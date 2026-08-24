#!/bin/bash
BASE="https://raw.githubusercontent.com/EkromSSH/hysteria-install/main"
curl -sL "$BASE/scripts/online-check.sh" -o /usr/local/bin/online-check.sh 2>/dev/null
curl -sL "$BASE/scripts/sysinfo.sh" -o /usr/local/bin/sysinfo.sh 2>/dev/null
curl -sL "$BASE/scripts/vnstat-traffic.sh" -o /usr/local/bin/vnstat-traffic.sh 2>/dev/null
curl -sL "$BASE/web/index.html" -o /home/vps/public_html/server/index.html 2>/dev/null
curl -sL "$BASE/install.sh" -o /tmp/ida-update.sh 2>/dev/null
chmod +x /opt/hysteria/menu.py /usr/local/bin/online-check.sh /usr/local/bin/sysinfo.sh /usr/local/bin/vnstat-traffic.sh /tmp/ida-update.sh 2>/dev/null
chown -R www-data:www-data /home/vps/public_html/server 2>/dev/null
# Update config: ensure disable_mtu_discovery=false for YouTube/QUIC
if [ -f /opt/hysteria/config-v1.json ]; then
  sed -i 's/"disable_mtu_discovery": true/"disable_mtu_discovery": false/' /opt/hysteria/config-v1.json
  systemctl restart hysteria 2>/dev/null || true
fi
systemctl restart online-check sysinfo vnstat-traffic 2>/dev/null || true
