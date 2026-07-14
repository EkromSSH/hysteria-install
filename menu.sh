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
#   พัฒนาโดย: Aku Cinta
# ═══════════════════════════════════════════════════════════

HYST_CONFIG="/opt/hysteria/config-v1.json"
HYST_SERVICE="hysteria"
HYST_BIN="/opt/hysteria/hysteria-v1"

# ════════════ จานสี (Color Palette) ════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ════════════ ฟังก์ชันตกแต่ง ════════════

rgb_bar() {
    # RGB Gradient Bar
    echo -e "  ${RED}▐${YELLOW}▐${GREEN}▐${CYAN}▐${BLUE}▐${MAGENTA}▐${NC}"
}

separator() {
    echo -e "  ${DIM}┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈${NC}"
}

thick_sep() {
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_brand() {
    echo ""
    echo -e "  ${RED}██${ORANGE}██${YELLOW}██${GREEN}██${CYAN}██${BLUE}██${MAGENTA}██${NC}  ${BOLD}${WHITE}IDA UDPHysteria${NC}  ${RED}██${ORANGE}██${YELLOW}██${GREEN}██${CYAN}██${BLUE}██${MAGENTA}██${NC}"
    echo -e "  ${DIM}       🚀 ระบบจัดการเซิร์ฟเวอร์ Hysteria v1${NC}"
    echo ""
}

print_footer() {
    echo ""
    echo -e "  ${DIM}┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈${NC}"
    echo -e "  ${DIM}⚡ IDA UDPHysteria | Hysteria v1 Manager${NC}"
    echo ""
}

# ════════════ หัวข้อ ════════════

show_header() {
    clear
    print_brand
    thick_sep
    echo ""

    IP=$(curl -s ifconfig.me 2>/dev/null || echo "ไม่ทราบ")
    STATUS=$(systemctl is-active $HYST_SERVICE 2>/dev/null)
    UPTIME_RAW=$(systemctl status $HYST_SERVICE --no-pager 2>/dev/null | grep "Active:" | sed 's/.*since //; s/;.*//' | head -c 40)
    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    ONLINE=$(count_online_users 2>/dev/null || echo "0")

    # ── สถานะเซิร์ฟเวอร์ ──
    echo -e "  ${BOLD}${WHITE}📋 ข้อมูลเซิร์ฟเวอร์${NC}"
    separator
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "IP เซิร์ฟเวอร์" "$IP"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "พอร์ตหลัก" "${HYST_PORT:-25000} (🏓 20000-50000)"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "AUTH" "$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "OBFS" "$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)"

    if [ "$STATUS" = "active" ]; then
        printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${GREEN}%-10s${NC} ${DIM}|${NC} ${YELLOW}👥 %s${NC}\n" "สถานะ" "✅ ONLINE" "ออนไลน์ $ONLINE คน"
        printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${DIM}${WHITE}%s${NC}\n" "เวลาทำงาน" "$UPTIME_RAW"
    else
        printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${RED}%-10s${NC}\n" "สถานะ" "❌ OFFLINE"
    fi
    echo ""
    thick_sep
    echo ""
}

# ════════════ เมนู ════════════

