#!/bin/bash
echo -e "\n\033[1;34m==>\033[0m \033[1;37mIDA UDPHysteria Complete Installer v2.2\033[0m\n"

# ══ Auto-detect IP ══
echo -e "\033[1;34m==>\033[0m Detecting server IP..."
AUTO_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
          curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || \
          ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}' || \
          hostname -I | awk '{print $1}')
[ -z "$AUTO_IP" ] && AUTO_IP="0.0.0.0"
echo -e "  \033[1;32mAuto-detect:\033[0m $AUTO_IP"
echo -e "  \033[2m(Press Enter to accept auto-detect, or type custom IP)\033[0m"
read -p "Server IP [$AUTO_IP]: " SERVER_IP
SERVER_IP=${SERVER_IP:-$AUTO_IP}

# ══ Port / Auth / OBFS ══
read -p "Port [36712]: " PORT
PORT=${PORT:-36712}
read -p "Auth [idavpn]: " AUTH
AUTH=${AUTH:-idavpn}
read -p "OBFS [idavpn]: " OBFS
OBFS=${OBFS:-idavpn}

# ══ License Key Check ══
GH_REPO="EkromSSH/hysteria-install"
ADMIN_IPS=("82.26.104.48" "82.26.104.107" "82.26.104.31" "45.144.167.239")
MASTER_KEYS=("MASTER-IDAVPN-8888" "MASTER-IDAVPN-9999")

echo ""
echo -e "\033[1;34m==>\033[0m \033[1;33m🔑 License Verification\033[0m"

# Check if admin IP → bypass
IS_ADMIN=0
for ip in "${ADMIN_IPS[@]}"; do
  [[ "$SERVER_IP" == "$ip" ]] && IS_ADMIN=1 && break
done

if [[ $IS_ADMIN -eq 1 ]]; then
  echo -e "  \033[1;32m✅ Admin IP — license bypassed\033[0m"
else
  # Check master keys first
  KEY_VALID=0
  LICENSE_KEY=""
  read -p "🔑 Enter License Key: " LICENSE_KEY
  LICENSE_KEY=$(echo "$LICENSE_KEY" | xargs)
  
  for mk in "${MASTER_KEYS[@]}"; do
    [[ "$LICENSE_KEY" == "$mk" ]] && KEY_VALID=1 && break
  done
  
  # Check regular keys from keys.txt
  if [[ $KEY_VALID -eq 0 ]]; then
    KEYS_LIST=$(curl -sL "https://raw.githubusercontent.com/$GH_REPO/main/keys.txt" 2>/dev/null | grep -v "^#" | grep -v "^$")
    while IFS= read -r key; do
      [[ "$(echo "$key" | xargs)" == "$LICENSE_KEY" ]] && KEY_VALID=1 && break
    done <<< "$KEYS_LIST"
  fi
  
  if [[ $KEY_VALID -ne 1 ]]; then
    echo -e "  \033[1;31m❌ Invalid license key! Installation aborted.\033[0m"
    exit 1
  fi
  echo -e "  \033[1;32m✅ License key valid!\033[0m"
fi

# ══ Handle apt lock gracefully ══
echo -e "\n\033[1;34m==>\033[0m Installing packages..."
for i in 1 2 3; do
  apt-get update -qq 2>/dev/null && break
  echo "  apt busy or locked, clearing lock... ($i/3)"
  lsof /var/lib/dpkg/lock-frontend 2>/dev/null | awk 'NR>1{print $2}' | xargs -r kill 2>/dev/null
  rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock 2>/dev/null
  dpkg --configure -a 2>/dev/null
  sleep 3
done
apt-get install -y wget curl openssl nginx vnstat conntrack jq python3 iptables-persistent 2>&1 | tail -2

# ══ Download Hysteria ══
echo -e "\n\033[1;34m==>\033[0m Downloading Hysteria v1.3.5..."
wget -q https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64 -O /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria
mkdir -p /etc/hysteria /home/vps/public_html/server
chmod o+x /home/vps 2>/dev/null

