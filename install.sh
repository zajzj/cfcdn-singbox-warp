#!/bin/bash
set -e

# ==============================
#  基础检查
# ==============================

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 运行此脚本"
  exit 1
fi

apt update -y
apt install -y curl socat prips wget unzip xxd

# ==============================
#  输入域名与路径
# ==============================

read -rp "请输入你的域名（必须已解析到本机）: " DOMAIN
read -rp "请输入 WebSocket 路径（例如 /ws123，必须以 / 开头）: " WSPATH

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "生成 UUID: $UUID"

mkdir -p /etc/sing-box

# ==============================
#  安装 acme.sh 并申请证书
# ==============================

if [ ! -d "/root/.acme.sh" ]; then
  curl https://get.acme.sh | sh
fi

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 停止可能占用 80 端口的服务
systemctl stop nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true

~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --keylength ec-256 --force

~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --ecc \
  --fullchain-file /etc/sing-box/cert.pem \
  --key-file /etc/sing-box/key.pem \
  --force

chmod 600 /etc/sing-box/cert.pem /etc/sing-box/key.pem

# ==============================
#  安装 sing-box
# ==============================

VERSION="1.9.7"
ARCH="linux-amd64"

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

curl -L -o sb.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-${ARCH}.tar.gz"
tar -xzf sb.tar.gz

install -m 755 "sing-box-${VERSION}-${ARCH}/sing-box" /usr/bin/sing-box

cd /
rm -rf "$TMPDIR"

# ==============================
#  写入 config.json（无 BOM、无 CRLF）
# ==============================

cat <<EOF >/etc/sing-box/config.json
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
          "uuid": "${UUID}"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      },
      "transport": {
        "type": "ws",
        "path": "${WSPATH}"
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

chmod 600 /etc/sing-box/config.json

# ==============================
#  systemd 服务
# ==============================

cat <<EOF >/etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

sleep 2

systemctl --no-pager -l status sing-box || true

# ==============================
#  输出节点
# ==============================

echo
echo "=============================="
echo "  安装完成"
echo "=============================="
echo "域名: ${DOMAIN}"
echo "UUID: ${UUID}"
echo "WS 路径: ${WSPATH}"
echo
echo "VLESS 节点:"
echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=${WSPATH}#sing-box"
echo
echo "如需查看日志： journalctl -u sing-box -n 50 --no-pager"
