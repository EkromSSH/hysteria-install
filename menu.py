#!/usr/bin/env python3
"""IDA UDPHysteria Manager — voltx-style Menu"""
import os, subprocess, re, unicodedata, json, socket, time

# ══ Config ══
HYST_CONFIG = "/opt/hysteria/config-v1.json"

# ══ Colors ══
R = '\033[0;31m'; G = '\033[0;32m'; O = '\033[0;33m'
Y = '\033[1;33m'; B = '\033[0;34m'; M = '\033[0;35m'
C = '\033[0;36m'; WHT = '\033[1;37m'; BD = '\033[1m'
D = '\033[2m'; NC = '\033[0m'
LG = '\033[0;92m'; LY = '\033[0;93m'; LC = '\033[0;96m'
LM = '\033[0;95m'; LR = '\033[0;91m'; LB = '\033[0;94m'

# ══ Helpers ══
def vislen(s):
    s2 = re.sub(r'\033\[[0-9;]*m', '', s)
    try:
        from wcwidth import wcswidth
        return sum(max(0, wcswidth(c)) for c in s2 if unicodedata.category(c) != 'Mn')
    except ImportError:
        w = 0
        for c in s2:
            if unicodedata.category(c) == 'Mn': continue
            cp = ord(c)
            if (0x0E00 <= cp <= 0x0E7F or cp <= 0x00FF): w += 1
            elif (0x1100 <= cp <= 0x11FF or 0x2E80 <= cp <= 0x2FFF or
                  0x3000 <= cp <= 0x33FF or 0x3400 <= cp <= 0x4DBF or
                  0x4E00 <= cp <= 0x9FFF or 0xAC00 <= cp <= 0xD7AF or
                  0xF900 <= cp <= 0xFAFF or 0xFE10 <= cp <= 0xFE19 or
                  0xFE30 <= cp <= 0xFE6F or 0xFF01 <= cp <= 0xFF60 or
                  0xFFE0 <= cp <= 0xFFE6 or 0x1F000 <= cp <= 0x1FFFF or
                  0x20000 <= cp <= 0x2FFFF or 0x30000 <= cp <= 0x3FFFF):
                w += 2
            else: w += 1
        return w

def pad(s, w):
    return s + ' ' * max(0, w - vislen(s))

# Rainbow decorations
def rb_top():
    print(f"  {R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}"
          f"{B}\u2554{'═'*56}\u2557{NC}"
          f"{R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}")

def rb_bot():
    print(f"  {R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}"
          f"{B}\u255a{'═'*56}\u255d{NC}"
          f"{R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}")

def rb_sep():
    print(f"  {B}\u2560{'═'*56}\u2563{NC}")

def bx(text):
    """Print box line with proper padding"""
    p = max(0, 56 - vislen(text))
    print(f"  {B}\u2551{NC}{text}{' '*p}{B}\u2551{NC}")

# ══ Data ══
def read_config():
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        port = d.get("listen", ":25000").split(":")[-1]
        return port, d.get("auth_str", ""), d.get("obfs", "")
    except: return "25000", "", ""

def get_ip():
    try: return subprocess.check_output("curl -s --connect-timeout 3 ifconfig.me", shell=True, timeout=5).decode().strip()
    except: return "N/A"

def get_status():
    try: return subprocess.run(["systemctl","is-active","hysteria"], capture_output=True,text=True,timeout=3).stdout.strip()
    except: return "inactive"

def get_uptime():
    try:
        r = subprocess.run(["systemctl","show","hysteria","-p","ActiveEnterTimestamp","--value"],
                          capture_output=True,text=True,timeout=3)
        t = r.stdout.strip()
        if t:
            from datetime import datetime
            dt = datetime.strptime(t.replace(" UTC",""), "%a %Y-%m-%d %H:%M:%S")
            delta = datetime.now() - dt
            days = delta.days
            hours, rem = divmod(delta.seconds, 3600)
            mins, _ = divmod(rem, 60)
            parts = []
            if days: parts.append(f"{days} day{'s' if days>1 else ''}")
            if hours: parts.append(f"{hours} hour{'s' if hours>1 else ''}")
            if mins and not days: parts.append(f"{mins} min")
            return ", ".join(parts) if parts else "just started"
    except: pass
    return ""

def count_online():
    ips = set()
    try:
        r = subprocess.run(["journalctl","-u","hysteria","--no-pager","--since","5 min ago"],
                          capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'\[src:(\d+\.\d+\.\d+\.\d+):\d+\]', r.stdout):
            ips.add(m.group(1))
    except: pass
    return len(ips)

