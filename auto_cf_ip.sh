#!/bin/bash

# ==========================================================
#  Cloudflare IP 自动优选 + 自动生成订阅
#  自动读取 /etc/sing-box/config.json
#  cfcdn-singbox-warp
# ==========================================================

CONFIG="/etc/sing-box/config.json"
SUB_FILE="/root/cfcdn-singbox-warp/sub.txt"

# -----------------------------
# 1. 自动读取配置文件
# -----------------------------
UUID=$(grep -oP '(?<="uuid": ")[^"]+' $CONFIG)
DOMAIN=$(grep -oP '(?<="server_name": ")[^"]+' $CONFIG)
WS_PATH=$(grep -oP '(?<="path": ")[^"]+' $CONFIG)

if [[ -z "$UUID" || -z "$DOMAIN" || -z "$WS_PATH" ]]; then
    echo "读取 config.json 失败，请检查文件是否存在并格式正确"
    exit 1
fi

echo "读取到配置："
echo "UUID: $UUID"
echo "域名: $DOMAIN"
echo "WS 路径: $WS_PATH"
echo ""

# -----------------------------
# 2. Cloudflare IP 段
# -----------------------------
CF_IP_RANGES=(
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    188.114.96.0/20
)

echo "开始优选 Cloudflare IP..."

BEST_IP=""
BEST_RTT=9999

# -----------------------------
# 3. 扫描并测速
# -----------------------------
for RANGE in "${CF_IP_RANGES[@]}"; do
    IPS=$(prips $RANGE | shuf | head -n 20)

    for IP in $IPS; do
        RTT=$(ping -c 1 -W 1 $IP | grep time= | awk -F"time=" '{print $2}' | cut -d " " -f1)

        if [[ ! -z "$RTT" ]]; then
            echo "测试 $IP 延迟: $RTT ms"

            if (( $(echo "$RTT < $BEST_RTT" | bc -l) )); then
                BEST_RTT=$RTT
                BEST_IP=$IP
            fi
        fi
    done
done

echo ""
echo "最佳 IP: $BEST_IP 延迟: $BEST_RTT ms"

# -----------------------------
# 4. 生成 VLESS 节点链接
# -----------------------------
VLESS_LINK="vless://$UUID@$BEST_IP:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WS_PATH#cfcdn-singbox-warp"

echo "$VLESS_LINK" > $SUB_FILE

echo ""
echo "订阅文件已更新：$SUB_FILE"
echo "内容如下："
echo "$VLESS_LINK"
echo ""
