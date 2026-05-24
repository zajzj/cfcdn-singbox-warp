cfcdn-singbox-warp
VLESS + WS + TLS + Cloudflare CDN + WARP 出口 一键部署
本项目提供一套 专业级、可长期维护、可解锁 AI、可加速全链路 的代理部署方案：

VLESS + WS + TLS（可套 Cloudflare CDN）

ACME 自动证书

Cloudflare CDN 优选 IP 加速去程

Cloudflare WARP 优化 VPS 出口（回程）

解锁 OpenAI / Claude / Gemini / YouTube

无需 Argo Tunnel

无需 Reality / Hysteria2 / TUIC

✨ 功能特点
✔ 去程：Cloudflare CDN + 优选 IP

✔ 回程：WARP（Cloudflare 网络）

✔ 协议：VLESS + WS + TLS（最稳定）

✔ 证书：ACME（公共 CA）

✔ 解锁：OpenAI / Claude / Gemini

✔ 完全兼容：OpenWrt / Passwall2 / sing-box

🚀 一键安装（VLESS + WS + TLS）
Code
bash <(wget -qO- https://raw.githubusercontent.com/你的用户名/cfcdn-singbox-warp/main/install.sh)
🚀 一键安装（WARP 出口）
Code
bash <(wget -qO- https://raw.githubusercontent.com/你的用户名/cfcdn-singbox-warp/main/install_warp.sh)
🌐 Cloudflare DNS 设置
类型	名称	内容	代理
A	dc03	VPS_IP	Proxied（橙色云）


📦 客户端配置（OpenWrt Passwall2）
项目	值
类型	VLESS
地址	你的域名
端口	443
UUID	安装脚本输出
加密	none
传输协议	ws
WS 路径	/ws
TLS	开启
SNI	你的域名


🔥 AI 解锁（WARP 出站）
WARP 出口自动解锁：

OpenAI

Claude

Gemini

YouTube

Google

Midjourney（部分地区）

🛠 维护
重启服务：

Code
systemctl restart sing-box
查看日志：

Code
journalctl -u sing-box -f
📄 LICENSE
MIT License
