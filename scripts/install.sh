#!/bin/bash
set -e
echo "=== IDA UDPHysteria Auto Installer ==="
read -p "Server IP: " SERVER_IP
read -p "Port (default 25000): " PORT
PORT=${PORT:-25000}
read -p "Auth (default ring): " AUTH
AUTH=${AUTH:-ring}
read -p "OBFS (min 10 chars, default adminadmin12): " OBFS
OBFS=${OBFS:-adminadmin12}
read -p "Enable Web Dashboard? (y/n, default n): " DASH
DASH=${DASH:-n}

echo "=== Creating dirs ==="
mkdir -p /opt/hysteria/certs /etc/hysteria/client
chmod 755 /opt/hysteria /opt/hysteria/certs

echo "=== Copying files ==="
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/menu.py" /opt/hysteria/menu.py
chmod +x /opt/hysteria/menu.py

echo "=== Generating certs ==="
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/hysteria/certs/server.key \
  -out /opt/hysteria/certs/server.crt \
  -subj "/C=TH/ST=Bangkok/L=Bangkok/O=IDA VPN/CN=${SERVER_IP}" 2>/dev/null
chmod 600 /opt/hysteria/certs/server.key
chmod 644 /opt/hysteria/certs/server.crt

echo "=== Writing config ==="
cat > /opt/hysteria/config-v1.json << EOF
{
  "listen": ":${PORT}",
  "protocol": "udp",
  "cert": "/opt/hysteria/certs/server.crt",
  "key": "/opt/hysteria/certs/server.key",
  "up_mbps": 100,
  "down_mbps": 100,
  "obfs": "${OBFS}",
  "auth_str": "${AUTH}",
  "recv_window_conn": 20971520,
  "recv_window_client": 41943040,
  "disable_mtu_discovery": false
}
EOF

echo "=== Creating start.sh ==="
cat > /opt/hysteria/start.sh << 'START_EOF'
#!/bin/bash
exec /opt/hysteria/hysteria-v1 server -c /opt/hysteria/config-v1.json
START_EOF
chmod +x /opt/hysteria/start.sh

echo "=== Creating systemd service ==="
cat > /etc/systemd/system/hysteria.service << 'SERVICE_EOF'
[Unit]
Description=Hysteria VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/hysteria/start.sh
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICE_EOF

echo "=== Enabling service ==="
systemctl daemon-reload
systemctl enable hysteria.service
systemctl restart hysteria.service
sleep 2

echo "=== Verification ==="
PORT_BIND=$(ss -ulnp | grep ":${PORT} " | head -1)
if [ -n "$PORT_BIND" ]; then
  echo "✅ Port ${PORT} listening"
else
  echo "❌ Port ${PORT} NOT listening — check with: journalctl -u hysteria.service -n 20"
fi
systemctl is-active hysteria.service | grep -q active && echo "✅ Service active" || echo "❌ Service failed"

echo "=== Config ==="
python3 -c "import json; d=json.load(open('/opt/hysteria/config-v1.json')); print('Auth:', d['auth_str'], '| OBFS:', d['obfs'], '| Listen:', d['listen'])"

echo "=== Menu ==="
echo "Run menu: python3 /opt/hysteria/menu.py"

if [ "$DASH" = "y" ]; then
  echo "=== Dashboard install requires nginx + vnstat + conntrack + jq ==="
  echo "Run on fresh VPS: apt-get install -y nginx vnstat conntrack jq"
fi

echo "=== DONE ==="
