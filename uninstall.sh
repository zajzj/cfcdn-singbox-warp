#!/bin/bash
# ==========================================================
#  Cloudflare VLESS + WARP 專案一鍵全自動卸載與清理腳本
# ==========================================================

echo "=== 開始卸載 cfcdn-singbox-warp 專案 ==="

# 1. 停用並刪除 sing-box 服務
echo "正在停用並移除 sing-box 服務..."
systemctl stop sing-box 2>/dev/null || true
systemctl disable sing-box 2>/dev/null || true
rm -f /etc/systemd/system/sing-box.service
systemctl daemon-reload

# 2. 停用並刪除 WARP (WireGuard) 介面
echo "正在停用並移除 WARP 虛擬網卡..."
wg-quick down warp 2>/dev/null || true
systemctl stop wg-quick@warp 2>/dev/null || true
systemctl disable wg-quick@warp 2>/dev/null || true
rm -rf /etc/wireguard/warp.conf

# 3. 清除 crontab 定時優選任務
echo "正在清除 Crontab 自動優選定時任務..."
crontab -l 2>/dev/null | grep -v "auto_cf_ip.sh" | crontab - 2>/dev/null || true

# 4. 移除所有產生的檔案與目錄
echo "正在清除所有專案安裝檔案與證書..."
rm -f /usr/bin/sing-box
rm -rf /etc/sing-box
rm -rf /root/cfcdn-singbox-warp

# 5. 提示移除 acme.sh（可選，避免破壞用戶其他證書）
ACME_BIN="/root/.acme.sh/acme.sh"
if [ ! -f "$ACME_BIN" ]; then ACME_BIN="$HOME/.acme.sh/acme.sh"; fi
if [ -f "$ACME_BIN" ]; then
    read -p "是否一併移除 acme.sh 證書工具？(y/N): " rm_acme
    if [[ "$rm_acme" == "y" || "$rm_acme" == "Y" ]]; then
        $ACME_BIN --uninstall
        rm -rf ~/.acme.sh
        echo "acme.sh 已卸載。"
    fi
fi

echo ""
echo "======================================"
echo "  項目已成功安全卸載，系統清理完畢！"
echo "======================================"
