#!/bin/bash
# IDA UDPHysteria Manager v3.0 - Python Boxed Menu
# 🔥 เรียกใช้งาน: bash <(curl -sL https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.sh)
PY="/root/hysteria-menu.py"
[ -f "$PY" ] || curl -sL "https://raw.githubusercontent.com/EkromSSH/hysteria-install/main/menu.py" -o "$PY" 2>/dev/null
chmod +x "$PY" 2>/dev/null
python3 "$PY" || { echo -e "\033[0;31m❌ ติดตั้ง Python 3 ก่อนใช้งาน\033[0m"; exit 1; }