# ══ Generate certificates ══
echo -e "\n\033[1;34m==>\033[0m Generating certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/C=TH/ST=Bangkok/L=Bangkok/O=IDA VPN/CN=${SERVER_IP}" 2>/dev/null
chmod 600 /etc/hysteria/server.key

# ══ Config ══
cat > /opt/hysteria/config-v1.json << EOF
{
  "listen": ":${PORT}",
  "protocol": "udp",
  "cert": "/etc/hysteria/server.crt",
  "key": "/etc/hysteria/server.key",
  "up_mbps": 100,
  "down_mbps": 100,
  "obfs": "${OBFS}",
  "auth_str": "${AUTH}",
  "disable_mtu_discovery": true
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

# ══ Port hopping ══
echo -e "\n\033[1;34m==>\033[0m Setting up port hopping..."
iptables -t nat -F PREROUTING 2>/dev/null
iptables -t nat -A PREROUTING -p udp --dport 10000:65000 -j REDIRECT --to-port ${PORT}
iptables -t nat -A PREROUTING -p udp --dport ${PORT} -j REDIRECT --to-port ${PORT}

systemctl daemon-reload && systemctl enable hysteria && systemctl restart hysteria
sleep 3
systemctl is-active hysteria && echo "✅ Hysteria: active" || echo "❌ Hysteria: failed"

# ══ showon.conf ══
cat > /etc/showon.conf << E3
VERSION="V.2.2"
WWW_DIR="/home/vps/public_html/server"
LIMIT=50
NET_IFACE="eth0"
AGN_PRESENT=1
AGN_PORT="${PORT}"
E3

# ══ Scripts ══
cat > /usr/local/bin/online-check.sh << 'E4'
#!/bin/bash
WWW="/home/vps/public_html/server"; LIMIT=50; AGN_PORT=36712
[ -f /etc/showon.conf ] && . /etc/showon.conf
mkdir -p "$WWW"; NOW=$(date +%s%3N)
SSH_ON=$(ps aux | grep 'sshd:' | grep -v 'listener\|grep\|root' | awk '{print $1}' | sort -u | wc -l)
AGNUDP_ON=0
[ -n "$AGN_PORT" ] && command -v conntrack >/dev/null 2>&1 && {
  SIP=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}')
  SNET=$(echo "$SIP" | cut -d. -f1-3)
  ips=$(conntrack -L -p udp 2>/dev/null | grep "sport=${AGN_PORT}" | grep -v "sport=443 " | sed "s/.* dst=\([0-9.]*\) sport=${AGN_PORT}.*/\1/" | sort -u)
  [ -n "$ips" ] && AGNUDP_ON=$(echo "$ips" | grep -vE "^${SIP}$|^127\.|^${SNET}\." | wc -l)
}
TOTAL=$((SSH_ON + AGNUDP_ON))
echo "[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"0\",\"dropbear\":\"0\",\"v2ray\":\"0\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]" > "$WWW/online_app.json"
E4
chmod +x /usr/local/bin/online-check.sh
printf '[Unit]\nDescription=Online Check\n[Service]\nType=simple\nExecStart=/usr/local/bin/online-check.sh\n' > /etc/systemd/system/online-check.service
printf '[Unit]\nDescription=Online Check Timer\n[Timer]\nOnBootSec=10\nOnUnitActiveSec=10\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/online-check.timer
systemctl enable --now online-check.timer 2>/dev/null

