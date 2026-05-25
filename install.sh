#!/bin/bash
set -e # 遇到錯誤立即停止執行

echo "请输入你的域名:"
read DOMAIN

echo "请输入你的 WS 路径（例如 /ws）:"
read WSPATH

# 移除用戶可能誤輸入的末尾斜杠
WSPATH=$(echo "$WSPATH" | sed 's/\/$//')

UUID=$(cat /proc/sys/kernel/random/uuid)

# 偵測作業系統套件管理器
if [ -x "$(command -v apt)" ]; then
    apt update -y && apt install -y curl wget unzip prips socat
elif [ -x "$(command -v dnf)" ]; then
    dnf install -y curl wget unzip socat
elif [ -x "$(command -v yum)" ]; then
    yum install -y curl wget unzip socat
else
    echo "未知的作業系統，請手動安裝相依套件。" && exit 1
fi

echo "开启 BBR..."
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
sysctl -p

# 自動判斷系統架構
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_TYPE="amd64" ;;
    aarch64) ARCH_TYPE="arm64" ;;
    *) echo "不支援的架構: $ARCH" && exit 1 ;;
esac

# 选择稳定版本
VERSION="1.13.12"

echo "安装 sing-box 稳定版 $VERSION ($ARCH_TYPE) ..."
rm -f sing-box.tar.gz
wget -O sing-box.tar.gz https://github.com
tar -xzf sing-box.tar.gz
mv sing-box-$VERSION-linux-$ARCH_TYPE/sing-box /usr/bin/sing-box
chmod +x /usr/bin/sing-box
# 清理安裝垃圾
rm -rf sing-box.tar.gz sing-box-$VERSION-linux-$ARCH_TYPE

mkdir -p /etc/sing-box

cat >/etc/sing-box/config.json <<'EOF'
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
          "uuid": "UUID_REPLACE"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      },
      "transport": {
        "type": "ws",
        "path": "WSPATH_REPLACE"
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

sed -i "s/UUID_REPLACE/$UUID/" /etc/sing-box/config.json
sed -i "s#WSPATH_REPLACE#$WSPATH#" /etc/sing-box/config.json

# 關鍵修正：申請證書前先停用 sing-box，釋放 443/80 端口
systemctl stop sing-box 2>/dev/null || true

echo "申请证书..."
curl https://get.acme.sh | sh || true

# 顯式指定 acme.sh 的絕對路徑，防止找不到命令
ACME_BIN="/root/.acme.sh/acme.sh"
if [ ! -f "$ACME_BIN" ]; then
    ACME_BIN="$HOME/.acme.sh/acme.sh"
fi

$ACME_BIN --set-default-ca --server letsencrypt
$ACME_BIN --issue -d "$DOMAIN" --standalone --force

$ACME_BIN --install-cert -d "$DOMAIN" \
--key-file /etc/sing-box/key.pem \
--fullchain-file /etc/sing-box/cert.pem

echo "创建 systemd 服务..."

cat >/etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

echo "安装完成！"
echo "UUID: $UUID"
echo "域名: $DOMAIN"
echo "WS 路径: $WSPATH"

echo ""
echo "VLESS 节点："
echo "vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WSPATH#cfcdn-singbox-warp"
