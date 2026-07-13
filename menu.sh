#!/bin/bash

# Hysteria Manager Menu
# =====================

HYST_CONFIG="/opt/hysteria/config-v1.json"
HYST_SERVICE="hysteria"
HYST_BIN="/opt/hysteria/hysteria-v1"
HYST_PORT_FILE="/opt/hysteria/current_port.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║       Hysteria Manager v1.0              ║"
    echo "╠══════════════════════════════════════════╣"
    echo -e "${NC}"
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    UPTIME=$(systemctl status $HYST_SERVICE --no-pager 2>/dev/null | grep "Active:" | sed 's/.*since //; s/;.*//')
    echo "   Server IP  : $IP"
    echo "   Port       : 25000 (Hopping: 20000-50000)"
    echo "   AUTH       : $(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)"
    echo "   OBFS       : $(grep -o '"obfs": "[^"]*"' $HYST_CONFIG 2>/dev/null | cut -d'"' -f4)"
    STATUS=$(systemctl is-active $HYST_SERVICE 2>/dev/null)
    if [ "$STATUS" = "active" ]; then
        echo -e "   Status     : ${GREEN}$STATUS${NC}"
    else
        echo -e "   Status     : ${RED}$STATUS${NC}"
    fi
    echo ""
}

show_menu() {
    echo -e "${YELLOW}═══════════════════ MENU ═══════════════════${NC}"
    echo ""
    echo "   [01] + Show Connection Info"
    echo "   [02] + Restart Hysteria Service"
    echo "   [03] + Stop Hysteria Service"
    echo "   [04] + Start Hysteria Service"
    echo "   [05] + View Hysteria Logs"
    echo "   [06] + System Info"
    echo "   [07] + Edit AUTH Password"
    echo "   [08] + Edit OBFS Password"
    echo "   [09] + Change Port"
    echo "   [10] + Speed Test"
    echo ""
    echo "   [00] + Exit"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    echo ""
}

show_connection_info() {
    echo -e "\n${GREEN}═════ Connection Info ═════${NC}"
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    AUTH=$(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)
    OBFS=$(grep -o '"obfs": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)
    echo ""
    echo "  Protocol      : UDP HYSTERIA (v1)"
    echo "  Server        : $IP"
    echo "  Port          : 25000 (or any 20000-50000)"
    echo "  AUTH          : $AUTH"
    echo "  OBFS          : $OBFS"
    echo "  Allow Insecure: YES"
    echo ""
    read -p "  Press Enter to continue..."
}

restart_service() {
    echo -e "\n${YELLOW}Restarting Hysteria...${NC}"
    systemctl restart $HYST_SERVICE
    sleep 2
    STATUS=$(systemctl is-active $HYST_SERVICE)
    if [ "$STATUS" = "active" ]; then
        echo -e "${GREEN}✓ Hysteria is running${NC}"
    else
        echo -e "${RED}✗ Hysteria failed to start${NC}"
    fi
    sleep 2
}

stop_service() {
    echo -e "\n${YELLOW}Stopping Hysteria...${NC}"
    systemctl stop $HYST_SERVICE
    echo -e "${GREEN}✓ Hysteria stopped${NC}"
    sleep 2
}

start_service() {
    echo -e "\n${YELLOW}Starting Hysteria...${NC}"
    systemctl start $HYST_SERVICE
    sleep 2
    STATUS=$(systemctl is-active $HYST_SERVICE)
    if [ "$STATUS" = "active" ]; then
        echo -e "${GREEN}✓ Hysteria is running${NC}"
    else
        echo -e "${RED}✗ Hysteria failed to start${NC}"
    fi
    sleep 2
}

view_logs() {
    echo -e "\n${CYAN}═════ Recent Logs ═════${NC}\n"
    journalctl -u $HYST_SERVICE --since "10 min ago" --no-pager 2>/dev/null | tail -30
    echo ""
    read -p "  Press Enter to continue..."
}

system_info() {
    echo -e "\n${GREEN}═════ System Info ═════${NC}"
    echo "  CPU: $(grep -c processor /proc/cpuinfo) cores"
    echo "  RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
    echo "  Uptime: $(uptime -p | sed 's/up //')"
    echo "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | head -1 | cut -d'"' -f2)"
    echo ""
    # Speed test
    echo -e "${YELLOW}Running speed test...${NC}"
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null || echo "Speed test unavailable"
    echo ""
    read -p "  Press Enter to continue..."
}

edit_auth() {
    echo -e "\n${YELLOW}Current AUTH: $(grep -o '"auth_str": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)${NC}"
    read -p "  New AUTH password: " NEW_AUTH
    if [ -n "$NEW_AUTH" ]; then
        sed -i "s/\"auth_str\": \"[^\"]*\"/\"auth_str\": \"$NEW_AUTH\"/" $HYST_CONFIG
        echo -e "${GREEN}✓ AUTH changed to: $NEW_AUTH${NC}"
        systemctl restart $HYST_SERVICE
        sleep 2
        echo -e "${GREEN}✓ Service restarted${NC}"
    fi
    sleep 2
}

edit_obfs() {
    echo -e "\n${YELLOW}Current OBFS: $(grep -o '"obfs": "[^"]*"' $HYST_CONFIG | cut -d'"' -f4)${NC}"
    read -p "  New OBFS password (leave empty to disable): " NEW_OBFS
    if [ -n "$NEW_OBFS" ]; then
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"$NEW_OBFS\"/" $HYST_CONFIG
        echo -e "${GREEN}✓ OBFS changed to: $NEW_OBFS${NC}"
    else
        sed -i "s/\"obfs\": \"[^\"]*\"/\"obfs\": \"\"/" $HYST_CONFIG
        echo -e "${GREEN}✓ OBFS disabled${NC}"
    fi
    systemctl restart $HYST_SERVICE
    sleep 2
    echo -e "${GREEN}✓ Service restarted${NC}"
    sleep 2
}

change_port() {
    echo -e "\n${YELLOW}Current main port: 25000${NC}"
    echo "  Port range available: 20000-50000"
    read -p "  New port: " NEW_PORT
    if [ -n "$NEW_PORT" ] && [ "$NEW_PORT" -ge 20000 ] && [ "$NEW_PORT" -le 50000 ] 2>/dev/null; then
        sed -i "s/\"listen\": \":[0-9]*\"/\"listen\": \":$NEW_PORT\"/" $HYST_CONFIG
        echo -e "${GREEN}✓ Port changed to: $NEW_PORT${NC}"
        systemctl restart $HYST_SERVICE
        sleep 2
        echo -e "${GREEN}✓ Service restarted${NC}"
    else
        echo -e "${RED}✗ Invalid port (must be 20000-50000)${NC}"
    fi
    sleep 2
}

speed_test() {
    echo -e "\n${YELLOW}Running speed test...${NC}"
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null || echo "Speed test unavailable"
    echo ""
    read -p "  Press Enter to continue..."
}

# Main loop
while true; do
    show_header
    show_menu
    read -p "  Select menu : " choice
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
        10) speed_test ;;
        00|0) 
            echo -e "\n${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *) 
            echo -e "\n${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
