#!/bin/bash

# ==========================================================
#  cfcdn-singbox-warp - install.sh
#  安装 VLESS + WS + TLS + WARP + 10MB 测速文件
# ==========================================================

read -p "请输入你的域名: " DOMAIN
read -p "请输入你的 WS 路径（例如 /ws）: " WS_PATH
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "安装依赖..."
apt update -y
apt install -y curl wget unzip
apt install -y prips

echo "安装 sing-box..."
LATEST=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
wget -O sing-box.tar.gz $LATEST
tar -xzf sing-box.tar.gz
mv sing-box*/sing-box /usr/bin/
chmod +x /usr/bin/sing-box

mkdir -p /etc/sing-box

echo "生成 config.json..."

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "disabled": false,
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
    },
    {
      "type": "http",
      "listen": "::",
      "listen_port": 8080,
      "routes": [
        {
          "path": "/test.bin",
          "body": "RANDOM_10MB"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

echo "申请证书..."
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
--key-file /etc/sing-box/key.pem \
--fullchain-file /etc/sing-box/cert.pem

echo "创建 systemd 服务..."

cat > /etc/systemd/system/sing-box.service <<EOF
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

echo ""
echo "安装完成！"
echo "UUID: $UUID"
echo "域名: $DOMAIN"
echo "WS 路径: $WS_PATH"
echo ""
echo "VLESS 节点："
echo "vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WS_PATH#cfcdn-singbox-warp"
