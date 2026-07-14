#!/bin/bash

# ═══════════════════════════════════════════════════════════
#   ██  ██████  █████   ██   ██ ██    ██ ██████  ██   ██
#   ██ ██    ██ ██   █  ██   ██ ██    ██ ██   ██ ██  ██
#   ██ ██    ██ █████   ██   ██ ██    ██ ██████  █████
#   ██ ██    ██ ██   █   ██ ██  ██    ██ ██   ██ ██  ██
#   ██  ██████  █████     ███    ██████  ██   ██ ██   ██
#
#   ██   ██ ██    ██ ██████  ██████  ██   ██
#   ██   ██  ██  ██  ██   ██ ██   ██  ██ ██
#   ███████   ████   ██████  ██████    ███
#   ██   ██    ██    ██      ██       ██ ██
#   ██   ██    ██    ██      ██      ██   ██
# ═══════════════════════════════════════════════════════════
#   IDA UDPHysteria Manager v2.0
#   ⚡ จัดการ Hysteria v1 ภาษาไทย
# ═══════════════════════════════════════════════════════════

HYST_CONFIG="/opt/hysteria/config-v1.json"
HYST_SERVICE="hysteria"
HYST_BIN="/opt/hysteria/hysteria-v1"

# ════════════ สี ════════════
RED='\033[0;31m'; GREEN='\033[0;32m'; ORANGE='\033[0;33m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
DIM='\033[2m'; NC='\033[0m'

# ════════════ จัดตำแหน่งแม่นยำ (Python: ไม่นับตัวควบ ◌ิ◌์) ════════════
vislen() {
    echo -n "$1" | python3 -c "import sys, unicodedata; print(sum(1 for c in sys.stdin.read() if unicodedata.category(c) != 'Mn'))" 2>/dev/null
}
pad() {
    local s="$1" w="$2"
    local n; n=$(vislen "$s")
    printf "%s" "$s"
    if [ "${n:-0}" -lt "$w" ]; then
        printf "%*s" $((w - n)) ""
    fi
}

rgb_bar() { echo -e "  ${RED}▐${ORANGE}▐${YELLOW}▐${GREEN}▐${CYAN}▐${BLUE}▐${MAGENTA}▐${NC}"; }
sep() { echo -e "  ${DIM}──────────────────────────────────────────${NC}"; }
dash() { echo -e "  ${DIM}┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈${NC}"; }

# ════════════ หัวข้อ ════════════

show_brand() {
    echo ""
    echo -e "  ${RED}██${ORANGE}██${YELLOW}██${GREEN}██${CYAN}██${BLUE}██${MAGENTA}██${NC}  ${BOLD}${WHITE}IDA UDPHysteria${NC}  ${RED}██${ORANGE}██${YELLOW}██${GREEN}██${CYAN}██${BLUE}██${MAGENTA}██${NC}"
    echo -e "  ${DIM}       🚀 ระบบจัดการ Hysteria v1${NC}"
    echo ""
}

show_header() {
    clear
    show_brand
    sep

    local IP STATUS UPTIME_RAW HYST_PORT ONLINE
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "ไม่ทราบ")
    STATUS=$(systemctl is-active $HYST_SERVICE 2>/dev/null)
    UPTIME_RAW=$(systemctl status $HYST_SERVICE --no-pager 2>/dev/null | grep "Active:" | sed 's/.*since //; s/;.*//' | head -c 40)
    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    ONLINE=$(count_online_users 2>/dev/null || echo "0")

    echo ""
    echo -e "  ${BOLD}${WHITE}📋 ข้อมูลเซิร์ฟเวอร์${NC}"
    dash
    echo -e "  $(pad "IP" 8) ${DIM}:${NC} ${WHITE}$IP${NC}"
    echo -e "  $(pad "พอร์ต" 8) ${DIM}:${NC} ${WHITE}${HYST_PORT:-25000}${NC} ${DIM}(20000-50000)${NC}"
    echo -e "  $(pad "AUTH" 8) ${DIM}:${NC} ${WHITE}$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)${NC}"
    echo -e "  $(pad "OBFS" 8) ${DIM}:${NC} ${WHITE}$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)${NC}"
    if [ "$STATUS" = "active" ]; then
        echo -e "  $(pad "สถานะ" 8) ${DIM}:${NC} ${GREEN}✅ ONLINE${NC} ${DIM}|${NC} ${YELLOW}👥 $ONLINE คน${NC}"
        echo -e "  $(pad "เวลา" 8) ${DIM}:${NC} ${DIM}${WHITE}$UPTIME_RAW${NC}"
    else
        echo -e "  $(pad "สถานะ" 8) ${DIM}:${NC} ${RED}❌ OFFLINE${NC}"
    fi
    echo ""
    sep
    echo ""
}

