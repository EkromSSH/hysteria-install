# IDA UDPHysteria Complete Installer

🚀 One-click installer for IDA UDPHysteria server with auto-update dashboard.

## 🚀 Quick Install

```bash
wget -qO- tinyurl.com/24fnhgvy | bash
```

Or:

```bash
bash <(curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/install.sh)
```

## ✨ Features

- ✅ Auto-detect Server IP (press Enter to accept)
- ✅ Fix apt lock automatically (retry 3 times)
- ✅ Nginx 403 fix
- ✅ Downloads latest scripts from GitHub after install
- ✅ Auto-update dashboard & scripts every 6 hours (cron)
- ✅ Port hopping 10000-65000 (bypass ISP throttle)
- ✅ Dashboard with CPU, RAM, Traffic, Online users
- ✅ Hysteria v1.3.5 (UDP only)

## 📋 Menu

After install, type:

```bash
showon
```

## 🔧 Client Config

```json
{
  "server": "YOUR_IP:10000-50000",
  "obfs": "idavpn",
  "auth_str": "idavpn",
  "up_mbps": 100,
  "down_mbps": 100,
  "retry": 3,
  "retry_interval": 1,
  "socks5": {
    "listen": "127.0.0.1:1080"
  },
  "http": {
    "listen": "127.0.0.1:8989"
  },
  "insecure": true,
  "lazy_start": true,
  "ca": "",
  "recv_window_conn": 196608,
  "recv_window": 491520,
  "disable_mtu_discovery": true
}
```

## 🌐 Dashboard

```
http://YOUR_IP:82/server/
```

## 📁 Repository Structure

```
├── install.sh              # Main installer (v2.2)
├── scripts/
│   ├── menu.py             # Interactive menu
│   ├── online-check.sh     # Online user counter
│   ├── sysinfo.sh          # System info (CPU/RAM)
│   └── vnstat-traffic.sh   # Traffic monitor
└── web/
    └── index.html          # Dashboard HTML
```
