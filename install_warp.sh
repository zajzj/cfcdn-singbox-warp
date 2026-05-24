#!/bin/bash

# ==========================================================
#  Cloudflare WARP 出口安装脚本（Debian 12）
#  cfcdn-singbox-warp
# ==========================================================

echo "=== 更新系统 ==="
apt update -y && apt install -y curl wget sudo wireguard-tools

echo "=== 下载 wgcf 工具 ==="
wget -O wgcf https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_amd64
chmod +x wgcf
mv wgcf /usr/local/bin/

echo "=== 注册 WARP 账户 ==="
wgcf register --accept-tos

echo "=== 生成 WARP WireGuard 配置 ==="
wgcf generate

echo "=== 安装 WireGuard 配置 ==="
mkdir -p /etc/wireguard
cp wgcf-profile.conf /etc/wireguard/wgcf.conf

echo "=== 调整 MTU ==="
sed -i 's/MTU = .*/MTU = 1280/' /etc/wireguard/wgcf.conf

echo "=== 启动 WARP ==="
wg-quick up wgcf
systemctl enable wg-quick@wgcf

echo ""
echo "======================================"
echo "  Cloudflare WARP 出口安装完成"
echo "======================================"
echo ""
echo "你的 VPS 出口现在走 Cloudflare WARP"
echo "可用于解锁 OpenAI / Claude / Gemini / YouTube"
echo ""
