#!/usr/bin/env python3
#!/usr/bin/env python3
"""IDA UDPHysteria Manager v3.0 — Python Boxed Menu"""
import os, subprocess, re, unicodedata, json, socket, time

# ══ Config ══
HYST_CONFIG = "/opt/hysteria/config-v1.json"

# ══ Colors ══
R = '\033[0;31m'; G = '\033[0;32m'; O = '\033[0;33m'
Y = '\033[1;33m'; B = '\033[0;34m'; M = '\033[0;35m'
C = '\033[0;36m'; WHT = '\033[1;37m'; BD = '\033[1m'
D = '\033[2m'; NC = '\033[0m'

# ══ Box (W=58) ══
W = 58
H = '═'
def vislen(s):
    from wcwidth import wcswidth
    s2 = re.sub(r'\033\[[0-9;]*m', '', s)
    return sum(max(0, wcswidth(c)) for c in s2 if unicodedata.category(c) != 'Mn')
def pad(s, w):
    return s + ' ' * max(0, w - vislen(s))
def box():
    print(f"  {B}╔{H*(W-2)}╗{NC}")
def bsep():
    print(f"  {B}╠{H*(W-2)}╣{NC}")
def bput(c):
    p = max(0, W-4-vislen(c))
    print(f"  {B}║{NC} {c}{' '*p} {B}║{NC}")
def center(t):
    v = vislen(t); l = (W-4-v)//2; r = W-4-v-l
    print(f"  {B}║{NC}{' '*l}{t}{' '*r}{B}║{NC}")
def menu_row(n1, i1, l1, n2, i2, l2):
    left = f"{G}[{n1}]{NC}  {i1}  {l1}"
    right = f"{G}[{n2}]{NC}  {i2}  {l2}"
    bput(f"  {pad(left, 25)}  {pad(right, 21)}")

# ══ Data ══
def read_config():
    try:
        with open(HYST_CONFIG) as f:
            d = json.load(f)
        port = d.get("listen", ":25000").split(":")[-1]
        return port, d.get("auth_str", ""), d.get("obfs", "")
    except: return "25000", "", ""

def get_ip():
    try: return subprocess.check_output("curl -s ifconfig.me", shell=True, timeout=3).decode().strip()
    except: return "ไม่ทราบ"
def get_status():
    try: return subprocess.run(["systemctl","is-active","hysteria"], capture_output=True,text=True,timeout=3).stdout.strip()
    except: return "inactive"
def get_uptime():
    try:
        r = subprocess.run(["systemctl","status","hysteria","--no-pager"], capture_output=True,text=True,timeout=3)
        m = re.search(r"since (.*?);", r.stdout)
        return m.group(1).strip()[:35] if m else ""
    except: return ""
def count_online():
    try:
        p,_,_ = read_config(); my = get_ip()
        r = subprocess.run(f"timeout 1.5 tcpdump -i any -c 5 -n udp port {p} 2>/dev/null", shell=True, capture_output=True,text=True,timeout=3)
        ips = set()
        for ip in re.findall(r'(\d+\.\d+\.\d+\.\d+)', r.stdout):
            if ip not in (my,"0.0.0.0") and not ip.startswith("127."): ips.add(ip)
        return len(ips)
    except: return 0