show_menu() {
    # ── ตกแต่งส่วนหัวเมนู ──
    echo -e "  ${BOLD}${WHITE}🎯 เลือกคำสั่งการทำงาน${NC}"
    separator
    echo ""

    # ── หมวด A: จัดการ ──
    echo -e "  ${YELLOW}▎${NC} ${BOLD}${DIM}หมวดจัดการระบบ${NC}"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "01" "📊 ข้อมูลการเชื่อมต่อ" "ดูรายละเอียดให้แอป Creeb"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "02" "🔄 รีสตาร์ท Hysteria" "รีบูตเซอร์วิส"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "03" "⛔ หยุด Hysteria" "หยุดเซอร์วิสทันที"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "04" "▶ เริ่ม Hysteria" "เริ่มเซอร์วิส"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "05" "📜 บันทึกการทำงาน" "ดู Log 10 นาทีล่าสุด"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "06" "🔍 ข้อมูลระบบ" "CPU, RAM, ดิสก์, สปีดเทส"
    echo ""

    # ── หมวด B: ตั้งค่า ──
    echo -e "  ${MAGENTA}▎${NC} ${BOLD}${DIM}หมวดตั้งค่า${NC}"
    printf "  ${MAGENTA}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "07" "🔑 แก้ไข AUTH" "เปลี่ยนรหัสผู้ใช้"
    printf "  ${MAGENTA}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "08" "🔏 แก้ไข OBFS" "เปลี่ยนรหัสพรางตัว"
    printf "  ${MAGENTA}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "09" "🔧 เปลี่ยนพอร์ต" "เปลี่ยนเลขพอร์ต"
    echo ""

    # ── หมวด C: พิเศษ ──
    echo -e "  ${CYAN}▎${NC} ${BOLD}${DIM}หมวดพิเศษ${NC}"
    printf "  ${YELLOW}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "10" "👥 ผู้ใช้ออนไลน์" "สแกนหาผู้ใช้ที่เชื่อมต่อ"
    printf "  ${GREEN}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "11" "🌐 ทดสอบความเร็ว" "วัดสปีดอินเทอร์เน็ต"
    echo ""

    # ── หมวด D: ออกจากโปรแกรม ──
    echo -e "  ${RED}▎${NC} ${BOLD}${DIM}ระบบ${NC}"
    printf "  ${RED}%2s${NC} │ ${WHITE}%-28s${NC} │ ${DIM}%s${NC}\n" "00" "🚪 ออกจากโปรแกรม" "กลับไปยัง Terminal"
    echo ""
    separator
    echo ""
}

# ════════════ ฟังก์ชันเช็คผู้ใช้ออนไลน์ ════════════

count_online_users() {
    local HYST_PORT
    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    [ -z "$HYST_PORT" ] && HYST_PORT=25000
    local MY_IP
    MY_IP=$(curl -s ifconfig.me 2>/dev/null)

    local COUNT
    COUNT=$(timeout 1.5 tcpdump -i any -c 5 -n udp port "$HYST_PORT" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | grep -v "$MY_IP" | grep -v "^0\.0\.0\.0$" | grep -v "^127\." | wc -l 2>/dev/null)
    
    if [ "$COUNT" -gt 0 ]; then
        echo "$COUNT"
        return
    fi

    echo "0"
}

check_online_users() {
    clear
    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}${WHITE}👥 ผู้ใช้ออนไลน์ 🔍${NC}                  ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo ""

    HYST_PORT=$(grep -o '":[0-9]*"' $HYST_CONFIG 2>/dev/null | head -1 | tr -d ':"')
    [ -z "$HYST_PORT" ] && HYST_PORT=25000
    MY_IP=$(curl -s ifconfig.me 2>/dev/null)
    rgb_bar
    echo -e "  ${YELLOW}⏳ กำลังสแกนหาผู้ใช้ (5 วินาที)...${NC}"
    echo ""

    CLIENTS=$(timeout 5 tcpdump -i any -n udp port "$HYST_PORT" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | grep -v "$MY_IP" | grep -v "^0\.0\.0\.0$" | grep -v "^127\." | head -50)
    
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -z "$CLIENTS" ]; then
        echo -e "  👥 ${WHITE}ไม่มีผู้ใช้งานในขณะนี้${NC}"
        echo -e "  ${DIM}  💡 รอสักครู่เมื่อมีคนเชื่อมต่อจะแสดงผล${NC}"
    else
        NUM=$(echo "$CLIENTS" | wc -l)
        echo -e "  👥 ${BOLD}${GREEN}พบ $NUM คน กำลังใช้งาน${NC}"
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
    
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # สถิติ
    echo ""
    echo -e "  ${BOLD}${WHITE}📊 สถิติ${NC}"
    separator
    local IFACE
    IFACE=$(ip route get 1 2>/dev/null | grep -o 'dev [^ ]*' | cut -d' ' -f2 | head -1)
    RX_BYTES=$(cat /proc/net/dev 2>/dev/null | grep "$IFACE" | awk '{print $2}')
    TX_BYTES=$(cat /proc/net/dev 2>/dev/null | grep "$IFACE" | awk '{print $10}')
    
    [ -n "$RX_BYTES" ] && [ "$RX_BYTES" -gt 0 ] && printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "⬇ ดาวน์โหลด" "$(numfmt --to=iec $RX_BYTES 2>/dev/null || echo "$RX_BYTES B")"
    [ -n "$TX_BYTES" ] && [ "$TX_BYTES" -gt 0 ] && printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "⬆ อัปโหลด" "$(numfmt --to=iec $TX_BYTES 2>/dev/null || echo "$TX_BYTES B")"
    
    HPID=$(pgrep hysteria-v1 2>/dev/null)
    [ -n "$HPID" ] && printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "PID" "$HPID"
    
    echo ""
    rgb_bar
    echo ""
    echo -ne "  ${BLUE}กด Enter เพื่อกลับ${NC}"
    read -r
}