# ════════════ เมนู ════════════

show_menu() {
    echo -e "  ${BOLD}${WHITE}🎯 เมนู${NC}"
    dash
    echo ""

    echo -e "  ${YELLOW}▎${NC} ${BOLD}${DIM}จัดการ${NC}"
    echo -e "  ${GREEN}[01]${NC}  📊 ข้อมูลเชื่อมต่อ     ${DIM}→ รายละเอียดให้ Creeb${NC}"
    echo -e "  ${GREEN}[02]${NC}  🔄 รีสตาร์ท           ${DIM}→ รีบูต Hysteria${NC}"
    echo -e "  ${GREEN}[03]${NC}  ⛔ หยุด               ${DIM}→ หยุดเซอร์วิส${NC}"
    echo -e "  ${GREEN}[04]${NC}  ▶ เริ่ม              ${DIM}→ เริ่ม Hysteria${NC}"
    echo -e "  ${GREEN}[05]${NC}  📜 ดู Logs            ${DIM}→ 10 นาทีล่าสุด${NC}"
    echo -e "  ${GREEN}[06]${NC}  🔍 ข้อมูลระบบ         ${DIM}→ CPU/RAM/สปีด${NC}"
    echo ""

    echo -e "  ${MAGENTA}▎${NC} ${BOLD}${DIM}ตั้งค่า${NC}"
    echo -e "  ${MAGENTA}[07]${NC}  🔑 แก้ AUTH          ${DIM}→ เปลี่ยนรหัส${NC}"
    echo -e "  ${MAGENTA}[08]${NC}  🔏 แก้ OBFS          ${DIM}→ เปลี่ยนรหัสพราง${NC}"
    echo -e "  ${MAGENTA}[09]${NC}  🔧 เปลี่ยนพอร์ต      ${DIM}→ เปลี่ยนเลข${NC}"
    echo ""

    echo -e "  ${CYAN}▎${NC} ${BOLD}${DIM}พิเศษ${NC}"
    echo -e "  ${YELLOW}[10]${NC}  👥 ผู้ใช้ออนไลน์     ${DIM}→ สแกน 5 วิ${NC}"
    echo -e "  ${GREEN}[11]${NC}  🌐 ทดสอบความเร็ว     ${DIM}→ Speed Test${NC}"
    echo ""

    echo -e "  ${RED}▎${NC} ${BOLD}${DIM}ออก${NC}"
    echo -e "  ${RED}[00]${NC}  🚪 ออกจากโปรแกรม      ${DIM}→ Exit${NC}"
    echo ""
    dash
    echo ""
}

# ════════════ เช็คผู้ใช้ออนไลน์ ════════════

count_online_users() {
    local HYST_PORT MY_IP COUNT
    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    [ -z "$HYST_PORT" ] && HYST_PORT=25000
    MY_IP=$(curl -s ifconfig.me 2>/dev/null)
    COUNT=$(timeout 1.5 tcpdump -i any -c 5 -n udp port "$HYST_PORT" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | grep -v "$MY_IP" | grep -v "^0\.0\.0\.0$" | grep -v "^127\." | wc -l 2>/dev/null)
    echo "${COUNT:-0}"
}

