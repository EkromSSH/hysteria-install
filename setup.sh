#!/bin/bash
set -e
echo -e "\n\033[1;34m==>\033[0m \033[1;37mIDA UDPHysteria Complete Installer\033[0m\n"
read -p "Server IP: " SERVER_IP
read -p "Port [36712]: " PORT
PORT=${PORT:-36712}
read -p "Auth [idavpn]: " AUTH
AUTH=${AUTH:-idavpn}
read -p "OBFS [idavpn]: " OBFS
OBFS=${OBFS:-idavpn}
echo -e "\n\033[1;34m==>\033[0m Installing packages..."
apt-get update -qq 2>/dev/null
apt-get install -y wget curl openssl nginx vnstat conntrack jq python3 iptables-persistent 2>&1 | tail -2
echo -e "\n\033[1;34m==>\033[0m Downloading Hysteria v1.3.5..."
wget -q https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64 -O /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria
mkdir -p /opt/hysteria/certs /home/vps/public_html/server
echo -e "\n\033[1;34m==>\033[0m Generating certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /opt/hysteria/certs/server.key -out /opt/hysteria/certs/server.crt -subj "/C=TH/ST=Bangkok/L=Bangkok/O=IDA VPN/CN=${SERVER_IP}" 2>/dev/null
chmod 600 /opt/hysteria/certs/server.key
cat > /opt/hysteria/config-v1.json << EOF
{
  "listen": ":${PORT}",
  "protocol": "udp",
  "cert": "/opt/hysteria/certs/server.crt",
  "key": "/opt/hysteria/certs/server.key",
  "up_mbps": 2000,
  "down_mbps": 2000,
  "obfs": "${OBFS}",
  "auth_str": "${AUTH}",
  "recv_window_conn": 20971520,
  "recv_window_client": 41943040,
  "disable_mtu_discovery": false
}
EOF
cat > /opt/hysteria/start.sh << 'E1'
#!/bin/bash
exec /usr/local/bin/hysteria server -c /opt/hysteria/config-v1.json
E1
chmod +x /opt/hysteria/start.sh
cat > /etc/systemd/system/hysteria.service << 'E2'
[Unit]
Description=Hysteria VPN Server
After=network.target
[Service]
Type=simple
ExecStart=/bin/bash /opt/hysteria/start.sh
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
E2
echo -e "\n\033[1;34m==>\033[0m Setting up port hopping..."
iptables -t nat -F PREROUTING 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 10000:65000 -j REDIRECT --to-port ${PORT}
iptables -t nat -A PREROUTING -p udp --dport ${PORT} -j REDIRECT --to-port ${PORT}
systemctl daemon-reload && systemctl enable hysteria && systemctl restart hysteria
sleep 3
systemctl is-active hysteria && echo "✅ Hysteria: active" || echo "❌ Hysteria: failed"
cat > /etc/showon.conf << E3
VERSION="V.1.0.8"
WWW_DIR="/home/vps/public_html/server"
LIMIT=50
NET_IFACE="eth0"
AGN_PRESENT=1
AGN_PORT="${PORT}"
E3
cat > /usr/local/bin/online-check.sh << 'E4'
#!/bin/bash
WWW="/home/vps/public_html/server"; LIMIT=50; AGN_PORT=36712
[ -f /etc/showon.conf ] && . /etc/showon.conf
mkdir -p "$WWW"; NOW=$(date +%s%3N)
SSH_ON=$(ss -tn state established 2>/dev/null | grep -E ':22\s' | wc -l)
AGNUDP_ON=0
[ -n "$AGN_PORT" ] && command -v conntrack >/dev/null 2>&1 && {
  SIP=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}')
  ips=$(conntrack -L -p udp 2>/dev/null | grep "sport=${AGN_PORT}" | grep -oP 'dst=\K[0-9.]+' | sort -u)
  [ -n "$ips" ] && AGNUDP_ON=$(echo "$ips" | grep -vE "^${SIP}$|^127\." | wc -l)
}
TOTAL=$((SSH_ON + AGNUDP_ON))
echo "[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"0\",\"dropbear\":\"0\",\"v2ray\":\"0\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]" > "$WWW/online_app.json"
E4
chmod +x /usr/local/bin/online-check.sh
printf '[Unit]\nDescription=Online Check\n[Service]\nType=simple\nExecStart=/usr/local/bin/online-check.sh\n' > /etc/systemd/system/online-check.service
printf '[Unit]\nDescription=Online Check Timer\n[Timer]\nOnBootSec=10\nOnUnitActiveSec=10\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/online-check.timer
systemctl enable --now online-check.timer 2>/dev/null
wget -q https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/sysinfo.sh -O /usr/local/bin/sysinfo.sh
chmod +x /usr/local/bin/sysinfo.sh
printf '[Unit]\nDescription=System Info\n[Service]\nType=simple\nExecStart=/usr/local/bin/sysinfo.sh\nRestart=on-failure\n' > /etc/systemd/system/sysinfo.service
systemctl enable --now sysinfo 2>/dev/null
cat > /usr/local/bin/vnstat-traffic.sh << 'E6'
#!/bin/bash
WWW="/home/vps/public_html/server"
while true; do
  RX=$(vnstat --json d 2>/dev/null|python3 -c "import json,sys;d=json.load(sys.stdin);dx=d.get('interfaces',[{}])[0].get('traffic',{}).get('days',[{}])[0];print(dx.get('rx',0))" 2>/dev/null||echo 0)
  TX=$(vnstat --json d 2>/dev/null|python3 -c "import json,sys;d=json.load(sys.stdin);dx=d.get('interfaces',[{}])[0].get('traffic',{}).get('days',[{}])[0];print(dx.get('tx',0))" 2>/dev/null||echo 0)
  echo "{\"vnstat_rx\":\"$RX\",\"vnstat_tx\":\"$TX\",\"v2ray_up\":\"0\",\"v2ray_down\":\"0\"}" > "$WWW/netinfo.json"
  sleep 30
done
E6
chmod +x /usr/local/bin/vnstat-traffic.sh
printf '[Unit]\nDescription=Traffic\n[Service]\nType=simple\nExecStart=/usr/local/bin/vnstat-traffic.sh\nRestart=on-failure\n' > /etc/systemd/system/vnstat-traffic.service
systemctl enable --now vnstat-traffic 2>/dev/null
wget -q https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/web/index.html -O /home/vps/public_html/server/index.html
cat > /etc/nginx/conf.d/dashboard.conf << 'E8'
server {listen 82;root /home/vps/public_html;index index.html;location /server/{alias /home/vps/public_html/server/;}}
E8
nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null
wget -q https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/menu.py -O /opt/hysteria/menu.py 2>/dev/null || true
chmod +x /opt/hysteria/menu.py 2>/dev/null
printf '#!/bin/bash\npython3 /opt/hysteria/menu.py\n' > /usr/local/bin/showon && chmod +x /usr/local/bin/showon
echo ""; echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo -e "\033[1;33m  🚀 Installation Complete!\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo "  Hysteria : $(systemctl is-active hysteria)"
echo "  Auth     : ${AUTH}"
echo "  OBFS     : ${OBFS}"
echo "  Dashboard: http://${SERVER_IP}:82/server/"
echo "  Type: showon → for menu"
