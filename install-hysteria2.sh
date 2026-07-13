#!/bin/bash
# Hysteria2 Installer for v2 Box
# ================================
# v2 Box uses Hysteria v1 protocol (with obfs) under "Hysteria2" label
# Run: bash <(curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/install-hysteria2.sh)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Hysteria2 Installer (v2 Box)   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi

IP=$(curl -s ifconfig.me)
read -p "Port (default: 25000): " PORT
PORT=${PORT:-25000}
read -p "Password (default: naman): " AUTH
AUTH=${AUTH:-naman}
read -p "OBFS Password (default: adman): " OBFS
OBFS=${OBFS:-adman}

echo -e "\n${YELLOW}[*] Installing dependencies...${NC}"
apt update -qq && apt install curl openssl iptables -y -qq

echo -e "${YELLOW}[*] Downloading Hysteria v1...${NC}"
curl -fsL "https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64" -o /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria

echo -e "${YELLOW}[*] Generating TLS certificate...${NC}"
mkdir -p /etc/hysteria/certs
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/certs/server.key \
  -out /etc/hysteria/certs/server.crt \
  -subj "/CN=$IP" -days 3650 2>/dev/null

echo -e "${YELLOW}[*] Creating config...${NC}"
cat > /etc/hysteria/config.json << EOF
{
  "listen": ":$PORT",
  "protocol": "udp",
  "cert": "/etc/hysteria/certs/server.crt",
  "key": "/etc/hysteria/certs/server.key",
  "up_mbps": 500,
  "down_mbps": 500,
  "obfs": "$OBFS",
  "auth_str": "$AUTH"
}
EOF

echo -e "${YELLOW}[*] Setting up port hopping...${NC}"
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-port $PORT 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 443 -j REDIRECT --to-port $PORT 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port $PORT 2>/dev/null

echo -e "${YELLOW}[*] Creating systemd service...${NC}"
cat > /etc/systemd/system/hysteria.service << 'EOF'
[Unit]
Description=Hysteria VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria
sleep 2

STATUS=$(systemctl is-active hysteria)

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo "  Server IP : $IP"
echo "  Port      : $PORT (Hopping: 20000-50000)"
echo "  Password  : $AUTH"
echo "  OBFS      : $OBFS"
echo "  Status    : $STATUS"
echo ""
echo -e "${YELLOW}  📱 v2 Box Settings:${NC}"
echo "  ───────────────────────────────"
echo "  Protocol  : Hysteria2"
echo "  Address   : $IP"
echo "  Port      : $PORT (or 443, 53)"
echo "  Password  : $AUTH"
echo "  Obfs pass : $OBFS"
echo "  Port Hop  : OFF"
echo "  Insecure  : ON"
echo ""
echo -e "${YELLOW}  📱 Creeb Injector Settings:${NC}"
echo "  ───────────────────────────────"
echo "  Protocol  : UDP HYSTERIA"
echo "  Port      : $PORT"
echo "  AUTH      : $AUTH"
echo "  OBFS      : $OBFS"
echo "  Insecure  : ON"
echo ""
echo -e "${YELLOW}  Commands:${NC}"
echo "  systemctl status hysteria"
echo "  systemctl restart hysteria"
echo "  journalctl -u hysteria -f"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
