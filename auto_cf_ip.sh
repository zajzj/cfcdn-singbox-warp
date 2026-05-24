#!/bin/bash

# ==========================================================
#  Cloudflare IP 自动优选（延迟 + 下载速度综合评分）
#  自动读取 /etc/sing-box/config.json
#  输出 2 个最优 IP 到订阅文件
# ==========================================================

CONFIG="/etc/sing-box/config.json"
SUB_FILE="/root/cfcdn-singbox-warp/sub.txt"

UUID=$(grep -oP '(?<="uuid": ")[^"]+' $CONFIG)
DOMAIN=$(grep -oP '(?<="server_name": ")[^"]+' $CONFIG)
WS_PATH=$(grep -oP '(?<="path": ")[^"]+' $CONFIG)

TEST_URL="https://$DOMAIN/test.bin"

if [[ -z "$UUID" || -z "$DOMAIN" || -z "$WS_PATH" ]]; then
    echo "读取 config.json 失败"
    exit 1
fi

echo "开始优选 Cloudflare IP..."
echo "UUID: $UUID"
echo "域名: $DOMAIN"
echo "WS 路径: $WS_PATH"
echo ""

CF_IP_RANGES=(
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    188.114.96.0/20
)

declare -A SCORE_MAP

for RANGE in "${CF_IP_RANGES[@]}"; do
    IPS=$(prips $RANGE | shuf | head -n 10)

    for IP in $IPS; do
        RTT=$(ping -c 1 -W 1 $IP | grep time= | awk -F"time=" '{print $2}' | cut -d " " -f1)
        if [[ -z "$RTT" ]]; then
            continue
        fi

        SPEED=$(curl --resolve $DOMAIN:443:$IP -o /dev/null -s -w "%{speed_download}" $TEST_URL)

        SCORE=$(echo "scale=4; ($SPEED/1024) - ($RTT*2)" | bc)
        SCORE_MAP[$IP]=$SCORE

        echo "IP: $IP | 延迟: ${RTT}ms | 速度: ${SPEED}B/s | 评分: $SCORE"
    done
done

BEST_IPS=$(for ip in "${!SCORE_MAP[@]}"; do echo "$ip ${SCORE_MAP[$ip]}"; done | sort -k2 -nr | head -n 2 | awk '{print $1}')

echo ""
echo "最优 IP："
echo "$BEST_IPS"
echo ""

echo "" > $SUB_FILE

for IP in $BEST_IPS; do
    VLESS_LINK="vless://$UUID@$IP:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WS_PATH#cfcdn-singbox-warp"
    echo "$VLESS_LINK" >> $SUB_FILE
done

echo "订阅文件已更新：$SUB_FILE"
