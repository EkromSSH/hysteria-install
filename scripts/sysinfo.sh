#!/bin/bash
WWW_DIR="/home/vps/public_html/server"
CONF="/etc/showon.conf"
[[ -f "$CONF" ]] && source "$CONF"
WWW_DIR=${WWW_DIR:-/home/vps/public_html/server}
mkdir -p "$WWW_DIR"

uptime=$(uptime -p | sed 's/^up //')
# Better CPU calculation
cpu_idle=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}' 2>/dev/null || echo "0")
cpu_idle=${cpu_idle%%%}  # Remove % sign if present
cpu_use=$(awk -v f="$cpu_idle" 'BEGIN{printf("%.1f%%",100-f)}')
ram=$(free -m | awk 'NR==2{printf "%s/%sMB",$3,$2}')
disk=$(df -h / | awk 'NR==2{printf "%s/%s",$3,$2}')

cat > "$WWW_DIR/sysinfo.json" << JSON
[{"uptime":"$uptime","cpu_usage":"$cpu_use","ram_usage":"$ram","disk_usage":"$disk"}]
JSON

chmod 644 "$WWW_DIR/sysinfo.json" 2>/dev/null
