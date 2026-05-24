# cfcdn-singbox-warp
### VLESS + WS + TLS + Cloudflare CDN + WARP 出口 + 自动优选 IP + 自动订阅

本项目提供一套 **全自动、可长期维护、可解锁 AI、可加速全链路** 的代理部署方案：

- **VLESS + WS + TLS（可套 Cloudflare CDN）**
- **ACME 自动证书（Let’s Encrypt）**
- **Cloudflare CDN 优选 IP 加速去程**
- **Cloudflare WARP 优化 VPS 出口（回程）**
- **自动优选 Cloudflare IP（每日自动测速）**
- **自动生成订阅（sub.txt）**
- **客户端自动更新（v2rayN / sing-box / OpenWrt）**

适合需要 **稳定、低延迟、可长期使用、可分享** 的用户。

---

# ✨ 功能特点

- ✔ 去程：Cloudflare CDN + 优选 IP  
- ✔ 回程：WARP（Cloudflare 网络）  
- ✔ 协议：VLESS + WS + TLS（最稳定）  
- ✔ 证书：ACME（公共 CA）  
- ✔ 自动优选 Cloudflare IP（每日测速）  
- ✔ 自动生成订阅 sub.txt  
- ✔ 客户端自动更新  
- ✔ 解锁：OpenAI / Claude / Gemini / YouTube  
- ✔ 完全兼容：OpenWrt / Passwall2 / sing-box / v2rayN  

---

# 🚀 一键安装（VLESS + WS + TLS）

bash <(wget -qO- https://raw.githubusercontent.com/zajzj/cfcdn-singbox-warp/main/install.sh)


安装过程中会提示输入：

- 域名  
- WS 路径  
- UUID（可自动生成）  

安装完成后会输出：

- 节点信息  
- VLESS 链接（可直接复制）  

---

# 🚀 一键安装（WARP 出口）

bash <(wget -qO- https://raw.githubusercontent.com/zajzj/cfcdn-singbox-warp/main/install_warp.sh


安装完成后：

- VPS 出口走 Cloudflare WARP  
- 自动解锁 OpenAI / Claude / Gemini / YouTube  

---

# 🌐 Cloudflare DNS 设置

| 类型 | 名称 | 内容 | 代理 |
|------|------|--------|--------|
| A | 你的子域名 | VPS_IP | **Proxied（橙色云）** |

Cloudflare → SSL/TLS → **Full（Strict）**

---

# 📦 客户端配置（OpenWrt Passwall2）

| 项目 | 值 |
|------|------|
| 类型 | VLESS |
| 地址 | 你的域名 |
| 端口 | 443 |
| UUID | 安装脚本输出 |
| 加密 | none |
| 传输协议 | ws |
| WS 路径 | /ws |
| TLS | 开启 |
| SNI | 你的域名 |

---

# ⚡ 自动优选 Cloudflare IP（auto_cf_ip.sh）

本项目提供自动优选脚本：

auto_cf_ip.sh


功能：

- 自动读取 `/etc/sing-box/config.json`  
- 自动读取 UUID / 域名 / WS 路径  
- 自动扫描 Cloudflare IP  
- 自动测速（延迟）  
- 自动选择最快 IP  
- 自动生成 VLESS 节点  
- 自动写入订阅文件 `sub.txt`  

---

# 📄 自动生成订阅（sub.txt）

订阅文件路径：

/root/cfcdn-singbox-warp/sub.txt


你可以用 nginx / Caddy 公开它，例如：

https://你的域名/sub.txt


客户端订阅后即可自动更新。

---

# ⏰ 设置每天自动优选（crontab）

执行：

crontab -e

加入：

0 3 * * * bash /root/cfcdn-singbox-warp/auto_cf_ip.sh

每天凌晨 3 点自动优选 Cloudflare IP。

---

# 🔥 自动优选 + 自动订阅 = 全自动加速系统

最终链路：

你 → 优选 Cloudflare IP（最快入口）
→ Cloudflare CDN（Anycast）
→ VPS（VLESS+WS+TLS）
→ WARP（Cloudflare 出口）
→ OpenAI / Google / YouTube


---

# 🛠 维护

重启服务：

systemctl restart sing-box


查看日志：

journalctl -u sing-box -f


---

# 📄 LICENSE

MIT License

---

# 🎉 完成！

你现在拥有一个：

- 自动部署  
- 自动优选  
- 自动订阅  
- 自动更新  
- 自动解锁 AI  
- 全链路 Cloudflare 加速  

的完整开源项目。

