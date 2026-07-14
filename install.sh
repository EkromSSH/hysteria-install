#!/bin/bash
# ═══════════════════════════════════════════════════════
# IDA UDPHysteria — Auto Installer v3.3
# Run: bash <(curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/install.sh)
# ═══════════════════════════════════════════════════════
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     IDA UDPHysteria — Auto Installer        ║"
echo "  ║           Hysteria v1 Setup                 ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Check root ──
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# ── Get passwords ──
echo -e "${YELLOW}Enter passwords (press Enter for default)${NC}"
echo ""
read -p "  AUTH password [naman]: " AUTH
AUTH=${AUTH:-naman}
read -p "  OBFS password [adman]: " OBFS
OBFS=${OBFS:-adman}
read -p "  Port [25000]: " PORT
PORT=${PORT:-25000}

echo ""
echo -e "${GREEN}Installing Hysteria v1...${NC}"

# ── Install dependencies ──
apt update -qq && apt install -y -qq curl openssl iptables python3 2>/dev/null

# ── Create directories ──
mkdir -p /opt/hysteria/{certs,config}

# ── Download Hysteria v1 ──
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armhf) ARCH="armhf" ;;
    *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "  Downloading hysteria-v1 (${ARCH})..."
curl -sL "https://github.com/apernet/hysteria/raw/master/cmd/hysteria-v1/hysteria-v1-linux-${ARCH}" \
    -o /opt/hysteria/hysteria-v1
chmod +x /opt/hysteria/hysteria-v1

# ── Generate self-signed certificate ──
IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
if [ -n "$IP" ]; then
    echo -e "  Generating certificate for ${IP}..."
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /opt/hysteria/certs/server.key \
        -out /opt/hysteria/certs/server.crt \
        -subj "/CN=${IP}" -days 3650 2>/dev/null
else
    echo -e "${YELLOW}  Cannot get public IP, using localhost${NC}"
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /opt/hysteria/certs/server.key \
        -out /opt/hysteria/certs/server.crt \
        -subj "/CN=localhost" -days 3650 2>/dev/null
fi

# ── Create config ──
cat > /opt/hysteria/config-v1.json << EOF
{
  "listen": ":${PORT}",
  "protocol": "udp",
  "cert": "/opt/hysteria/certs/server.crt",
  "key": "/opt/hysteria/certs/server.key",
  "up_mbps": 1000,
  "down_mbps": 1000,
  "obfs": "${OBFS}",
  "auth_str": "${AUTH}",
  "recv_window_conn": 20971520,
  "recv_window_client": 41943040,
  "disable_mtu_discovery": false
}
EOF

# ── Create systemd service ──
cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=Hysteria VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/opt/hysteria/hysteria-v1 server -c /opt/hysteria/config-v1.json
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# ── Start service ──
systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria
sleep 2

# ── Check status ──
if systemctl is-active --quiet hysteria; then
    STATUS="${GREEN}RUNNING${NC}"
else
    STATUS="${RED}FAILED${NC}"
fi

# ── Download menu ──
echo -e "  Downloading menu..."
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.py \
    -o /opt/hysteria/menu.py
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.sh \
    -o /usr/local/bin/hysteria-menu
chmod +x /usr/local/bin/hysteria-menu /opt/hysteria/menu.py

# ── Create convenience alias ──
grep -q "hysteria-menu" /root/.bashrc 2>/dev/null || \
    echo 'alias menu="python3 /opt/hysteria/menu.py"' >> /root/.bashrc

# ── Show result ──
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Installation Complete!${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Server IP  : ${BOLD}${IP:-Unknown}${NC}"
echo -e "${CYAN}║${NC}  Port       : ${BOLD}${PORT}${NC}"
echo -e "${CYAN}║${NC}  Auth       : ${BOLD}${AUTH}${NC}"
echo -e "${CYAN}║${NC}  Obfs       : ${BOLD}${OBFS}${NC}"
echo -e "${CYAN}║${NC}  Status     : ${STATUS}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Run menu   : ${BOLD}python3 /opt/hysteria/menu.py${NC}"
echo -e "${CYAN}║${NC}  Or alias   : ${BOLD}menu${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Login with Creeb/v2Box:${NC}"
echo -e "  Server : ${BOLD}${IP:-YOUR_IP}${NC}"
echo -e "  Port   : ${BOLD}${PORT}${NC}"
echo -e "  Auth   : ${BOLD}${AUTH}${NC}"
echo -e "  OBFS   : ${BOLD}${OBFS}${NC}"
echo ""