check_online_users() {
    clear
    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}${WHITE}👥 ผู้ใช้ออนไลน์ 🔍${NC}                  ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""

    local HYST_PORT MY_IP
    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    [ -z "$HYST_PORT" ] && HYST_PORT=25000
    MY_IP=$(curl -s ifconfig.me 2>/dev/null)

    echo -e "  ${YELLOW}⏳ กำลังสแกน (5 วินาที)...${NC}"
    echo ""
    CLIENTS=$(timeout 5 tcpdump -i any -n udp port "$HYST_PORT" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | grep -v "$MY_IP" | grep -v "^0\.0\.0\.0$" | grep -v "^127\." | head -50)
    sep

    if [ -z "$CLIENTS" ]; then
        echo -e "  👥 ${WHITE}ไม่มีผู้ใช้ขณะนี้${NC}"
    else
        NUM=$(echo "$CLIENTS" | wc -l)
        echo -e "  👥 ${BOLD}${GREEN}ออนไลน์ $NUM คน${NC}"
        echo ""
        local i=1
        echo "$CLIENTS" | while read -r ip; do
            [ -z "$ip" ] && continue
            HOST=$(nslookup "$ip" 2>/dev/null | grep "name = " | head -1 | sed 's/.*name = //' | sed 's/\.$//')
            if [ -n "$HOST" ]; then
                printf "  ${GREEN}%-3s${NC} ${YELLOW}%-15s${NC} ${DIM}(%s)${NC}\n" " $i." "$ip" "$HOST"
            else
                printf "  ${GREEN}%-3s${NC} ${WHITE}%-15s${NC}\n" " $i." "$ip"
            fi
            i=$((i + 1))
        done
    fi
    sep
    echo ""
    echo -e "  ${BOLD}${WHITE}📊 สถิติ${NC}"
    dash
    local IFACE
    IFACE=$(ip route get 1 2>/dev/null | grep -o 'dev [^ ]*' | cut -d' ' -f2 | head -1)
    local RX TX
    RX=$(cat /proc/net/dev 2>/dev/null | grep "$IFACE" | awk '{print $2}')
    TX=$(cat /proc/net/dev 2>/dev/null | grep "$IFACE" | awk '{print $10}')
    [ -n "$RX" ] && [ "$RX" -gt 0 ] && echo -e "  $(pad "⬇ ดาวน์โหลด" 14) ${DIM}:${NC} ${WHITE}$(numfmt --to=iec $RX 2>/dev/null || echo "$RX B")${NC}"
    [ -n "$TX" ] && [ "$TX" -gt 0 ] && echo -e "  $(pad "⬆ อัปโหลด" 14) ${DIM}:${NC} ${WHITE}$(numfmt --to=iec $TX 2>/dev/null || echo "$TX B")${NC}"
    HPID=$(pgrep hysteria-v1 2>/dev/null)
    [ -n "$HPID" ] && echo -e "  $(pad "PID" 14) ${DIM}:${NC} ${WHITE}$HPID${NC}"
    echo ""; rgb_bar; echo ""
    echo -ne "  ${BLUE}กด Enter${NC}"; read -r
}

# ════════════ ฟังก์ชันอื่นๆ ════════════

show_connection_info() {
    clear; echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}📊 ข้อมูลเชื่อมต่อ${NC}                       ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    local IP AUTH OBFS
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "ไม่ทราบ")
    AUTH=$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)
    OBFS=$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)
    sep
    echo -e "  $(pad "📡 โปรโตคอล" 16) ${DIM}:${NC} ${WHITE}UDP Hysteria v1${NC}"
    echo -e "  $(pad "🌐 เซิร์ฟเวอร์" 16) ${DIM}:${NC} ${WHITE}$IP${NC}"
    echo -e "  $(pad "🔌 พอร์ต" 16) ${DIM}:${NC} ${WHITE}25000${NC} ${DIM}(20000-50000)${NC}"
    echo -e "  $(pad "🔑 AUTH" 16) ${DIM}:${NC} ${WHITE}$AUTH${NC}"
    echo -e "  $(pad "🔏 OBFS" 16) ${DIM}:${NC} ${WHITE}$OBFS${NC}"
    echo -e "  $(pad "⚠ Allow Insecure" 16) ${DIM}:${NC} ${GREEN}✅ YES${NC}"
    sep
    echo ""
    echo -e "  ${DIM}💡 ใช้ตั้งค่าใน Creeb / v2 Box${NC}"
    echo ""
    echo -ne "  ${BLUE}กด Enter${NC}"; read -r
}

restart_service() {
    clear; echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}${WHITE}🔄 รีสตาร์ท${NC}                               ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar
    echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"
    systemctl restart $HYST_SERVICE 2>/dev/null; sleep 2
    if [ "$(systemctl is-active $HYST_SERVICE)" = "active" ]; then
        echo -e "\r  ${GREEN}✅${NC} ${BOLD}รีสตาร์ทสำเร็จ ✓${NC}  "
    else echo -e "\r  ${RED}❌${NC} ${BOLD}ไม่สำเร็จ${NC}  "; fi
    sleep 2
}

