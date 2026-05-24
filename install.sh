#!/bin/bash

# ==========================================================
#  cfcdn-singbox-warp
#  VLESS + WS + TLS + ACME 自动安装脚本（交互式）
#  适合 Cloudflare CDN（无需 Argo）
#  系统：Debian 12 / Ubuntu 20+
# ==========================================================

echo "=============================================="
echo "   cfcdn-singbox-warp - VLESS + WS + TLS 安装"
echo "=============================================="
echo ""

# -----------------------------
# 1. 用户输入
# -----------------------------
read -p "请输入你的域名（必须已解析到本机）: " DOMAIN
read -p "请输入 WebSocket 路径（例如 /ws）: " WS_PATH
read -p "请输入 UUID（留空则自动生成）: " UUID

if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
fi

echo ""
echo "你输入的配置如下："
echo "域名: $DOMAIN"
echo "WS 路径: $WS_PATH"
echo "UUID: $UUID"
echo ""
read -p "确认继续安装？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "安装已取消。"
    exit 1
fi

# -----------------------------
# 2. 安装依赖
# -----------------------------
echo "=== 更新系统 ==="
apt update -y && apt install -y curl wget socat

# -----------------------------
# 3. 安装 ACME 证书
# -----------------------------
echo "=== 安装 ACME.sh ==="
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

echo "=== 申请证书 ==="
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
mkdir -p /etc/sing-box
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
--key-file /etc/sing-box/key.pem \
--fullchain-file /etc/sing-box/cert.pem

# -----------------------------
# 4. 安装 sing-box
# -----------------------------
echo "=== 下载 sing-box 最新版本 ==="
LATEST=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
wget -O /usr/local/bin/sing-box $LATEST
chmod +x /usr/local/bin/sing-box

# -----------------------------
# 5. 生成配置文件
# -----------------------------
echo "=== 生成 sing-box 配置 ==="
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 443,
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      },
      "transport": {
        "type": "ws",
        "path": "$WS_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

# -----------------------------
# 6. 创建 systemd 服务
# -----------------------------
echo "=== 创建 systemd 服务 ==="
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# -----------------------------
# 7. 完成
# -----------------------------
echo ""
echo "=============================================="
echo "  Sing-box VLESS + WS + TLS 安装完成"
echo "=============================================="
echo ""
echo "地址：$DOMAIN"
echo "端口：443"
echo "UUID：$UUID"
echo "传输：ws"
echo "路径：$WS_PATH"
echo "TLS：开启"
echo ""
echo "请确保 Cloudflare DNS 已开启橙色云（CDN）"
echo ""
