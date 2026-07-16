#!/bin/bash
# ═══════════════════════════════════════════════════════
# IDA UDPHysteria — All-in-One Installer + Menu v1.0
# ═══════════════════════════════════════════════════════
set -e

# ── Helper function ──
progress() { echo -e "\n\033[1;34m==>\033[0m \033[1;37m$1\033[0m"; }

progress "Installing packages..."
apt-get update -qq && apt-get install -y -qq wget curl openssl python3 2>/dev/null

progress "Downloading hysteria binary v1.3.5..."
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  BIN="hysteria-linux-amd64";;
  aarch64) BIN="hysteria-linux-arm64";;
  *)       BIN="hysteria-linux-amd64";;
esac
wget -q "https://github.com/apernet/hysteria/releases/download/app/v1.3.5/$BIN" -O /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria

progress "Creating directories..."
mkdir -p /opt/hysteria/certs /etc/hysteria/client

progress "Generating certificates..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/hysteria/certs/server.key \
  -out /opt/hysteria/certs/server.crt \
  -subj "/C=TH/ST=Bangkok/L=Bangkok/O=IDA VPN/CN=${SERVER_IP}" 2>/dev/null
chmod 600 /opt/hysteria/certs/server.key

progress "Configuration..."
read -p "  Port [25000]: " PORT
PORT=${PORT:-25000}
read -p "  Auth [ring]: " AUTH
AUTH=${AUTH:-ring}
read -p "  OBFS [adminadmin12]: " OBFS
OBFS=${OBFS:-adminadmin12}

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

progress "Creating start.sh..."
cat > /opt/hysteria/start.sh << 'EOS'
#!/bin/bash
exec /usr/local/bin/hysteria server -c /opt/hysteria/config-v1.json
EOS
chmod +x /opt/hysteria/start.sh

progress "Creating systemd service..."
cat > /etc/systemd/system/hysteria.service << 'EOSERV'
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
EOSERV

systemctl daemon-reload
systemctl enable hysteria.service
systemctl restart hysteria.service
sleep 2

progress "Verification..."
if ss -ulnp | grep -q ":$PORT "; then
  echo -e "\033[1;32m  ✅ Port $PORT listening\033[0m"
  echo -e "\033[1;32m  ✅ Service: $(systemctl is-active hysteria.service)\033[0m"
  python3 -c "import json; d=json.load(open('/opt/hysteria/config-v1.json')); print(f'  Auth: {d[\"auth_str\"]} | OBFS: {d[\"obfs\"]} | Port: {d[\"listen\"]}')"
else
  echo -e "\033[1;31m  ❌ Service failed. Check: journalctl -u hysteria.service -n 20\033[0m"
fi

echo ""
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo -e "\033[1;33m  🚀 Installation Complete!\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo ""

# ── Embedded menu.py ──
cat > /opt/hysteria/menu.py << 'EOMENU'
#!/usr/bin/env python3
"""IDA UDPHysteria Manager v3.5 — All-in-One"""
import os, subprocess, re, unicodedata, json, time

HYST_BIN = "/usr/local/bin/hysteria"
HYST_CONFIG = "/opt/hysteria/config-v1.json"
R = '\033[0;31m'; G = '\033[0;32m'; Y = '\033[1;33m'; B = '\033[0;34m'
C = '\033[0;36m'; M = '\033[0;35m'; W = '\033[1;37m'; D = '\033[2m'; NC = '\033[0m'

def vislen(s):
    s2 = re.sub(r'\033\[[0-9;]*m', '', s); w = 0
    for c in s2:
        cp = ord(c)
        if cp <= 0x00FF or (0x0E00 <= cp <= 0x0E7F): w += 1
        elif 0x4E00 <= cp <= 0x9FFF: w += 2
        else: w += 1
    return w

def pad(s, w): return s + ' ' * max(0, w - vislen(s))
def box(): print(f"  {B}\u2554" + "\u2550"*56 + f"\u2557{NC}")
def bot(): print(f"  {B}\u255a" + "\u2550"*56 + f"\u255d{NC}")
def bsep(): print(f"  {B}\u2560" + "\u2550"*56 + f"\u2563{NC}")
def bput(c): p = max(0, 60 - 6 - vislen(c)); print(f"  {B}\u2551{NC} {c}{' '*p} {B}\u2551{NC}")
def center(t):
    v = vislen(t); l = (60-4-v)//2; r = 60-4-v-l
    print(f"  {B}\u2551{NC}{' '*l}{t}{' '*r}{B}\u2551{NC}")

def read_config():
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        return d.get("listen",":25000").split(":")[-1], d.get("auth_str",""), d.get("obfs","")
    except: return "25000","",""

def get_ip():
    try: return subprocess.check_output("curl -s ifconfig.me", shell=True, timeout=3).decode().strip()
    except: return "N/A"