# ══ Menu Screen ══
def show_menu():
    p, a, o = read_config(); ip = get_ip(); st = get_status(); up = get_uptime(); on = count_online()
    si = f"{G}✅{NC}" if st=="active" else f"{R}❌{NC}"; stt = f"{G}ONLINE{NC}" if st=="active" else f"{R}OFFLINE{NC}"
    os.system("clear")
    print()
    box()
    center(f"{R}████{O}████{Y}████{G}████{C}████{B}████{M}████{NC}{WHT} IDA UDPHysteria {R}████{O}████{Y}████{G}████{C}████{B}████{M}████{NC}")
    center(f"{D}🚀 ระบบจัดการ Hysteria v1{NC}")
    bsep()
    bput(f"  📡 IP : {WHT}{ip}{NC}  🔌 PORT : {WHT}{p}{NC}  {D}(20000-50000){NC}")
    bput(f"  🔑 AUTH : {WHT}{a}{NC}     🔏 OBFS : {WHT}{o}{NC}")
    bput(f"  📊 {si} {D}|{NC} {stt}     👥 {WHT}{on}{NC} คน     ⏱  {D}{up}{NC}")

    # ── Color bar ──
    bput(f"  {R}▌{NC}{O}▌{NC}{Y}▌{NC}{G}▌{NC}{C}▌{NC}{B}▌{NC}{M}▌{NC}")
    bput(f"  {D}━━━━━━━━━━━━━━  🎯  {NC}กรุณาเลือกเมนู{D}  ━━━━━━━━━━━━━━━{NC}")
    bput("")
    menu_row("01","📊","ข้อมูลเชื่อมต่อ","07","🔑","แก้ AUTH")
    menu_row("02","🔄","รีสตาร์ท","08","🔏","แก้ OBFS")
    menu_row("03","⛔","หยุด","09","🔧","เปลี่ยนพอร์ต")
    menu_row("04","▶ ","เริ่ม","10","👥","ผู้ใช้ออนไลน์")
    menu_row("05","📜","ดู Logs","11","🌐","Speed Test")
    menu_row("06","🔍","ข้อมูลระบบ","00","🚪","ออกจากโปรแกรม")
    bput("")
    bsep()
    box()
    print()
    return input(f"  {Y}👉{NC} {BD}เลือก{NC} {D}[00-11]{NC} : ").strip()

# ══ Screens ══
def show_info():
    p,a,o = read_config(); ip = get_ip()
    os.system("clear"); print(); box(); center(f"{G}📊{NC} {BD}ข้อมูลเชื่อมต่อ{NC}"); bsep()
    bput(f"📡 โปรโตคอล : {WHT}UDP Hysteria v1{NC}")
    bput(f"🌐 เซิร์ฟเวอร์ : {WHT}{ip}{NC}")
    bput(f"🔌 พอร์ต : {WHT}{p}{NC}  {D}(20000-50000){NC}")
    bput(f"🔑 AUTH : {WHT}{a}{NC}")
    bput(f"🔏 OBFS : {WHT}{o}{NC}")
    bput(f"⚠ Allow Insecure : {G}✅ YES{NC}")
    bsep(); bput(f"{D}💡 ใช้ตั้งค่าใน Creeb / v2 Box{NC}"); box(); print(); input(f"  {B}กด Enter{NC} ")
def restart():
    os.system("clear"); print(); box(); center(f"{Y}🔄{NC} {BD}รีสตาร์ท Hysteria{NC}"); bsep()
    bput(f"{Y}⏳{NC} กำลังรีสตาร์ท..."); subprocess.run(["systemctl","restart","hysteria"],timeout=10); time.sleep(2)
    st = subprocess.run(["systemctl","is-active","hysteria"],capture_output=True,text=True).stdout.strip()
    bput(f"{G}✅{NC} รีสตาร์ทสำเร็จ" if st=="active" else f"{R}❌{NC} ไม่สำเร็จ"); box(); print(); time.sleep(1.5)
def stop():
    os.system("clear"); print(); box(); center(f"{R}⛔{NC} {BD}หยุด Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","stop","hysteria"],timeout=10)
    bput(f"{G}✅{NC} หยุดแล้ว"); box(); print(); time.sleep(1.5)
def start():
    os.system("clear"); print(); box(); center(f"{G}▶{NC} {BD}เริ่ม Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","start","hysteria"],timeout=10); time.sleep(2)
    st = subprocess.run(["systemctl","is-active","hysteria"],capture_output=True,text=True).stdout.strip()
    bput(f"{G}✅{NC} เริ่มสำเร็จ" if st=="active" else f"{R}❌{NC} ไม่สำเร็จ"); box(); print(); time.sleep(1.5)
def view_logs():
    os.system("clear"); print(); box(); center(f"{C}📜{NC} {BD}บันทึก 10 นาทีล่าสุด{NC}"); bsep()
    r = subprocess.run(["journalctl","-u","hysteria","--since","10 min ago","--no-pager"],capture_output=True,text=True,timeout=10)
    logs = r.stdout.strip().split("\n")[-30:]
    if logs and logs[0]:
        for line in logs: bput(f"{D}{line[:80]}{NC}")
    else: bput(f"{Y}⚠ ไม่มี log{NC}")
    box(); print(); input(f"  {B}กด Enter{NC} ")