stop_service() {
    clear; echo ""
    echo -e "  ${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${RED}║${NC}  ${BOLD}${WHITE}⛔ หยุด${NC}                                 ${RED}║${NC}"
    echo -e "  ${RED}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar
    echo -ne "  ${YELLOW}⏳ หยุด...${NC}"
    systemctl stop $HYST_SERVICE 2>/dev/null; sleep 1
    echo -e "\r  ${GREEN}✅${NC} หยุดแล้ว"; sleep 2
}

start_service() {
    clear; echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}▶ เริ่ม${NC}                                 ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar
    echo -ne "  ${YELLOW}⏳ เริ่ม...${NC}"
    systemctl start $HYST_SERVICE 2>/dev/null; sleep 2
    if [ "$(systemctl is-active $HYST_SERVICE)" = "active" ]; then
        echo -e "\r  ${GREEN}✅${NC} ${BOLD}เริ่มสำเร็จ ✓${NC}  "
    else echo -e "\r  ${RED}❌${NC} ไม่สำเร็จ  "; fi
    sleep 2
}

view_logs() {
    clear; echo ""
    echo -e "  ${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC}  ${BOLD}${WHITE}📜 บันทึก${NC}                               ${CYAN}║${NC}"
    echo -e "  ${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  ${DIM}📄 30 บรรทัดล่าสุด (10 นาที)${NC}"; dash
    local LOGS; LOGS=$(journalctl -u $HYST_SERVICE --since "10 min ago" --no-pager 2>/dev/null | tail -30)
    if [ -n "$LOGS" ]; then echo "$LOGS" | while read -r line; do echo -e "  ${DIM}$line${NC}"; done
    else echo -e "  ${YELLOW}⚠ ไม่มี log${NC}"; fi
    echo ""; echo -ne "  ${BLUE}กด Enter${NC}"; read -r
}

system_info() {
    clear; echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔍 ข้อมูลระบบ${NC}                            ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  ${BOLD}${WHITE}💻 ฮาร์ดแวร์${NC}"; dash
    echo -e "  $(pad "CPU" 10) ${DIM}:${NC} ${WHITE}$(grep -c processor /proc/cpuinfo) แกน${NC}"
    echo -e "  $(pad "RAM" 10) ${DIM}:${NC} ${WHITE}$(free -h | awk '/^Mem:/ {print $3 "/" $2}')${NC}"
    echo -e "  $(pad "ดิสก์" 10) ${DIM}:${NC} ${WHITE}$(df -h / | awk 'NR==2 {print $3 "/" $2}')${NC}"
    echo -e "  $(pad "อัปไทม์" 10) ${DIM}:${NC} ${WHITE}$(uptime -p | sed 's/up //')${NC}"
    echo -e "  $(pad "OS" 10) ${DIM}:${NC} ${WHITE}$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | head -1 | cut -d'"' -f2)${NC}"
    echo -e "  $(pad "โหลด" 10) ${DIM}:${NC} ${WHITE}$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')${NC}"
    echo ""
    echo -e "  ${BOLD}${WHITE}🌐 Speed Test${NC}"; dash
    echo -e "  ${DIM}⏳ ทดสอบ...${NC}"
    local R; R=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null)
    if [ -n "$R" ]; then echo ""; echo "$R" | while read -r line; do echo -e "  ${GREEN}⚡${NC} ${WHITE}$line${NC}"; done
    else echo ""; echo -e "  ${RED}✗ ไม่ได้${NC}"; fi
    echo ""; echo -ne "  ${BLUE}กด Enter${NC}"; read -r
}

edit_auth() {
    clear; local C; C=$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔑 แก้ AUTH${NC}                              ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  $(pad "ปัจจุบัน" 10) ${DIM}:${NC} ${WHITE}${BOLD}$C${NC}"; dash
    echo -ne "  ${GREEN}▶${NC} ${BOLD}AUTH ใหม่${NC} : "; read -r N
    if [ -n "$N" ]; then
        sed -i "s/\"auth_str\": \"[^\"]*\"/\"auth_str\": \"$N\"/" $HYST_CONFIG
        echo ""; echo -e "  ${GREEN}✅${NC} เปลี่ยนแล้ว → ${WHITE}${BOLD}$N${NC}"
        echo ""; echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"; systemctl restart $HYST_SERVICE 2>/dev/null; sleep 2
        echo -e "\r  ${GREEN}✅${NC} เรียบร้อย  "
    else echo -e "  ${RED}✗ ยกเลิก${NC}"; fi
    sleep 2
}