def get_status():
    try: return subprocess.run(["systemctl","is-active","hysteria"], capture_output=True,text=True,timeout=3).stdout.strip()
    except: return "inactive"
def get_uptime():
    try:
        up = subprocess.run("uptime -p", shell=True, capture_output=True,text=True,timeout=3).stdout.strip().replace("up ","")
        d = re.search(r"(\d+)\s*day", up); h = re.search(r"(\d+)\s*hour", up); m = re.search(r"(\d+)\s*minute", up)
        if d and h: return f"{d.group(1)}d{h.group(1)}h"
        if d: return f"{d.group(1)}d"
        if h: return f"{h.group(1)}h" + (f"{m.group(1)}m" if m else "")
        if m: return f"{m.group(1)}m"
    except: pass
    return ""

def run_menu():
    os.system("clear"); print()
    p, a, o = read_config(); ip = get_ip(); st = get_status(); u = get_uptime()
    stt = f"{G}ONLINE{NC}" if st == "active" else f"{R}OFFLINE{NC}"
    box()
    bar = f"  {R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}"
    center(f"{bar}  {W}IDA UDPHysteria{NC}  {bar}")
    center(f"{D}Hysteria v1 Server Manager{NC}")
    bsep()
    bput(f"{D}  Server IP{NC} : {W}{ip}{NC}")
    bput(f"{D}  Port{NC}      : {W}{p} (20000-50000){NC}")
    bput(f"{D}  Auth{NC}      : {W}{a if a else '-'}{NC}")
    bput(f"{D}  Obfs{NC}      : {W}{o if o else '-'}{NC}")
    bput(f"{D}  Status{NC}    : {stt}   {D}Up:{u}{NC}")
    bput(f"  {R}\u258c{NC}{O}\u258c{NC}{Y}\u258c{NC}{G}\u258c{NC}{C}\u258c{NC}{B}\u258c{NC}{M}\u258c{NC}")
    center(f"{D}========== SELECT OPTION =========={NC}")
    bput("")
    items = [
        ("01","\U0001f4ca","Connection Info"), ("07","\U0001f511","Edit AUTH"),
        ("02","\U0001f504","Restart"),           ("08","\U0001f50f","Edit OBFS"),
        ("03","\u26d4","Stop"),                  ("09","\U0001f527","Change Port"),
        ("04","\u25b6","Start"),                ("10","\U0001f465","Online Users"),
        ("05","\U0001f4dc","View Logs"),         ("11","\U0001f310","Speed Test"),
        ("06","\U0001f50d","System Info"),        ("00","\U0001f6aa","Exit"),
    ]
    for i in range(0, len(items), 2):
        n1,i1,l1 = items[i]; n2,i2,l2 = items[i+1]
        left = f"{G}[{n1}]{NC}  {i1}  {l1}"
        right = f"{G}[{n2}]{NC}  {i2}  {l2}"
        bput(f"  {pad(left,25)}  {pad(right,25)}")
    bput("")
    bsep(); bot(); print()
    return input(f"  {Y}>>{NC} Choose [00-11]: ").strip()

def show_info():
    p,a,o = read_config(); ip = get_ip()
    os.system("clear"); print(); box(); center(f"{G}\U0001f4ca{NC} Connection Info"); bsep()
    bput(f"Protocol : {W}UDP Hysteria v1{NC}")
    bput(f"Server   : {W}{ip}{NC}")
    bput(f"Port     : {W}{p}{NC}")
    bput(f"Auth     : {W}{a}{NC}")
    bput(f"Obfs     : {W}{o}{NC}")
    bput(f"Range    : {W}20000-50000{NC}")
    bsep(); bot(); print(); input("  Press Enter > ")

def do_restart():
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(2)
    if get_status()=="active": print(f"  {G}\u2705 Restarted{NC}")
    else: print(f"  {R}\u274c Failed{NC}")
    time.sleep(1.5)

