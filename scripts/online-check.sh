#!/bin/bash
set -u -o pipefail
CONF="/etc/showon.conf"
WWW_DIR_DEFAULT="/home/vps/public_html/server"
LIMIT_DEFAULT=50
WWW_DIR="$WWW_DIR_DEFAULT"
LIMIT="$LIMIT_DEFAULT"
AGN_PORT="36712"

if [[ -f "$CONF" ]]; then
  . "$CONF"
fi

mkdir -p "$WWW_DIR"
ONLINE_JSON="$WWW_DIR/online_app.json"
NOW="$(date +%s%3N)"

SSH_ON=$(ss -tn state established 2>/dev/null | grep -E ":22\s" | wc -l)
DB_ON=0; OVPN_ON=0; V2_ON=0; AGNUDP_ON=0

if [[ -n "$AGN_PORT" ]] && command -v conntrack >/dev/null 2>&1; then
  SERVER_IP=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}')
  ips=$(conntrack -L -p udp 2>/dev/null | grep "sport=${AGN_PORT} " | grep -oP 'dst=\K[0-9.]+' | sort -u)
  if [[ -n "$ips" ]]; then
    AGNUDP_ON=$(echo "$ips" | grep -vE "^${SERVER_IP}$|^127\." | wc -l)
  fi
fi

TOTAL=$(( SSH_ON + DB_ON + OVPN_ON + V2_ON + AGNUDP_ON ))
echo "[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]" > "$ONLINE_JSON"
exit 0