def system_info():
    os.system("clear"); print(); box(); center(f"{M}🔍{NC} {BD}ข้อมูลระบบ{NC}"); bsep()
    cpu = subprocess.run("grep -c processor /proc/cpuinfo",shell=True,capture_output=True,text=True).stdout.strip()
    ram = subprocess.run("free -h | awk '/^Mem:/{print \\$3\"/\"\\$2}'",shell=True,capture_output=True,text=True).stdout.strip()
    disk = subprocess.run("df -h / | awk 'NR==2{print \\$3\"/\"\\$2}'",shell=True,capture_output=True,text=True).stdout.strip()
    upt = subprocess.run("uptime -p | sed 's/up //'",shell=True,capture_output=True,text=True).stdout.strip()
    lo = open("/proc/loadavg").read().split()[:3]
    bput(f"💻 CPU : {WHT}{cpu}{NC} แกน  RAM : {WHT}{ram}{NC}  ดิสก์ : {WHT}{disk}{NC}")
    bput(f"⏱ อัปไทม์ : {WHT}{upt}{NC}  โหลด : {WHT}{', '.join(lo)}{NC}")
    bsep(); bput(f"{Y}⏳ Speed Test...{NC}")
    sp = subprocess.run("curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null",shell=True,capture_output=True,text=True,timeout=30)
    if sp.stdout.strip():
        for line in sp.stdout.strip().split("\n"): bput(f"{G}⚡{NC} {WHT}{line}{NC}")
    else: bput(f"{R}✗{NC} Speed test ล้มเหลว")
    box(); print(); input(f"  {B}กด Enter{NC} ")
def edit_auth():
    p,a,o = read_config()
    os.system("clear"); print(); box(); center(f"{M}🔑{NC} {BD}แก้ AUTH{NC}"); bsep()
    bput(f"🔑 ปัจจุบัน : {WHT}{BD}{a}{NC}"); bsep()
    new = input(f"  {G}▶{NC} AUTH ใหม่ : ").strip()
    if new:
        try:
            with open(HYST_CONFIG) as f: d = json.load(f)
            d["auth_str"] = new
            with open(HYST_CONFIG,"w") as f: json.dump(d,f,indent=2)
            bput(f"{G}✅{NC} เปลี่ยนเป็น {WHT}{BD}{new}{NC}")
            subprocess.run(["systemctl","restart","hysteria"],timeout=10); bput(f"{G}✅{NC} รีสตาร์ทแล้ว")
        except Exception as e: bput(f"{R}❌{NC} {e}")
    else: bput(f"{R}✗{NC} ยกเลิก")
    box(); print(); time.sleep(2)
def edit_obfs():
    p,a,o = read_config()
    os.system("clear"); print(); box(); center(f"{M}🔏{NC} {BD}แก้ OBFS{NC}"); bsep()
    bput(f"🔏 ปัจจุบัน : {WHT}{BD}{o}{NC}"); bput(f"{D}💡 เว้นว่าง = ปิด{NC}"); bsep()
    new = input(f"  {G}▶{NC} OBFS ใหม่ : ").strip()
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        d["obfs"] = new
        with open(HYST_CONFIG,"w") as f: json.dump(d,f,indent=2)
        bput(f"{G}✅{NC} {'ปิด' if not new else 'เปลี่ยนเป็น '+new}")
        subprocess.run(["systemctl","restart","hysteria"],timeout=10); bput(f"{G}✅{NC} รีสตาร์ทแล้ว")
    except Exception as e: bput(f"{R}❌{NC} {e}")
    box(); print(); time.sleep(2)
def change_port():
    p,a,o = read_config()
    os.system("clear"); print(); box(); center(f"{M}🔧{NC} {BD}เปลี่ยนพอร์ต{NC}"); bsep()
    bput(f"🔌 ปัจจุบัน : {WHT}{BD}{p}{NC}"); bput(f"{D}📌 พิมพ์เลข 20000-50000{NC}"); bsep()
    new = input(f"  {G}▶{NC} พอร์ตใหม่ : ").strip()
    if new and new.isdigit() and 20000 <= int(new) <= 50000:
        try:
            with open(HYST_CONFIG) as f: d = json.load(f)
            d["listen"] = f":{new}"
            with open(HYST_CONFIG,"w") as f: json.dump(d,f,indent=2)
            bput(f"{G}✅{NC} เปลี่ยนเป็น {WHT}{BD}{new}{NC}")
            subprocess.run(["systemctl","restart","hysteria"],timeout=10); bput(f"{G}✅{NC} รีสตาร์ทแล้ว")
        except Exception as e: bput(f"{R}❌{NC} {e}")
    else: bput(f"{R}✗{NC} ไม่ถูกต้อง (20000-50000)")
    box(); print(); time.sleep(2)