edit_obfs() {
    clear; local C; C=$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔏 แก้ OBFS${NC}                              ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  $(pad "ปัจจุบัน" 10) ${DIM}:${NC} ${WHITE}${BOLD}$C${NC}"
    echo -e "  ${DIM}💡 เว้นว่าง = ปิด${NC}"; dash
    echo -ne "  ${GREEN}▶${NC} ${BOLD}OBFS ใหม่${NC} : "; read -r N
    if [ -n "$N" ]; then
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"$N\"/" $HYST_CONFIG
        echo ""; echo -e "  ${GREEN}✅${NC} เปลี่ยนแล้ว → ${WHITE}${BOLD}$N${NC}"
    else
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"\"/" $HYST_CONFIG
        echo ""; echo -e "  ${YELLOW}⚠ ปิด OBFS${NC}"; fi
    echo ""; echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"; systemctl restart $HYST_SERVICE 2>/dev/null; sleep 2
    echo -e "\r  ${GREEN}✅${NC} เรียบร้อย  "; sleep 2
}

change_port() {
    clear; local C; C=$(grep -o '":\([0-9]*\)"' $HYST_CONFIG | head -1 | tr -d ':"')
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔧 เปลี่ยนพอร์ต${NC}                          ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  $(pad "ปัจจุบัน" 10) ${DIM}:${NC} ${WHITE}${BOLD}$C${NC}"
    echo -e "  ${DIM}📌 20000-50000${NC}"; dash
    echo -ne "  ${GREEN}▶${NC} ${BOLD}พอร์ตใหม่${NC} : "; read -r N
    if [ -n "$N" ] && [ "$N" -ge 20000 ] && [ "$N" -le 50000 ] 2>/dev/null; then
        sed -i "s/\"listen\": \":[0-9]*\"/\"listen\": \":$N\"/" $HYST_CONFIG
        echo ""; echo -e "  ${GREEN}✅${NC} เปลี่ยนแล้ว → ${WHITE}${BOLD}$N${NC}"
        echo ""; echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"; systemctl restart $HYST_SERVICE 2>/dev/null; sleep 2
        echo -e "\r  ${GREEN}✅${NC} เรียบร้อย  "
    else echo ""; echo -e "  ${RED}✗ ไม่ถูกต้อง (20000-50000)${NC}"; fi
    sleep 2
}

speed_test() {
    clear; echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}🌐 Speed Test${NC}                            ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""; rgb_bar; echo ""
    echo -e "  ${YELLOW}⏳ ทดสอบ...${NC}"
    local R; R=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null)
    if [ -n "$R" ]; then echo ""; echo "$R" | while read -r line; do echo -e "  ${GREEN}⚡${NC} ${WHITE}$line${NC}"; done
    else echo ""; echo -e "  ${RED}✗ ไม่ได้${NC}"; fi
    echo ""; echo -ne "  ${BLUE}กด Enter${NC}"; read -r
}

# ════════════ Main Loop ════════════
while true; do
    show_header
    show_menu
    echo -ne "  ${YELLOW}👉${NC} ${BOLD}เลือก${NC} ${DIM}[00-11]${NC} : "
    read -r choice
    echo ""
    case $choice in
        01|1) show_connection_info ;;
        02|2) restart_service ;;
        03|3) stop_service ;;
        04|4) start_service ;;
        05|5) view_logs ;;
        06|6) system_info ;;
        07|7) edit_auth ;;
        08|8) edit_obfs ;;
        09|9) change_port ;;
        10) check_online_users ;;
        11) speed_test ;;
        00|0)
            echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
            echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}👋 ขอบคุณ — IDA UDPHysteria${NC}      ${GREEN}║${NC}"
            echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
            echo ""; exit 0 ;;
        *) echo -e "  ${RED}❌ เลือก 00-11${NC}"; sleep 1.5 ;;
    esac
done