cat > /usr/local/bin/sysinfo.sh << 'E5'
#!/bin/bash
WWW="/home/vps/public_html/server"
while true; do
  C1=$(awk 'NR==1{print $2+$4+$5}' /proc/stat); I1=$(awk 'NR==1{print $2+$4}' /proc/stat)
  sleep 1
  C2=$(awk 'NR==1{print $2+$4+$5}' /proc/stat); I2=$(awk 'NR==1{print $2+$4}' /proc/stat)
  CPU=$(awk -v u=$((I2-I1)) -v c=$((C2-C1)) 'BEGIN{if(c>0)printf "%d",u*100/c;else print 0}')
  UPTIME=$(uptime -p | sed 's/up //')
  RAM_U=$(free -m|awk '/^Mem:/{print $3}'); RAM_T=$(free -m|awk '/^Mem:/{print $2}')
  DISK=$(df -h /|awk 'NR==2{print $3"/"$2}')
  echo "[{\"uptime\":\"$UPTIME\",\"cpu_usage\":\"${CPU:-0}%\",\"ram_usage\":\"$RAM_U/${RAM_T}MB\",\"disk_usage\":\"$DISK\"}]" > "$WWW/sysinfo.json"
  sleep 29
done
E5
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

# ══ Dashboard HTML ══
cat > /home/vps/public_html/server/index.html << 'E7'
<!doctype html><html lang="en"><head><meta charset="utf-8"/><title>IDA UDPHysteria Dashboard V.1.0.7</title>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0d1117;color:#e6edf3;font-family:sans-serif;max-width:1200px;margin:0 auto;padding:20px}
h1{font-size:1.6rem;margin-bottom:16px}h2{font-size:1.2rem;margin-bottom:10px}
.grid{display:grid;gap:20px}@media(min-width:900px){.grid{grid-template-columns:1fr 1fr}}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:16px}
table{width:100%;border-collapse:collapse;margin-top:10px}
th,td{padding:10px;text-align:center}th{background:#1f242c;color:#c9d1d9}
td{border-top:1px solid #2d333b}.ok{color:#3fb950;font-weight:600}
@media(max-width:600px){body{padding:10px}h1{font-size:1.2rem}table{font-size:.7rem}th,td{padding:6px 3px}.table-wrap{overflow-x:auto}}
</style></head><body>
<h1>IDA UDPHysteria Dashboard V.1.0.7</h1><div class="grid">
<div class="card"><h2>Online Summary</h2><div class="table-wrap"><table><thead><tr><th>✅ Total</th><th>🎯 Limit</th><th>🔒 SSH</th><th>🌐 OpenVPN</th><th>⚫ Dropbear</th><th>⚡ V2Ray</th><th>📡 AGN-UDP</th></tr></thead>
<tbody><tr id="row-online"><td colspan="7">Loading...</td></tr></tbody></table></div></div>
<div class="card"><h2>System</h2><div class="mono" id="sys">Loading...</div></div>
<div class="card"><h2>Traffic</h2><table><thead id="traffic-head"></thead><tbody><tr id="row-net"><td>Loading...</td></tr></tbody></table></div></div>
<script>
const j=async u=>{const r=await fetch(u+"?_="+Date.now(),{cache:"no-store"});if(!r.ok)throw new Error(r.status);return r.json()};
let lo=null,ls=null,lt=null;
async function refresh(){
try{const a=await j('./online_app.json');lo=Array.isArray(a)?a[0]:a}catch(e){}
try{const s=await j('./sysinfo.json');ls=Array.isArray(s)?s[0]:s}catch(e){}
try{const n=await j('./netinfo.json');lt=Array.isArray(n)?n[0]:n}catch(e){}
if(lo)document.getElementById('row-online').innerHTML='<td class="ok">'+lo.onlines+'</td><td>'+lo.limite+'</td><td>'+lo.ssh+'</td><td>'+lo.openvpn+'</td><td>'+lo.dropbear+'</td><td>'+lo.v2ray+'</td><td>'+lo.agnudp+'</td>'
if(ls)document.getElementById('sys').innerHTML='<b>Uptime:</b> '+ls.uptime+' · <b>CPU:</b> '+ls.cpu_usage+' · <b>RAM:</b> '+ls.ram_usage+' · <b>Disk:</b> '+ls.disk_usage
if(lt)document.getElementById('row-net').innerHTML='<td>'+lt.vnstat_rx+' B</td><td>'+lt.vnstat_tx+' B</td>'
}
setInterval(refresh,5000);refresh()
</script></body></html>
E7

# ══ Nginx ══
cat > /etc/nginx/conf.d/dashboard.conf << 'E8'
server {listen 82;root /home/vps/public_html;index index.html;location /server/{alias /home/vps/public_html/server/;}}
E8
nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null

# ══ Download menu ══
wget -q https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/menu.py -O /opt/hysteria/menu.py 2>/dev/null || true
chmod +x /opt/hysteria/menu.py 2>/dev/null
printf '#!/bin/bash\npython3 /opt/hysteria/menu.py\n' > /usr/local/bin/showon && chmod +x /usr/local/bin/showon

# ══ Fresh update: download latest scripts from GitHub ══
echo -e "\n\033[1;34m==>\033[0m Updating to latest scripts..."
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/web/index.html -o /home/vps/public_html/server/index.html 2>/dev/null
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/online-check.sh -o /usr/local/bin/online-check.sh 2>/dev/null
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/sysinfo.sh -o /usr/local/bin/sysinfo.sh 2>/dev/null
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/vnstat-traffic.sh -o /usr/local/bin/vnstat-traffic.sh 2>/dev/null
curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/scripts/menu.py -o /opt/hysteria/menu.py 2>/dev/null
chmod +x /usr/local/bin/online-check.sh /usr/local/bin/sysinfo.sh /usr/local/bin/vnstat-traffic.sh /opt/hysteria/menu.py 2>/dev/null
chown -R www-data:www-data /home/vps/public_html/server 2>/dev/null
systemctl restart online-check sysinfo vnstat-traffic 2>/dev/null || true

# ══ Auto-update menu (every 6 hours) ══
cat > /opt/hysteria/auto-update.sh << 'AU'
#!/bin/bash
BASE="https://raw.githubusercontent.com/EkromSSH/hysteria-install/main"
curl -sL "$BASE/scripts/menu.py" -o /opt/hysteria/menu.py 2>/dev/null
curl -sL "$BASE/scripts/online-check.sh" -o /usr/local/bin/online-check.sh 2>/dev/null
curl -sL "$BASE/scripts/sysinfo.sh" -o /usr/local/bin/sysinfo.sh 2>/dev/null
curl -sL "$BASE/scripts/vnstat-traffic.sh" -o /usr/local/bin/vnstat-traffic.sh 2>/dev/null
curl -sL "$BASE/web/index.html" -o /home/vps/public_html/server/index.html 2>/dev/null
curl -sL "$BASE/install.sh" -o /tmp/ida-update.sh 2>/dev/null
chmod +x /opt/hysteria/menu.py /usr/local/bin/online-check.sh /usr/local/bin/sysinfo.sh /usr/local/bin/vnstat-traffic.sh /tmp/ida-update.sh 2>/dev/null
chown -R www-data:www-data /home/vps/public_html/server 2>/dev/null
systemctl restart online-check sysinfo vnstat-traffic 2>/dev/null || true
AU
chmod +x /opt/hysteria/auto-update.sh
echo "0 */6 * * * root /opt/hysteria/auto-update.sh" > /etc/cron.d/ida-auto-update

# ══ Done ══
echo ""
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo -e "\033[1;33m  🚀 Installation Complete!\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo "  Hysteria : $(systemctl is-active hysteria)"
echo "  Auth     : ${AUTH}"
echo "  OBFS     : ${OBFS}"
echo "  Dashboard: http://${SERVER_IP}:82/server/"
echo "  Type: showon → for menu"
echo ""
echo -e "\033[1;32m  ✅ Menu auto-updates every 6 hours\033[0m"
echo -e "\033[1;32m  ✅ IP auto-detected: ${SERVER_IP}\033[0m"
