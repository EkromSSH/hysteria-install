#!/bin/bash
# ═══════════════════════════════════════════════════════
# IDA UDPHysteria — Complete Installer v4.0
# Hysteria v1 + ShowOn Dashboard
# Run: bash install.sh
# ═══════════════════════════════════════════════════════
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     IDA UDPHysteria — Complete Installer     ║"
echo "  ║           Hysteria v1 + Dashboard            ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi

# Get passwords
echo -e "${YELLOW}Enter passwords (press Enter for default)${NC}"
echo ""
read -p "  AUTH password [naman]: " AUTH
AUTH=${AUTH:-naman}
read -p "  OBFS password [adman]: " OBFS
OBFS=${OBFS:-adman}
read -p "  Hysteria Port [25000]: " PORT
PORT=${PORT:-25000}
read -p "  Dashboard Port [82]: " DPORT
DPORT=${DPORT:-82}
read -p "  Limit User Online [2000]: " LIMIT
LIMIT=${LIMIT:-2000}

echo ""
echo -e "${GREEN}Installing...${NC}"

# ── Step 1: Install dependencies ──
echo -e "${CYAN}[1/8]${NC} Installing dependencies..."
apt update -qq && apt install -y -qq curl openssl iptables nginx vnstat conntrack jq python3 net-tools psmisc ca-certificates >/dev/null 2>&1
systemctl enable vnstat 2>/dev/null; systemctl start vnstat 2>/dev/null

# ── Step 2: Install Hysteria v1 ──
echo -e "${CYAN}[2/8]${NC} Installing Hysteria v1..."
mkdir -p /opt/hysteria/{certs,config}
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo -e "${RED}Unsupported architecture${NC}"; exit 1 ;;
esac
curl -sL "https://github.com/apernet/hysteria/raw/master/cmd/hysteria-v1/hysteria-v1-linux-${ARCH}" -o /opt/hysteria/hysteria-v1
chmod +x /opt/hysteria/hysteria-v1

# ── Step 3: Generate certificate ──
echo -e "${CYAN}[3/8]${NC} Generating certificate..."
IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
if [ -n "$IP" ]; then
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /opt/hysteria/certs/server.key \
        -out /opt/hysteria/certs/server.crt \
        -subj "/CN=${IP}" -days 3650 2>/dev/null
    echo -e "  ${GREEN}OK${NC} Certificate for ${IP}"
else
    echo -e "  ${YELLOW}WARN${NC} Cannot get IP, using localhost"
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /opt/hysteria/certs/server.key \
        -out /opt/hysteria/certs/server.crt \
        -subj "/CN=localhost" -days 3650 2>/dev/null
fi

# ── Step 4: Create Hysteria config ──
echo -e "${CYAN}[4/8]${NC} Creating Hysteria config..."
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
chmod 600 /opt/hysteria/config-v1.json

# ── Step 5: Create systemd service ──
echo -e "${CYAN}[5/8]${NC} Creating Hysteria service..."
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
systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria
sleep 2

# ── Step 6: Setup Dashboard ──
echo -e "${CYAN}[6/8]${NC} Setting up Dashboard..."
WWW_DIR="/home/vps/public_html/server"
mkdir -p "$WWW_DIR"

# Download dashboard files
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/web/index.html -o "$WWW_DIR/index.html"
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/online-check.sh -o /usr/local/bin/online-check.sh
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/sysinfo.sh -o /usr/local/bin/sysinfo.sh
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/vnstat-traffic.sh -o /usr/local/bin/vnstat-traffic.sh
chmod +x /usr/local/bin/online-check.sh /usr/local/bin/sysinfo.sh /usr/local/bin/vnstat-traffic.sh

# Create config
NIC=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
[ -z "$NIC" ] && NIC="eth0"
cat > /etc/showon.conf << EOF
VERSION="V.4.0"
WWW_DIR="$WWW_DIR"
LIMIT=${LIMIT}
DEBUG_LOG="/var/log/ida-debug.log"
PANEL_URL=""
XUI_USER=""
XUI_PASS=""
NET_IFACE="$NIC"
AGN_PRESENT=1
AGN_PORT="$PORT"
EOF
chmod 600 /etc/showon.conf

# ── Step 7: Configure Nginx ──
echo -e "${CYAN}[7/8]${NC} Configuring Nginx..."
VPS_CONF="/etc/nginx/conf.d/vps.conf"
mkdir -p /etc/nginx/conf.d /var/log/nginx
cat > "$VPS_CONF" << NGINX
server {
  listen       ${DPORT};
  server_name  127.0.0.1 localhost;
  access_log /var/log/nginx/ida-access.log;
  error_log  /var/log/nginx/ida-error.log error;
  root $WWW_DIR;
  location = / { return 302 /server/; }
  location /server/ {
    alias $WWW_DIR/;
    index index.html;
    autoindex off;
    location ~* \.(json)$ { default_type application/json; }
    location ~ /server/(online_app|sys_info|v2ray_traffic|vnstat_traffic)$ { default_type application/json; }
  }
}
NGINX
nginx -t 2>&1 && systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null

# ── Step 8: Create systemd services ──
echo -e "${CYAN}[8/8]${NC} Creating services..."
for svc in online-check sysinfo vnstat-traffic; do
  cat > "/etc/systemd/system/${svc}.service" << SVCEOF
[Unit]
Description=IDA ${svc}
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /usr/local/bin/${svc}.sh; sleep 5; done'
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
SVCEOF
done
systemctl daemon-reload
systemctl enable --now online-check.service vnstat-traffic.service sysinfo.service 2>/dev/null

# ── Tuning conntrack ──
sysctl -w net.netfilter.nf_conntrack_udp_timeout=5 >/dev/null 2>&1 || true
sysctl -w net.netfilter.nf_conntrack_udp_timeout_stream=5 >/dev/null 2>&1 || true
if ! grep -q "nf_conntrack_udp_timeout" /etc/sysctl.conf 2>/dev/null; then
    echo "net.netfilter.nf_conntrack_udp_timeout=5" >> /etc/sysctl.conf
    echo "net.netfilter.nf_conntrack_udp_timeout_stream=5" >> /etc/sysctl.conf
fi

# ── Download menu script ──
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.py -o /opt/hysteria/menu.py
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.sh -o /usr/local/bin/ida-menu
chmod +x /opt/hysteria/menu.py /usr/local/bin/ida-menu

# ── Show result ──
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Installation Complete!${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Server IP  : ${BOLD}${IP:-Unknown}${NC}"
echo -e "${CYAN}║${NC}  Auth       : ${BOLD}${AUTH}${NC}"
echo -e "${CYAN}║${NC}  Obfs       : ${BOLD}${OBFS}${NC}"
echo -e "${CYAN}║${NC}  Port       : ${BOLD}${PORT}${NC}"
echo -e "${CYAN}║${NC}  Dashboard  : ${BOLD}http://${IP:-YOUR_IP}:${DPORT}/server/${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Run menu   : ${BOLD}python3 /opt/hysteria/menu.py${NC}"
echo -e "${CYAN}║${NC}  Or alias   : ${BOLD}ida-menu${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