# ════════════ ฟังก์ชันอื่นๆ ════════════

show_connection_info() {
    clear
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}📊 ข้อมูลการเชื่อมต่อ${NC}                   ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""

    IP=$(curl -s ifconfig.me 2>/dev/null || echo "ไม่ทราบ")
    AUTH=$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)
    OBFS=$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)

    thick_sep
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "โปรโตคอล" "UDP Hysteria v1"
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "เซิร์ฟเวอร์" "$IP"
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "พอร์ต" "25000 (🏓 20000-50000)"
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "AUTH" "$AUTH"
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "OBFS" "$OBFS"
    printf "  ${YELLOW}%-16s${NC} ${DIM}:${NC} ${GREEN}%s${NC}\n" "Allow Insecure" "✅ YES (จำเป็น)"
    thick_sep
    echo ""
    echo -e "  ${DIM}💡 ใช้ข้อมูลนี้ตั้งค่าใน Creeb Injector / v2 Box${NC}"
    echo ""
    echo -ne "  ${BLUE}กด Enter เพื่อกลับ${NC}"
    read -r
}

restart_service() {
    clear
    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}${WHITE}🔄 รีสตาร์ท Hysteria${NC}                       ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo -ne "  ${YELLOW}⏳ กำลังรีสตาร์ท...${NC}"
    systemctl restart $HYST_SERVICE 2>/dev/null
    sleep 2
    STATUS=$(systemctl is-active $HYST_SERVICE)
    if [ "$STATUS" = "active" ]; then
        echo -e "\r  ${GREEN}✅${NC} ${BOLD}รีสตาร์ทสำเร็จ!${NC} เซิร์ฟเวอร์กลับมาทำงานแล้ว ✓  "
    else
        echo -e "\r  ${RED}❌${NC} ${BOLD}รีสตาร์ทไม่สำเร็จ${NC} กรุณาตรวจสอบ systemctl ✗  "
    fi
    sleep 2
}

stop_service() {
    clear
    echo ""
    echo -e "  ${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${RED}║${NC}  ${BOLD}${WHITE}⛔ หยุด Hysteria${NC}                            ${RED}║${NC}"
    echo -e "  ${RED}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo -ne "  ${YELLOW}⏳ กำลังหยุด...${NC}"
    systemctl stop $HYST_SERVICE 2>/dev/null
    sleep 1
    echo -e "\r  ${GREEN}✅${NC} ${BOLD}หยุดเซอร์วิสเรียบร้อย${NC}  "
    sleep 2
}

start_service() {
    clear
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}▶ เริ่ม Hysteria${NC}                              ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo -ne "  ${YELLOW}⏳ กำลังเริ่ม...${NC}"
    systemctl start $HYST_SERVICE 2>/dev/null
    sleep 2
    STATUS=$(systemctl is-active $HYST_SERVICE)
    if [ "$STATUS" = "active" ]; then
        echo -e "\r  ${GREEN}✅${NC} ${BOLD}เริ่มสำเร็จ!${NC} Hysteria กำลังทำงาน ✓  "
    else
        echo -e "\r  ${RED}❌${NC} ${BOLD}เริ่มไม่สำเร็จ${NC} ตรวจสอบ logs ✗  "
    fi
    sleep 2
}