def check_online():
    os.system("clear"); print(); box(); center(f"{Y}👥{NC} {BD}ผู้ใช้ออนไลน์{NC}"); bsep()
    p,_,_ = read_config(); my = get_ip()
    bput(f"{Y}⏳{NC} กำลังสแกน (5 วิ)...")
    r = subprocess.run(f"timeout 5 tcpdump -i any -n udp port {p} 2>/dev/null",shell=True,capture_output=True,text=True,timeout=7)
    clients = set()
    for ip in re.findall(r'(\d+\.\d+\.\d+\.\d+)', r.stdout):
        if ip not in (my,"0.0.0.0") and not ip.startswith("127."): clients.add(ip)
    bsep()
    if clients:
        bput(f"👥 {G}{BD}ออนไลน์ {len(clients)} คน{NC}")
        for i,ip in enumerate(sorted(clients)[:20],1):
            try: h = socket.gethostbyaddr(ip)[0][:40]; bput(f"  {G}{i:>2}.{NC}  {Y}{ip:>15}{NC}  {D}({h}){NC}")
            except: bput(f"  {G}{i:>2}.{NC}  {WHT}{ip:>15}{NC}")
    else: bput(f"👥 {WHT}ไม่มีผู้ใช้ในขณะนี้{NC}")
    bsep()
    iface = subprocess.run("ip route get 1 | grep -o 'dev [^ ]*' | cut -d' ' -f2 | head -1",shell=True,capture_output=True,text=True).stdout.strip()
    rx=tx="0"
    if iface:
        for line in open("/proc/net/dev"):
            if iface in line:
                parts=line.split(); rx,tx=parts[1],parts[9]
    try:
        rx_b,tx_b=int(rx),int(tx)
        bput(f"⬇ ดาวน์โหลด : {WHT}{rx_b/1024/1024/1024:.2f} GB{NC}   ⬆ อัปโหลด : {WHT}{tx_b/1024/1024/1024:.2f} GB{NC}")
    except: pass
    hpid = subprocess.run("pgrep hysteria-v1",shell=True,capture_output=True,text=True).stdout.strip()
    if hpid: bput(f"📌 PID : {WHT}{hpid}{NC}")
    box(); print(); input(f"  {B}กด Enter{NC} ")
def speed_test():
    os.system("clear"); print(); box(); center(f"{G}🌐{NC} {BD}Speed Test{NC}"); bsep()
    bput(f"{Y}⏳{NC} กำลังทดสอบ...")
    r = subprocess.run("curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py 2>/dev/null | python3 - --simple 2>/dev/null",shell=True,capture_output=True,text=True,timeout=30)
    if r.stdout.strip():
        for line in r.stdout.strip().split("\n"): bput(f"{G}⚡{NC} {WHT}{line}{NC}")
    else: bput(f"{R}✗{NC} Speed test ล้มเหลว")
    box(); print(); input(f"  {B}กด Enter{NC} ")

# ══ Main Loop ══
ACTIONS = {
    "01":show_info,"1":show_info,"02":restart,"2":restart,"03":stop,"3":stop,
    "04":start,"4":start,"05":view_logs,"5":view_logs,"06":system_info,"6":system_info,
    "07":edit_auth,"7":edit_auth,"08":edit_obfs,"8":edit_obfs,"09":change_port,"9":change_port,
    "10":check_online,"11":speed_test,
}
while True:
    try:
        c = show_menu()
        if c in ("00","0","exit","quit","q"): break
        if c in ACTIONS: ACTIONS[c]()
    except KeyboardInterrupt: break
    except Exception as e:
        print(f"  {R}❌{NC} ผิดพลาด: {e}"); time.sleep(2)
os.system("clear"); print(); box(); center(f"{G}👋{NC} {BD}ขอบคุณ — IDA UDPHysteria{NC}"); box(); print()
