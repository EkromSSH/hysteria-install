#!/bin/bash
CONF="/etc/showon.conf"
WWW_DIR_DEFAULT="/home/vps/public_html/server"
LIMIT_DEFAULT=50
WWW_DIR="$WWW_DIR_DEFAULT"
LIMIT="$LIMIT_DEFAULT"
AGN_PORT="36712"
STATE="/tmp/agnudp_state"
KEEP=30   # เก็บสถานะ IP ที่เห็นไว้ 30 วินาที (เลิกต่อแล้วหายหลัง 30 วิ)

if [[ -f "$CONF" ]]; then
  . "$CONF"
fi

mkdir -p "$WWW_DIR"
ONLINE_JSON="$WWW_DIR/online_app.json"
NOW="$(date +%s%3N)"
NOW_S=$((NOW/1000))

# นับเฉพาะ Inbound (คนเชื่อมเข้ามา) พอร์ตอื่นนับปกติ พอร์ต 22 ไม่นับ
SERVER_IP=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}')
SUBNET=$(echo "$SERVER_IP" | cut -d. -f1-3)
# รวม IP ที่ต้องไม่นับ (ตัวเอง + hub/termius จาก showon.conf)
EXCLUDE="$SERVER_IP"
[ -n "$MY_IPS" ] && EXCLUDE="$EXCLUDE|$MY_IPS"
# เอารายการพอร์ตที่เครื่องเราฟังอยู่ (listening) ยกเว้น 22
LPORTS=$(ss -tlnp 2>/dev/null | awk '{print $4}' | grep -oE ':[0-9]+$' | tr -d ':' | grep -v '^22$' | sort -u | tr '\n' '|')
LPORTS="${LPORTS%|}"
SSH_ON=0
# ดูการต่อที่ established: คอลัมน์4=Local คอลัมน์5=Peer
while read -r _ _ local peer _; do
  [ -z "$local" ] && continue
  lport=${local##*:}
  echo "$LPORTS" | grep -qw "$lport" || continue
  pip=${peer%%:*}
  [ -z "$pip" ] && continue
  if ! echo "$pip" | grep -qE "^(${EXCLUDE})$|^127\.|^${SUBNET}\."; then
    SSH_ON=$((SSH_ON+1))
  fi
done < <(ss -tnp state established 2>/dev/null | grep -v '^Recv')
DB_ON=0; OVPN_ON=0; V2_ON=0; AGNUDP_ON=0

if [[ -n "$AGN_PORT" ]] && command -v conntrack >/dev/null 2>&1; then
  SERVER_IP=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $7}')
  SUBNET=$(echo "$SERVER_IP" | cut -d. -f1-3)
  ips=$(conntrack -L -p udp 2>/dev/null | grep "sport=${AGN_PORT}" | grep -v "sport=443 " | sed "s/.* dst=\([0-9.]*\) sport=${AGN_PORT}.*/\1/" | sort -u | grep -vE "^${SERVER_IP}$|^127\.|^${SUBNET}\.")
  touch "$STATE" 2>/dev/null
  # ลบรายการที่หมดอายุ (เกิน KEEP วินาที)
  while IFS='|' read -r ip ts; do
    [ -z "$ip" ] && continue
    if [ $((NOW_S - ${ts:-0})) -gt $KEEP ]; then
      sed -i "/^${ip}|/d" "$STATE" 2>/dev/null
    fi
  done < "$STATE"
  # เพิ่ม/อัปเดต IP ที่เห็นรอบนี้
  for ip in $ips; do
    sed -i "/^${ip}|/d" "$STATE" 2>/dev/null
    echo "${ip}|${NOW_S}" >> "$STATE"
  done
  AGNUDP_ON=$(wc -l < "$STATE" 2>/dev/null || echo 0)
fi

TOTAL=$(( SSH_ON + DB_ON + OVPN_ON + V2_ON + AGNUDP_ON ))
echo "[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]" > "$ONLINE_JSON"
exit 0
