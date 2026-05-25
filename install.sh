#!/bin/bash

echo "请输入你的域名:"
read DOMAIN

echo "请输入你的 WS 路径（例如 /ws）:"
read WSPATH

UUID=$(cat /proc/sys/kernel/random/uuid)

apt update -y
apt install -y curl wget unzip prips

echo "开启 BBR..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 选择稳定版本
VERSION="1.13.12"

echo "安装 sing-box 稳定版 $VERSION ..."
wget -O sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v$VERSION/sing-box-$VERSION-linux-amd64.tar.gz
tar -xzf sing-box.tar.gz
mv sing-box-$VERSION-linux-amd64/sing-box /usr/bin/sing-box
chmod +x /usr/bin/sing-box


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

echo "申请证书..."
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --force

~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
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