# ══ Menu ══
def show_menu():
    p, a, o = read_config()
    ip = get_ip()
    st = get_status()
    on = count_online()
    up = get_uptime()
    sc = G if st=="active" else R
    stx = "ON" if st=="active" else "OFF"

    os.system("clear")
    print()
    rb_top()
    bx(f"{'':>18}{WHT}IDA UDPHysteria{NC}")
    bx(f"  {LC}Version:{NC} {WHT}v3.3{NC}  {LC}Protocol:{NC} {WHT}[udp]{NC}")
    rb_sep()
    bx(f"  {LC}IPinfo:{NC} {WHT}{ip}{NC}")
    bx(f"  {LC}Port:{NC} {WHT}{p}{NC}")
    bx(f"  {LC}Auth:{NC} {WHT}{a if a else '-'}{NC}  {LC}Obfs:{NC} {WHT}{o if o else '-'}{NC}")
    bx(f"  {LC}Status:{NC} {sc}[{stx}]{NC}  {LC}Users:{NC} {WHT}{on}{NC}")
    if up:
        bx(f"  {LC}Uptime:{NC} {WHT}{up}{NC}")
    rb_sep()
    bx(f"  {G}[01]{NC} Create AUTH Passwords  {G}[02]{NC} List Auth Passwords")
    bx(f"  {G}[03]{NC} Restart Hysteria       {G}[04]{NC} System Info")
    bx(f"  {G}[05]{NC} View Logs             {G}[06]{NC} Speed Test")
    bx(f"  {G}[07]{NC} Online Users          {G}[08]{NC} Edit Config")
    bx(f"  {G}[00]{NC} Exit")
    rb_bot()
    print()
    return input(f"  {Y}>>{NC} Select menu : ").strip()

# ══ Actions ══
def show_info():
    p,a,o = read_config(); ip = get_ip()
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}Connection Info{NC}"); rb_sep()
    bx(f"  {LC}Server:{NC} {WHT}{ip}{NC}")
    bx(f"  {LC}Port:{NC} {WHT}{p} (20000-50000){NC}")
    bx(f"  {LC}Auth:{NC} {WHT}{a}{NC}")
    bx(f"  {LC}Obfs:{NC} {WHT}{o}{NC}")
    rb_sep(); bx(f"  {D}Use in Creeb / v2 Box{NC}")
    rb_bot(); print(); input(f"  {B}Press Enter{NC} ")

def do_restart():
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}Restarting Hysteria...{NC}"); rb_bot(); print()
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(2)
    if get_status()=="active": print(f"  {G}\u2705 Restarted!{NC}")
    else: print(f"  {R}\u274c Failed{NC}")
    time.sleep(1.5)

def do_stop():
    os.system("clear"); print()
    subprocess.run(["systemctl","stop","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(1); print(f"  {G}\u2705 Stopped{NC}"); time.sleep(1.5)

def do_start():
    os.system("clear"); print()
    subprocess.run(["systemctl","start","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(2)
    if get_status()=="active": print(f"  {G}\u2705 Started!{NC}")
    else: print(f"  {R}\u274c Failed{NC}")
    time.sleep(1.5)

def view_logs():
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}Logs (Last 10 min){NC}"); rb_sep()
    r = subprocess.run(["journalctl","-u","hysteria","--no-pager","-n","30","--since","10 min ago"],
                       capture_output=True,text=True,timeout=5)
    for line in r.stdout.strip().split("\n")[-20:]:
        bx(f"  {D}{line[:52]}{NC}")
    if not r.stdout.strip(): bx(f"  {D}No recent logs{NC}")
    rb_bot(); print(); input(f"  {B}Press Enter{NC} ")

def sys_info():
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}System Information{NC}"); rb_sep()
    for cmd, lbl in [("hostname -f","Hostname"),("uname -r","Kernel"),("uptime -p","Uptime"),
                     ("free -h | awk '/Mem:/{print $3\"/\"$2}'","Memory"),("df -h / | awk 'NR==2{print $3\"/\"$2}'","Disk")]:
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True,text=True,timeout=3)
            bx(f"  {LC}{pad(lbl,12)}{NC}: {WHT}{r.stdout.strip()[:30]}{NC}")
        except: pass
    rb_bot(); print(); input(f"  {B}Press Enter{NC} ")

def edit_config():
    os.system("clear"); print()
    p,a,o = read_config()
    rb_top(); bx(f"  {WHT}Edit Configuration{NC}"); rb_sep()
    bx(f"  {LC}Auth:{NC} {WHT}{a}{NC}")
    bx(f"  {LC}Obfs:{NC} {WHT}{o}{NC}")
    bx(f"  {LC}Port:{NC} {WHT}{p}{NC}")
    rb_sep()
    print(f"\n  {Y}[1]{NC} Auth  {Y}[2]{NC} Obfs  {Y}[3]{NC} Port  {Y}[0]{NC} Cancel")
    ch = input(f"  {Y}>>{NC} Choose: ").strip()
    if ch=="1":
        n = input(f"  {Y}>>{NC} New Auth: ").strip()
        if n:
            with open(HYST_CONFIG) as f: d=json.load(f)
            d["auth_str"]=n
            with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
            subprocess.run(["systemctl","restart","hysteria"],capture_output=True,text=True,timeout=10)
            print(f"  {G}\u2705 Done!{NC}"); time.sleep(2)
    elif ch=="2":
        n = input(f"  {Y}>>{NC} New Obfs: ").strip()
        if n:
            with open(HYST_CONFIG) as f: d=json.load(f)
            d["obfs"]=n
            with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
            subprocess.run(["systemctl","restart","hysteria"],capture_output=True,text=True,timeout=10)
            print(f"  {G}\u2705 Done!{NC}"); time.sleep(2)
    elif ch=="3":
        n = input(f"  {Y}>>{NC} New Port: ").strip()
        if n and n.isdigit():
            with open(HYST_CONFIG) as f: d=json.load(f)
            old=d.get("listen",":25000")
            d["listen"]=f"{old.rsplit(':',1)[0]}:{n}"
            with open(HYST_CONFIG,'w') as f: json.dump(d,f,indent=2)
            subprocess.run(["systemctl","restart","hysteria"],capture_output=True,text=True,timeout=10)
            print(f"  {G}\u2705 Done!{NC}"); time.sleep(2)

def speed_test():
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}Speed Test{NC}"); rb_sep()
    bx(f"  {D}Testing...{NC}")
    try:
        r = subprocess.run("curl -s -o /dev/null -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=10000000",
                           shell=True, capture_output=True,text=True,timeout=30)
        mbps = float(r.stdout.strip().replace("'",""))*8/1_000_000
        bx(f"  {WHT}{mbps:.1f} Mbps{NC} download")
    except: bx(f"  {R}Failed{NC}")
    rb_bot(); print(); input(f"  {B}Press Enter{NC} ")

