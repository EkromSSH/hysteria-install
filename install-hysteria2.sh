#!/bin/bash
# Hysteria2 Installer for v2 Box
# ================================
# Run: bash <(curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/install-hysteria2.sh)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Hysteria2 Installer (v2 Box)   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi

IP=$(curl -s ifconfig.me)
read -p "Port (default: 25002): " PORT
PORT=${PORT:-25002}
read -p "Password (default: naman): " AUTH
AUTH=${AUTH:-naman}

echo -e "\n${YELLOW}[*] Installing dependencies...${NC}"
apt update -qq && apt install curl openssl iptables -y -qq

echo -e "${YELLOW}[*] Downloading Hysteria2...${NC}"
curl -fsL "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64" -o /usr/local/bin/hysteria2
chmod +x /usr/local/bin/hysteria2

echo -e "${YELLOW}[*] Generating TLS certificate...${NC}"
mkdir -p /etc/hysteria2/certs
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria2/certs/server.key \
  -out /etc/hysteria2/certs/server.crt \
  -subj "/CN=$IP" -days 3650 2>/dev/null

echo -e "${YELLOW}[*] Creating server config...${NC}"
mkdir -p /etc/hysteria2
cat > /etc/hysteria2/config.json << EOF
{
  "listen": ":$PORT",
  "tls": {
    "cert": "/etc/hysteria2/certs/server.crt",
    "key": "/etc/hysteria2/certs/server.key"
  },
  "auth": {
    "type": "password",
    "password": "$AUTH"
  },
  "bandwidth": {
    "up": "500 mbps",
    "down": "500 mbps"
  },
  "quic": {
    "initStreamReceiveWindow": 8388608,
    "maxStreamReceiveWindow": 8388608,
    "initConnReceiveWindow": 20971520,
    "maxConnReceiveWindow": 20971520,
    "maxIdleTimeout": "30s",
    "keepAlivePeriod": "5s"
  }
}
EOF

echo -e "${YELLOW}[*] Creating systemd service...${NC}"
cat > /etc/systemd/system/hysteria2.service << 'EOF'
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria2 server -c /etc/hysteria2/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria2
sleep 2

STATUS=$(systemctl is-active hysteria2)

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Hysteria2 Installed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo "  Server IP : $IP"
echo "  Port      : $PORT"
echo "  Password  : $AUTH"
echo "  Status    : $STATUS"
echo ""
echo -e "${YELLOW}  v2 Box Client Config:${NC}"
echo "  ─────────────────────────────────"
echo "  📋 ก๊อป JSON นี้ไปใส่ในช่อง Configs:"
echo ""
cat << EOF
{
  "server": "$IP:$PORT",
  "auth": "$AUTH",
  "tls": {
    "insecure": true
  },
  "bandwidth": {
    "up": "100 mbps",
    "down": "200 mbps"
  }
}
EOF
echo ""
echo -e "${YELLOW}  หรือตั้งค่าในช่องของ v2 Box:${NC}"
echo "  Port      : $PORT"
echo "  Password  : $AUTH"
echo "  Port Hopping : ไม่ต้องเปิด"
echo "  Allow Insecure : ON"
echo ""
echo -e "${YELLOW}  Commands:${NC}"
echo "  systemctl status hysteria2"
echo "  systemctl restart hysteria2"
echo "  journalctl -u hysteria2 -f"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