view_logs() {
    clear
    echo ""
    echo -e "  ${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC}  ${BOLD}${WHITE}📜 บันทึกการทำงาน${NC}                         ${CYAN}║${NC}"
    echo -e "  ${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""
    echo -e "  ${DIM}📄 แสดง 30 บรรทัดล่าสุด${NC}"
    separator

    LOGS=$(journalctl -u $HYST_SERVICE --since "10 min ago" --no-pager 2>/dev/null | tail -30)
    if [ -n "$LOGS" ]; then
        echo "$LOGS" | while read -r line; do
            echo -e "  ${DIM}$line${NC}"
        done
    else
        echo -e "  ${YELLOW}⚠ ไม่มีบันทึกในช่วง 10 นาทีที่ผ่านมา${NC}"
    fi
    echo ""
    echo -ne "  ${BLUE}กด Enter เพื่อกลับ${NC}"
    read -r
}

system_info() {
    clear
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔍 ข้อมูลระบบ${NC}                              ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""

    echo -e "  ${BOLD}${WHITE}💻 ฮาร์ดแวร์${NC}"
    separator
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "CPU" "$(grep -c processor /proc/cpuinfo) แกน"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "RAM" "$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "ดิสก์" "$(df -h / | awk 'NR==2 {print $3 "/" $2}')"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "อัปไทม์" "$(uptime -p | sed 's/up //')"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "OS" "$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | head -1 | cut -d'"' -f2)"
    printf "  ${CYAN}%-16s${NC} ${DIM}:${NC} ${WHITE}%s${NC}\n" "โหลดเฉลี่ย" "$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')"
    echo ""

    echo -e "  ${BOLD}${WHITE}🌐 ทดสอบความเร็ว${NC}"
    separator
    echo -e "  ${DIM}⏳ กำลังทดสอบ...${NC}"
    speedtest_result=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null)
    if [ -n "$speedtest_result" ]; then
        echo ""
        echo "$speedtest_result" | while read -r line; do
            echo -e "  ${GREEN}⚡${NC} ${WHITE}$line${NC}"
        done
    else
        echo ""
        echo -e "  ${RED}✗ ไม่สามารถทดสอบได้${NC}"
    fi
    echo ""
    echo -ne "  ${BLUE}กด Enter เพื่อกลับ${NC}"
    read -r
}

edit_auth() {
    clear
    CURRENT_AUTH=$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔑 แก้ไข AUTH${NC}                              ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""
    echo -e "  ${YELLOW}รหัสปัจจุบัน${NC} ${DIM}:${NC} ${WHITE}${BOLD}$CURRENT_AUTH${NC}"
    separator
    echo -ne "  ${GREEN}▶${NC} ${BOLD}ป้อน AUTH ใหม่${NC} : "
    read -r NEW_AUTH
    if [ -n "$NEW_AUTH" ]; then
        sed -i "s/\"auth_str\": \"[^\"]*\"/\"auth_str\": \"$NEW_AUTH\"/" $HYST_CONFIG
        echo ""
        echo -e "  ${GREEN}✅${NC} เปลี่ยนรหัส AUTH สำเร็จ!"
        echo -e "  ${WHITE}   รหัสใหม่: ${BOLD}$NEW_AUTH${NC}"
        echo ""
        echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"
        systemctl restart $HYST_SERVICE 2>/dev/null
        sleep 2
        echo -e "\r  ${GREEN}✅${NC} รีสตาร์ทเรียบร้อย  "
    else
        echo -e "  ${RED}✗ ยกเลิก (ไม่ได้ป้อนรหัส)${NC}"
    fi
    sleep 2
}

edit_obfs() {
    clear
    CURRENT_OBFS=$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔏 แก้ไข OBFS${NC}                              ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""
    echo -e "  ${YELLOW}รหัสปัจจุบัน${NC} ${DIM}:${NC} ${WHITE}${BOLD}$CURRENT_OBFS${NC}"
    echo -e "  ${DIM}💡 เว้นว่าง = ปิด OBFS${NC}"
    separator
    echo -ne "  ${GREEN}▶${NC} ${BOLD}ป้อน OBFS ใหม่${NC} : "
    read -r NEW_OBFS
    if [ -n "$NEW_OBFS" ]; then
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"$NEW_OBFS\"/" $HYST_CONFIG
        echo ""
        echo -e "  ${GREEN}✅${NC} เปลี่ยน OBFS สำเร็จ!"
        echo -e "  ${WHITE}   OBFS ใหม่: ${BOLD}$NEW_OBFS${NC}"
    else
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"\"/" $HYST_CONFIG
        echo ""
        echo -e "  ${YELLOW}⚠ ปิด OBFS แล้ว${NC}"
    fi
    echo ""
    echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"
    systemctl restart $HYST_SERVICE 2>/dev/null
    sleep 2
    echo -e "\r  ${GREEN}✅${NC} รีสตาร์ทเรียบร้อย  "
    sleep 2
}