def do_stop():
    subprocess.run(["systemctl","stop","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(1)
    print(f"  {G}\u2705 Stopped{NC}"); time.sleep(1.5)

def do_start():
    subprocess.run(["systemctl","start","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(2)
    if get_status()=="active": print(f"  {G}\u2705 Started{NC}")
    else: print(f"  {R}\u274c Failed{NC}")
    time.sleep(1.5)

def view_logs():
    os.system("clear"); print(); box(); center(f"{C}\U0001f4dc{NC} Logs"); bsep()
    r = subprocess.run(["journalctl","-u","hysteria","--no-pager","-n","20","--since","10 min ago"], capture_output=True,text=True,timeout=5)
    for line in r.stdout.strip().split("\n")[-15:]:
        bput(f"{D}{line[:55]}{NC}")
    bsep(); bot(); print(); input("  Press Enter > ")

def sys_info():
    os.system("clear"); print(); box(); center(f"{M}\U0001f50d{NC} System Info"); bsep()
    for cmd,lbl in [("hostname -f","Hostname"),("uname -r","Kernel"),("uptime -p","Uptime"),
                    ("free -h|awk '/Mem:/{print $3\"/\"$2}'","Memory"),
                    ("df -h /|awk 'NR==2{print $3\"/\"$2}'","Disk")]:
        r = subprocess.run(cmd, shell=True, capture_output=True,text=True,timeout=3)
        bput(f"{D}  {lbl}{NC} : {W}{r.stdout.strip()[:30]}{NC}")
    bsep(); bot(); print(); input("  Press Enter > ")

def edit_auth():
    _,old,_ = read_config()
    os.system("clear"); print(); box(); center(f"{M}\U0001f511{NC} Edit AUTH"); bsep()
    bput(f"Current : {W}{old}{NC}"); bput("")
    new = input(f"  >> New AUTH (empty=cancel): ").strip()
    if not new: print("Cancelled"); time.sleep(1); return
    with open(HYST_CONFIG) as f: d = json.load(f)
    d["auth_str"] = new
    with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(2)
    bput(f"{G}\u2705 AUTH updated{NC}"); bsep(); bot(); print(); time.sleep(2)

def edit_obfs():
    _,_,old = read_config()
    os.system("clear"); print(); box(); center(f"{M}\U0001f50f{NC} Edit OBFS"); bsep()
    bput(f"Current : {W}{old}{NC}"); bput("")
    new = input(f"  >> New OBFS (empty=cancel): ").strip()
    if not new: print("Cancelled"); time.sleep(1); return
    with open(HYST_CONFIG) as f: d = json.load(f)
    d["obfs"] = new
    with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(2)
    bput(f"{G}\u2705 OBFS updated{NC}"); bsep(); bot(); print(); time.sleep(2)

def change_port():
    p,_,_ = read_config()
    os.system("clear"); print(); box(); center(f"{M}\U0001f527{NC} Change Port"); bsep()
    bput(f"Current : {W}{p}{NC}"); bput("")
    new = input(f"  >> New Port (10000-65535): ").strip()
    if not new or not new.isdigit() or not (10000 <= int(new) <= 65535):
        print(f"{R}Invalid range{NC}"); time.sleep(1.5); return
    with open(HYST_CONFIG) as f: d = json.load(f)
    d["listen"] = f":{new}"
    with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10); time.sleep(2)
    bput(f"{G}\u2705 Port changed to {new}{NC}"); bsep(); bot(); print(); time.sleep(2)

def check_online():
    os.system("clear"); print(); box(); center(f"{M}\U0001f465{NC} Online Users"); bsep()
    bput(f"{D}  Scanning...{NC}")
    p,_,_ = read_config(); my = get_ip()
    r = subprocess.run(f"timeout 5 tcpdump -i any -c 20 -n udp port {p} 2>/dev/null", shell=True, capture_output=True,text=True,timeout=7)
    ips = set()
    for m in re.finditer(r'(\d+\.\d+\.\d+\.\d+)', r.stdout):
        ip = m.group(1)
        if ip != my and not ip.startswith("127."): ips.add(ip)
    bput(f"  {W}{len(ips)}{NC} user(s) online")
    bsep(); bot(); print(); input("  Press Enter > ")

def speed_test():
    os.system("clear"); print(); box(); center(f"{G}\U0001f310{NC} Speed Test"); bsep()
    bput(f"{D}  Testing...{NC}")
    r = subprocess.run("curl -s -o /dev/null -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=5000000", shell=True, capture_output=True,text=True,timeout=30)
    mbps = float(r.stdout.strip() or '0') * 8 / 1_000_000
    bput(f"  {W}{mbps:.1f} Mbps{NC} download")
    bsep(); bot(); print(); input("  Press Enter > ")

if __name__ == "__main__":
    while True:
        try:
            ch = run_menu()
            if ch == "01": show_info()
            elif ch == "02": do_restart()
            elif ch == "03": do_stop()
            elif ch == "04": do_start()
            elif ch == "05": view_logs()
            elif ch == "06": sys_info()
            elif ch == "07": edit_auth()
            elif ch == "08": edit_obfs()
            elif ch == "09": change_port()
            elif ch == "10": check_online()
            elif ch == "11": speed_test()
            elif ch == "00": os.system("clear"); print(f"  {G}Goodbye!{NC}"); break
        except KeyboardInterrupt: break
        except Exception as e: print(f"  {R}Error: {e}{NC}"); time.sleep(2)
EOMENU

chmod +x /opt/hysteria/menu.py
python3 /opt/hysteria/menu.py
