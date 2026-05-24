#!/bin/bash

# ==========================================================
#  Cloudflare IP 自动优选 + 自动生成订阅
#  cfcdn-singbox-warp
# ==========================================================

DOMAIN="你的域名"
WS_PATH="/ws"
UUID="你的UUID"
SUB_FILE="/root/cfcdn-singbox-warp/sub.txt"

# Cloudflare IP 段（最常用、最稳定）
CF_IP_RANGES=(
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    188.114.96.0/20
)

echo "开始优选 Cloudflare IP..."

BEST_IP=""
BEST_RTT=9999

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

echo "最佳 IP: $BEST_IP 延迟: $BEST_RTT ms"

# 生成 VLESS 节点链接
VLESS_LINK="vless://$UUID@$BEST_IP:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WS_PATH#cfcdn-singbox-warp"

# 写入订阅文件
echo "$VLESS_LINK" > $SUB_FILE

echo "订阅文件已更新：$SUB_FILE"