change_port() {
    clear
    CURRENT_PORT=$(grep -o '":\([0-9]*\)"' $HYST_CONFIG | head -1 | tr -d ':"')
    echo ""
    echo -e "  ${MAGENTA}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${MAGENTA}║${NC}  ${BOLD}${WHITE}🔧 เปลี่ยนพอร์ต${NC}                            ${MAGENTA}║${NC}"
    echo -e "  ${MAGENTA}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""
    echo -e "  ${YELLOW}พอร์ตปัจจุบัน${NC} ${DIM}:${NC} ${WHITE}${BOLD}$CURRENT_PORT${NC}"
    echo -e "  ${DIM}📌 ช่วง: 20000-50000${NC}"
    separator
    echo -ne "  ${GREEN}▶${NC} ${BOLD}ป้อนพอร์ตใหม่${NC} : "
    read -r NEW_PORT
    if [ -n "$NEW_PORT" ] && [ "$NEW_PORT" -ge 20000 ] && [ "$NEW_PORT" -le 50000 ] 2>/dev/null; then
        sed -i "s/\"listen\": \":[0-9]*\"/\"listen\": \":$NEW_PORT\"/" $HYST_CONFIG
        echo ""
        echo -e "  ${GREEN}✅${NC} เปลี่ยนพอร์ตสำเร็จ!"
        echo -e "  ${WHITE}   พอร์ตใหม่: ${BOLD}$NEW_PORT${NC}"
        echo -e "  ${YELLOW}   🏓 20000-50000${NC}"
        echo ""
        echo -ne "  ${YELLOW}⏳ รีสตาร์ท...${NC}"
        systemctl restart $HYST_SERVICE 2>/dev/null
        sleep 2
        echo -e "\r  ${GREEN}✅${NC} รีสตาร์ทเรียบร้อย  "
    else
        echo ""
        echo -e "  ${RED}✗ พอร์ตไม่ถูกต้อง! (20000-50000)${NC}"
    fi
    sleep 2
}

speed_test() {
    clear
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}🌐 ทดสอบความเร็ว${NC}                            ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    rgb_bar
    echo ""
    echo -e "  ${YELLOW}⏳ กำลังทดสอบ... กรุณารอสักครู่${NC}"
    result=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null)
    if [ -n "$result" ]; then
        echo ""
        echo "$result" | while read -r line; do
            echo -e "  ${GREEN}⚡${NC} ${WHITE}$line${NC}"
        done
    else
        echo ""
        echo -e "  ${RED}✗ ไม่สามารถทดสอบความเร็วได้${NC}"
        echo -e "  ${DIM}   สาเหตุ: ไม่สามารถดาวน์โหลดสคริปต์ทดสอบ${NC}"
    fi
    echo ""
    echo -ne "  ${BLUE}กด Enter เพื่อกลับ${NC}"
    read -r
}

# ════════════ Main Loop ════════════

while true; do
    show_header
    show_menu
    echo -ne "  ${YELLOW}👉${NC} ${BOLD}เลือกเมนู${NC} ${DIM}[00-11]${NC} : "
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
            echo -e "  ${GREEN}║${NC}  ${BOLD}${WHITE}👋 ขอบคุณที่ใช้ IDA UDPHysteria${NC}  ${GREEN}║${NC}"
            echo -e "  ${GREEN}╚══════════════════════════════════════╝${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "  ${RED}╔══════════════════════════════════════╗${NC}"
            echo -e "  ${RED}║${NC}  ${BOLD}❌ กรุณาเลือก 00-11${NC}                    ${RED}║${NC}"
            echo -e "  ${RED}╚══════════════════════════════════════╝${NC}"
            sleep 1.5
            ;;
    esac
done
