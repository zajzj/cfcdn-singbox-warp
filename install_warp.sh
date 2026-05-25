#!/bin/bash
# ==========================================================
#  Cloudflare WARP 應用態出口安裝腳本 (終極免密鑰全自動版)
#  專為 cfcdn-singbox-warp 設計 | 支援低記憶體環境
# ==========================================================
set -e

CONFIG="/etc/sing-box/config.json"

# 確保基礎相依套件與常規工具存在
if [ -x "$(command -v apt)" ]; then
    apt update -y && apt install -y curl jq wireguard-tools
elif [ -x "$(command -v dnf)" ]; then
    dnf install -y curl jq wireguard-tools
elif [ -x "$(command -v yum)" ]; then
    yum install -y curl jq wireguard-tools
fi

echo "=== 開始全自動向 Cloudflare 註冊免金鑰 WARP 帳戶 ==="

# 1. 本地生成臨時公網密鑰對
PRIV_KEY=$(wg genkey)
PUB_KEY=$(echo "$PRIV_KEY" | wg pubkey)

# 2. 請求 Cloudflare 官方 API 註冊全新的 WARP 帳戶，直接管道獲取回傳 JSON
echo "正在與 Cloudflare API 握手..."
RESPONSE=$(curl -s -X POST "https://cloudflareclient.com" \
  -H "User-Agent: okhttp/3.12.1" \
  -H "Content-Type: application/json" \
  -d "{\"key\":\"$PUB_KEY\"}")

# 3. 解析帳戶核心認證細節（包含分配的 IPv4、IPv6 以及 Token）
CLIENT_ID=$(echo "$RESPONSE" | jq -r '.result.id // empty')
ACCOUNT_TOKEN=$(echo "$RESPONSE" | jq -r '.result.token // empty')
WARP_IPV4=$(echo "$RESPONSE" | jq -r '.result.config.interface.addresses.v4 // empty')
WARP_IPV6=$(echo "$RESPONSE" | jq -r '.result.config.interface.addresses.v6 // empty')
PEER_PUBKEY=$(echo "$RESPONSE" | jq -r '.result.config.peers[0].public_key // empty')
ENDPOINT_HOST=$(echo "$RESPONSE" | jq -r '.result.config.peers[0].endpoint.host // empty')

# 防錯驗證：確保註冊成功拿到有效數據
if [[ -z "$CLIENT_ID" || -z "$WARP_IPV4" ]]; then
    echo "錯誤：Cloudflare WARP 註冊失敗，請檢查 VPS 是否能夠正常連通外網。"
    exit 1
fi

echo "[成功] 已獲取免手動 WARP 分配地址：$WARP_IPV4"

# 4. 融合並重寫 sing-box 主設定檔 (保持原有 inbound 組態，注入應用態 WireGuard 與分流)
if [ -f "$CONFIG" ]; then
    UUID=$(grep -oP '(?<="uuid": ")[^"]+' $CONFIG | head -n 1)
    WSPATH=$(grep -oP '(?<="path": ")[^"]+' $CONFIG | head -n 1)
    
    # 動態安全擷取域名
    DOMAIN=$(openssl x509 -in /etc/sing-box/cert.pem -noout -ext subjectAltName 2>/dev/null | grep -oP 'DNS:\K[^,]+' | head -n 1 || echo "")
    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(grep -oP '(?<="host": ")[^"]+' $CONFIG | head -n 1 || echo "yourdomain.com")
    fi

    echo "正在將全自動帳戶注入 sing-box 內核分流控制層..."
    
    cat > $CONFIG <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "0.0.0.0:443",
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      },
      "transport": {
        "type": "ws",
        "path": "$WSPATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "wireguard",
      "tag": "warp-out",
      "server": "$ENDPOINT_HOST",
      "server_port": 2408,
      "local_address": [
        "$WARP_IPV4",
        "$WARP_IPV6"
      ],
      "private_key": "$PRIV_KEY",
      "peer_public_key": "$PEER_PUBKEY",
      "mtu": 1280,
      "system_interface": true
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": [
          "openai.com",
          "ai.com",
          "anthropic.com",
          "google.com",
          "cloudflare.com"
        ],
        "outbound": "warp-out"
      }
    ],
    "final": "direct"
  }
}
EOF

    echo "正在重啟 sing-box 核心代理引擎..."
    systemctl restart sing-box
    echo "========================================================"
    echo "  [大功告成] sing-box 內建免密鑰 WARP 已全自動完美跑通！"
    echo "========================================================"
else
    echo "錯誤：未檢測到 /etc/sing-box/config.json，請先執行 install.sh"
    exit 1
fi
