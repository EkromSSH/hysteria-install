#!/bin/bash
# IDA UDPHysteria Manager v3.0 — Bash Wrapper (เรียก Python backend)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/hysteria-menu.py"

# ถ้าไฟล์ Python อยู่ในที่อื่น ให้หาให้
[ -f "$SCRIPT_PATH" ] || SCRIPT_PATH="/root/hysteria-menu.py"
[ -f "$SCRIPT_PATH" ] || SCRIPT_PATH="$(which hysteria-menu.py 2>/dev/null)"
[ -f "$SCRIPT_PATH" ] || { echo -e "\033[0;31m❌ ไม่พบ hysteria-menu.py\033[0m"; exit 1; }

python3 "$SCRIPT_PATH" "$@"
