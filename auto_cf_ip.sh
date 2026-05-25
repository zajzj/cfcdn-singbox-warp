#!/bin/bash

# ==========================================================
#  Cloudflare IP 自动优选（修复版：延迟 + 下载速度综合评分）
# ==========================================================

# 显式声明环境变量，防止 crontab 找不到命令
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONFIG="/etc/sing-box/config.json"
SUB_FILE="/root/cfcdn-singbox-warp/sub.txt"

# 确保订阅目录存在
mkdir -p "$(dirname "$SUB_FILE")"

# 修复：从 config.json 安全提取 UUID 和 path
UUID=$(grep -oP '(?<="uuid": ")[^"]+' $CONFIG | head -n 1)
WS_PATH=$(grep -oP '(?<="path": ")[^"]+' $CONFIG | head -n 1)

# 修复：由于服务端 config 没有 server_name，尝试从公网或证书提取域名
# 这里我们假设用户域名就是证书的 SNI，也可以直接读取 /etc/sing-box/ 目录下的证书信息
DOMAIN=$(openssl x509 -in /etc/sing-box/cert.pem -noout -ext subjectAltName | grep -oP 'DNS:\K[^,]+' | head -n 1)

# 如果提取不到域名，则提示错误
if [[ -z "$UUID" || -z "$DOMAIN" || -z "$WS_PATH" ]]; then
    echo "错误：无法从系统或配置中读取 UUID、域名或 WS 路径"
    exit 1
fi

# 修复：测试点改为 Cloudflare 官方全球通用的 100MB/5MB 测速文件
# 这样测出来的是 VPS 到 CF 节点，或者 CF 节点本身的真实吞吐量
TEST_URL="https://cloudflare.com" # 测试 2MB 大小

echo "开始优选 Cloudflare IP..."
echo "UUID: $UUID"
echo "域名: $DOMAIN"
echo "WS 路径: $WS_PATH"
echo "----------------------------------------"

CF_IP_RANGES=(
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    188.114.96.0/20
)

declare -A SCORE_MAP

for RANGE in "${CF_IP_RANGES[@]}"; do
    # 确保 prips 命令存在
    if ! command -v prips &> /dev/null; then
        IPS=$(nmap -sL -n $RANGE | awk '/Nmap scan report/{print $5}' | shuf | head -n 8)
    else
        IPS=$(prips $RANGE | shuf | head -n 8)
    fi

    for IP in $IPS; do
        # 限制 ping 的超时时间为 1 秒
        RTT=$(ping -c 1 -W 1 $IP 2>/dev/null | grep time= | awk -F"time=" '{print $2}' | cut -d " " -f1)
        
        if [[ -z "$RTT" ]]; then
            continue
        fi

        # 修复 curl 测速：限制最大执行时间为 3 秒，防止遇到死 IP 导致脚本卡死
        # --resolve 可以强制让 curl 访问特定 IP 时的特定域名
        SPEED=$(curl --resolve "$DOMAIN:443:$IP" -o /dev/null -s --connect-timeout 2 --max-time 3 -w "%{speed_download}" "$TEST_URL" || echo "0")

        # 确保 SPEED 是纯数字
        if ! [[ "$SPEED" =~ ^[0-9]+$ ]]; then
            SPEED=0
        fi

        # 修复 bc 计算：将速度转换为 KB/s，并处理 RTT。为了防止 bc 输出 -.5 这种没有前导 0 的负数，统一加一个基数 10000
        # 评分公式：速度分(KB/s) - 延迟分(ms * 2)
        SPEED_KB=$(echo "scale=2; $SPEED / 1024" | bc)
        RAW_SCORE=$(echo "scale=2; $SPEED_KB - ($RTT * 2)" | bc)
        
        # 统一格式化为标准浮点数，补齐前导 0
        SCORE=$(printf "%.2f" "$RAW_SCORE" 2>/dev/null || echo "0.00")
        SCORE_MAP[$IP]=$SCORE

        echo "IP: $IP | 延迟: ${RTT}ms | 速度: ${SPEED_KB} KB/s | 评分: $SCORE"
    done
done

# 修复排序问题：使用 sort -g (通用数值排序) 处理负数和小数
BEST_IPS=$(for ip in "${!SCORE_MAP[@]}"; do echo "$ip ${SCORE_MAP[$ip]}"; done | sort -k2 -gr | head -n 2 | awk '{print $1}')

if [[ -z "$BEST_IPS" ]]; then
    echo "错误：未能筛选出有效的最优 IP"
    exit 1
fi

echo "----------------------------------------"
echo "最优 IP："
echo "$BEST_IPS"
echo ""

# 清空并重新写入订阅
echo "" > "$SUB_FILE"

for IP in $BEST_IPS; do
    # 这里的 VLESS 链接把服务器地址换成了优选出的 CF IP，但 host 依旧保留原域名，完美符合 Cloudflare CDN 代理逻辑
    VLESS_LINK="vless://$UUID@$IP:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$WS_PATH#cfcdn-singbox-warp"
    echo "$VLESS_LINK" >> "$SUB_FILE"
done

echo "订阅文件已更新：$SUB_FILE"