def check_online():
    os.system("clear"); print()
    rb_top(); bx(f"  {WHT}Online Users{NC}"); rb_sep()
    p,_,_ = read_config()
    log_ips = set()
    try:
        r = subprocess.run(["journalctl","-u","hysteria","--no-pager","--since","5 min ago"],
                          capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'\[src:(\d+\.\d+\.\d+\.\d+):\d+\]', r.stdout):
            log_ips.add(m.group(1))
    except: pass
    traffic_ips = {}
    try:
        r = subprocess.run(f"timeout 8 tcpdump -i any -c 50 -n udp port {p} 2>/dev/null",
                          shell=True, capture_output=True,text=True,timeout=12)
        my = get_ip()
        for m in re.finditer(r'(\d+\.\d+\.\d+\.\d+)', r.stdout):
            ip=m.group(1)
            if ip!=my and not ip.startswith("127.") and ip!="0.0.0.0":
                traffic_ips[ip]=traffic_ips.get(ip,0)+1
    except: pass
    all_ips = log_ips.union(set(traffic_ips.keys()))
    bx(f"  {LC}Logs:{NC} {WHT}{len(log_ips)}{NC}  {LC}Live:{NC} {WHT}{len(traffic_ips)}{NC}  {LC}Total:{NC} {WHT}{len(all_ips)}{NC}")
    rb_sep()
    if all_ips:
        for i,ip in enumerate(sorted(all_ips)[:10],1):
            try: h=socket.gethostbyaddr(ip)[0][:25]
            except: h="unknown"
            s=[]
            if ip in log_ips: s.append("LOG")
            if ip in traffic_ips: s.append("LIVE")
            bx(f"  {G}{i:2}.{NC} {WHT}{ip}{NC}  {D}{h}{NC}  {D}[{','.join(s)}]{NC}")
    else:
        bx(f"  {D}No active users{NC}")
        bx(f"  {D}(idle won't show){NC}")
    rb_bot(); print(); input(f"  {B}Press Enter{NC} ")

# ══ Main ══
if __name__=="__main__":
    os.system("chmod 600 "+HYST_CONFIG+" 2>/dev/null")
    while True:
        try:
            ch=show_menu()
            if ch=="01": show_info()
            elif ch=="02": do_restart()
            elif ch=="03": do_stop()
            elif ch=="04": do_start()
            elif ch=="05": view_logs()
            elif ch=="06": sys_info()
            elif ch=="07": edit_config()
            elif ch=="08": speed_test()
            elif ch=="09": check_online()
            elif ch=="00":
                os.system("clear"); print()
                rb_top(); bx(f"  {G}Thank You - IDA UDPHysteria{NC}"); rb_bot()
                print(); break
        except KeyboardInterrupt: break
        except Exception as e:
            print(f"  {R}Error: {e}{NC}"); time.sleep(2)
    os.system("clear"); print()
    rb_top(); bx(f"  {G}Thank You - IDA UDPHysteria{NC}"); rb_bot(); print()
