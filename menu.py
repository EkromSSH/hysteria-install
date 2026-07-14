#!/usr/bin/env python3
"""IDA UDPHysteria Manager v3.4 — English Menu + Web Dashboard"""
import os, subprocess, re, unicodedata, json, socket, time, sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from threading import Thread

# ══ Config ══
HYST_CONFIG = "/opt/hysteria/config-v1.json"
WEB_DIR = "/opt/hysteria/web"
WEB_PORT = 82

# ══ Colors ══
R = '\033[0;31m'; G = '\033[0;32m'; O = '\033[0;33m'
Y = '\033[1;33m'; B = '\033[0;34m'; M = '\033[0;35m'
C = '\033[0;36m'; WHT = '\033[1;37m'; BD = '\033[1m'
D = '\033[2m'; NC = '\033[0m'

# ══ Box (W=58) ══
W = 58
H = '\u2550'
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
def box():
    print(f"  {B}\u2554{H*(W-2)}\u2557{NC}")
def bot():
    print(f"  {B}\u255a{H*(W-2)}\u255d{NC}")
def bsep():
    print(f"  {B}\u2560{H*(W-2)}\u2563{NC}")
def bput(c):
    p = max(0, W-6-vislen(c))
    print(f"  {B}\u2551{NC} {c}{' '*p} {B}\u2551{NC}")
def center(t):
    v = vislen(t); l = (W-4-v)//2; r = W-4-v-l
    print(f"  {B}\u2551{NC}{' '*l}{t}{' '*r}{B}\u2551{NC}")
def menu_row(n1, i1, l1, n2, i2, l2):
    left = f"{G}[{n1}]{NC}  {i1}  {l1}"
    right = f"{G}[{n2}]{NC}  {i2}  {l2}"
    bput(f"  {pad(left, 25)}  {pad(right, 21)}")

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
        up = subprocess.run("uptime -p", shell=True, capture_output=True,text=True,timeout=3).stdout.strip().replace("up ","")
        d = re.search(r"(\d+)\s*day", up)
        h = re.search(r"(\d+)\s*hour", up)
        m = re.search(r"(\d+)\s*minute", up)
        if d and h: return f"{d.group(1)}d{h.group(1)}h"
        if d: return f"{d.group(1)}d"
        if h: return f"{h.group(1)}h{m.group(1)}m" if m else f"{h.group(1)}h"
        if m: return f"{m.group(1)}m"
    except: pass
    return ""
def _get_ips_from_conntrack(port):
    ips = {}
    try:
        r = subprocess.run(f"conntrack -L -p udp 2>/dev/null | grep -F 'dport={port}'",
                          shell=True, capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'src=(\d+\.\d+\.\d+\.\d+)', r.stdout):
            ip = m.group(1)
            if not ip.startswith("127."):
                ips[ip] = ips.get(ip, 0) + 1
    except: pass
    return ips
def _get_ips_from_logs():
    ips = {}
    try:
        r = subprocess.run(["journalctl","-u","hysteria","--no-pager","--since","5 min ago"],
                          capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'\[src:(\d+\.\d+\.\d+\.\d+):\d+\]', r.stdout):
            ips[m.group(1)] = ips.get(m.group(1), 0) + 1
    except: pass
    return ips
def count_online():
    p, _, _ = read_config()
    return len(_get_ips_from_conntrack(p))

# ══ Web Dashboard ══
def get_dashboard_data():
    p, a, o = read_config()
    ip = get_ip()
    st = get_status()
    ct_ips = _get_ips_from_conntrack(p)
    log_ips = _get_ips_from_logs()
    all_ips = {}
    for src, ips in [("conntrack", ct_ips), ("log", log_ips)]:
        for ip_addr, cnt in ips.items():
            if ip_addr not in all_ips: all_ips[ip_addr] = {"conntrack": 0, "log": 0}
            all_ips[ip_addr][src] = cnt
    return {
        "server_ip": ip,
        "port": p,
        "auth": a,
        "obfs": o,
        "status": st,
        "uptime": get_uptime(),
        "online_users": len(all_ips),
        "users_list": [{"ip": ip, "conntrack": v["conntrack"], "log": v["log"]} for ip, v in all_ips.items()]
    }

DASHBOARD_HTML = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>IDA UDPHysteria Dashboard</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0d1117;color:#e6edf3;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;max-width:1200px;margin:0 auto;padding:20px}
h1{font-size:1.8rem;margin-bottom:20px;text-align:center}
h2{font-size:1.2rem;margin-bottom:10px;color:#58a6ff}
.muted{color:#8b949e}
.grid{display:grid;gap:20px;margin-bottom:20px}
@media(min-width:900px){.grid{grid-template-columns:1fr 1fr}}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:16px;box-shadow:0 2px 4px rgba(0,0,0,.3)}
.card h3{color:#58a6ff;margin-bottom:12px;font-size:1.1rem}
.stat{font-size:2rem;font-weight:bold;color:#3fb950}
.stat-label{color:#8b949e;font-size:.9rem}
table{width:100%;border-collapse:collapse;margin-top:10px;font-size:.95rem}
th,td{padding:10px;text-align:left}
th{background:#1f242c;color:#c9d1d9;font-weight:600}
tr:nth-child(even){background:#1a1f27}
tr:nth-child(odd){background:#161b22}
.ok{color:#3fb950;font-weight:600}
.err{color:#f85149;font-weight:600}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:.8rem;font-weight:600}
.badge-ok{background:#238636;color:#fff}
.badge-err{background:#da3633;color:#fff}
.rainbow{height:4px;background:linear-gradient(90deg,#f85149,#d29922,#3fb950,#58a6ff,#bc8cff);border-radius:2px;margin-bottom:20px}
.refresh{background:#238636;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-size:.9rem}
.refresh:hover{background:#2ea043}
#auto-refresh{margin-left:10px}
footer{text-align:center;color:#8b949e;margin-top:20px;font-size:.85rem}
</style>
</head>
<body>
<div class="rainbow"></div>
<h1>&#x1F680; IDA UDPHysteria Dashboard</h1>
<div class="grid">
<div class="card">
<h3>&#x1F4CA; Server Status</h3>
<table>
<tr><td class="muted">Server IP</td><td id="ip">Loading...</td></tr>
<tr><td class="muted">Port</td><td id="port">-</td></tr>
<tr><td class="muted">Auth</td><td id="auth">-</td></tr>
<tr><td class="muted">Obfs</td><td id="obfs">-</td></tr>
<tr><td class="muted">Status</td><td id="status">-</td></tr>
<tr><td class="muted">Uptime</td><td id="uptime">-</td></tr>
</table>
</div>
<div class="card">
<h3>&#x1F465; Online Users</h3>
<div style="text-align:center;padding:20px">
<div class="stat" id="users-count">0</div>
<div class="stat-label">Connected Users</div>
</div>
</div>
</div>
<div class="card">
<h3>&#x1F4CA; User List</h3>
<table>
<thead><tr><th>#</th><th>IP Address</th><th>Conntrack</th><th>Logs</th></tr></thead>
<tbody id="users-table"><tr><td colspan="4" class="muted">Loading...</td></tr></tbody>
</table>
</div>
<div style="text-align:center;margin-top:20px">
<button class="refresh" onclick="fetchData()">&#x1F504; Refresh</button>
<label id="auto-refresh"><input type="checkbox" checked onchange="toggleAuto()"> Auto-refresh (10s)</label>
</div>
<footer>IDA UDPHysteria v3.4 &mdash; Powered by conntrack</footer>
<script>
let auto=true;let timer;
function toggleAuto(){auto=document.querySelector("#auto-refresh input").checked;if(auto)startTimer();else clearInterval(timer)}
function startTimer(){clearInterval(timer);timer=setInterval(fetchData,10000)}
async function fetchData(){
try{const r=await fetch("/api/status");const d=await r.json();
document.getElementById("ip").textContent=d.server_ip;
document.getElementById("port").textContent=d.port;
document.getElementById("auth").textContent=d.auth||"-";
document.getElementById("obfs").textContent=d.obfs||"-";
document.getElementById("status").innerHTML=d.status=="active"?'<span class="badge badge-ok">ONLINE</span>':'<span class="badge badge-err">OFFLINE</span>';
document.getElementById("uptime").textContent=d.uptime||"-";
document.getElementById("users-count").textContent=d.online_users;
const tb=document.getElementById("users-table");
if(d.users_list.length>0){tb.innerHTML=d.users_list.map((u,i)=>"<tr><td>"+(i+1)+"</td><td>"+u.ip+"</td><td>"+u.conntrack+"</td><td>"+u.log+"</td></tr>").join("")}
else{tb.innerHTML='<tr><td colspan="4" class="muted">No users online</td></tr>'}
}catch(e){console.error(e)}}
fetchData();startTimer();
</script>
</body>
</html>'''

class DashboardHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(DASHBOARD_HTML.encode())
        elif self.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            data = get_dashboard_data()
            self.wfile.write(json.dumps(data).encode())
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, format, *args):
        pass  # Suppress logs

def start_web_server():
    os.makedirs(WEB_DIR, exist_ok=True)
    with open(f"{WEB_DIR}/index.html", "w") as f:
        f.write(DASHBOARD_HTML)
    try:
        server = HTTPServer(("0.0.0.0", WEB_PORT), DashboardHandler)
        server.serve_forever()
    except OSError:
        pass

def is_web_running():
    try:
        r = subprocess.run(f"curl -s --connect-timeout 2 http://127.0.0.1:{WEB_PORT}/api/status",
                          shell=True, capture_output=True,text=True,timeout=3)
        return "server_ip" in r.stdout
    except: return False

# ══ Menu Screen ══
def show_menu():
    p, a, o = read_config(); ip = get_ip(); st = get_status(); on = count_online()
    u = get_uptime()
    stt = f"{G}ONLINE{NC}" if st=="active" else f"{R}OFFLINE{NC}"
    web_st = f"{G}RUNNING{NC}" if is_web_running() else f"{R}STOPPED{NC}"
    os.system("clear")
    print()
    box()
    center(f"  {R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}  {WHT}IDA UDPHysteria{NC}  {R}\u2588\u2588{O}\u2588\u2588{Y}\u2588\u2588{G}\u2588\u2588{C}\u2588\u2588{B}\u2588\u2588{M}\u2588\u2588{NC}")
    center(f"{D}Hysteria v1 Server Manager{NC}")
    bsep()
    LW = 12
    info = [
        ("Server IP", ip),
        ("Port", f"{p} (20000-50000)"),
        ("Auth", a if a else "-"),
        ("Obfs", o if o else "-"),
        ("Status", f"{stt}  Users:{on}  Up:{u}"),
        ("Web Panel", f"{web_st}  Port:{WEB_PORT}"),
    ]
    for label, val in info:
        bput(f"{D}{pad(label, LW)}{NC} : {WHT}{val}{NC}")
    bput(f"  {R}\u258c{NC}{O}\u258c{NC}{Y}\u258c{NC}{G}\u258c{NC}{C}\u258c{NC}{B}\u258c{NC}{M}\u258c{NC}")
    bput(f"  {D}{'='*14}  {NC}SELECT OPTION{D}  {'='*14}{NC}")
    bput("")
    menu_row("01","📊","Connection Info","07","🔑","Edit AUTH")
    menu_row("02","🔄","Restart","08","🔏","Edit OBFS")
    menu_row("03","⛔","Stop","09","🔧","Change Port")
    menu_row("04","▶","Start","10","👥","Online Users")
    menu_row("05","📜","View Logs","11","🌐","Speed Test")
    menu_row("06","🔍","System Info","12","🖥️","Web Dashboard")
    menu_row("00","🚪","Exit","","","")
    bput("")
    bsep()
    bot()
    print()
    return input(f"  {Y}>>{NC} {BD}Choose{NC} {D}[00-12]{NC} : ").strip()

# ══ Screens ══
def show_info():
    p,a,o = read_config(); ip = get_ip()
    os.system("clear"); print(); box(); center(f"{G}📊{NC} {BD}Connection Info{NC}"); bsep()
    bput(f"Protocol   : {WHT}UDP Hysteria v1{NC}")
    bput(f"Server     : {WHT}{ip}{NC}")
    bput(f"Port       : {WHT}{p}{NC}")
    bput(f"Auth       : {WHT}{a}{NC}")
    bput(f"Obfs       : {WHT}{o}{NC}")
    bput(f"Port Range : {WHT}20000-50000{NC}")
    bput(f"Config     : {WHT}{HYST_CONFIG}{NC}")
    bput("")
    bput(f"{D}Use this info in Creeb / v2 Box client{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def do_restart():
    os.system("clear"); print(); box(); center(f"{Y}🔄{NC} {BD}Restart Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(2)
    new_st = get_status()
    bput(f"{G}✅{NC} Restarted" if new_st=="active" else f"{R}❌{NC} Failed")
    bsep(); bot(); print(); time.sleep(1.5)

def do_stop():
    os.system("clear"); print(); box(); center(f"{R}⛔{NC} {BD}Stop Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","stop","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(1)
    bput(f"{G}✅{NC} Stopped")
    bsep(); bot(); print(); time.sleep(1.5)

def do_start():
    os.system("clear"); print(); box(); center(f"{G}▶{NC} {BD}Start Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","start","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(2)
    new_st = get_status()
    bput(f"{G}✅{NC} Started" if new_st=="active" else f"{R}❌{NC} Failed")
    bsep(); bot(); print(); time.sleep(1.5)

def view_logs():
    os.system("clear"); print(); box(); center(f"{C}📜{NC} {BD}Logs (Last 10 min){NC}"); bsep()
    r = subprocess.run(["journalctl","-u","hysteria","--no-pager","-n","30","--since","10 min ago"],
                       capture_output=True,text=True,timeout=5)
    for line in r.stdout.strip().split("\n")[-20:]:
        bput(f"{D}{line[:52]}{NC}")
    if not r.stdout.strip(): bput(f"{D}  No recent logs{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def sys_info():
    os.system("clear"); print(); box(); center(f"{M}🔍{NC} {BD}System Info{NC}"); bsep()
    for cmd, label in [
        ("hostname -f","Hostname"), ("uname -r","Kernel"), ("uptime -p","Uptime"),
        ("free -h | awk '/Mem:/{print $3\"/\"$2}'","Memory"), ("df -h / | awk 'NR==2{print $3\"/\"$2}'","Disk"),
    ]:
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True,text=True,timeout=3)
            val = r.stdout.strip().strip('"')[:30]
            bput(f"{D}{pad(label,12)}{NC} : {WHT}{val}{NC}")
        except: pass
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def edit_auth():
    os.system("clear"); print(); box(); center(f"{M}🔑{NC} {BD}Edit AUTH{NC}"); bsep()
    _,old,_ = read_config()
    bput(f"Current AUTH : {WHT}{old}{NC}")
    bput("")
    new_auth = input(f"  {Y}>>{NC} New AUTH (empty=cancel) : ").strip()
    if not new_auth: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        d["auth_str"] = new_auth
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2)
        bput(f"{G}✅{NC} AUTH updated & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def edit_obfs():
    os.system("clear"); print(); box(); center(f"{M}🔏{NC} {BD}Edit OBFS{NC}"); bsep()
    _,_,old = read_config()
    bput(f"Current OBFS : {WHT}{old}{NC}")
    bput("")
    new_obfs = input(f"  {Y}>>{NC} New OBFS (empty=cancel) : ").strip()
    if not new_obfs: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        d["obfs"] = new_obfs
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2)
        bput(f"{G}✅{NC} OBFS updated & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def change_port():
    os.system("clear"); print(); box(); center(f"{M}🔧{NC} {BD}Change Port{NC}"); bsep()
    p,_,_ = read_config()
    bput(f"Current Port : {WHT}{p}{NC}")
    bput("")
    new_port = input(f"  {Y}>>{NC} New Port (empty=cancel) : ").strip()
    if not new_port: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    if not new_port.isdigit() or not (1 <= int(new_port) <= 65535):
        bput(f"{R}❌{NC} Invalid port"); bsep(); bot(); print(); time.sleep(2); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        old_listen = d.get("listen", ":25000")
        prefix = old_listen.rsplit(":", 1)[0]
        d["listen"] = f"{prefix}:{new_port}"
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2)
        bput(f"{G}✅{NC} Port changed to {new_port} & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def check_online():
    os.system("clear"); print(); box(); center(f"{M}👥{NC} {BD}Online Users{NC}"); bsep()
    bput(f"{D}  Scanning: conntrack + logs...{NC}")
    print(f"\r", end="")
    p, _, _ = read_config()
    try:
        ct_ips = _get_ips_from_conntrack(p)
        bput(f"  {D}Conntrack:{NC} {WHT}{len(ct_ips)}{NC} user(s)")
        log_ips = _get_ips_from_logs()
        bput(f"  {D}Logs (5 min):{NC} {WHT}{len(log_ips)}{NC} client(s)")
        all_ips = {}
        for src_name, ip_dict in [("CONNTRACK", ct_ips), ("LOG", log_ips)]:
            for ip, cnt in ip_dict.items():
                if ip not in all_ips: all_ips[ip] = {"conntrack": 0, "log": 0}
                all_ips[ip][src_name.lower()] = cnt
        bput("")
        bput(f"  {WHT}Total unique users: {len(all_ips)}{NC}")
        bput("")
        if all_ips:
            for i, (ip, info) in enumerate(sorted(all_ips.items(), key=lambda x: -(x[1]["conntrack"]+x[1]["log"]))[:10], 1):
                try: h = socket.gethostbyaddr(ip)[0][:30]
                except: h = "unknown"
                src = []
                if info["conntrack"]: src.append(f"CONN:{info['conntrack']}")
                if info["log"]: src.append(f"LOG:{info['log']}")
                bput(f"  {G}{i:2}.{NC} {WHT}{ip}{NC}  {D}{h}{NC}  {D}[{','.join(src)}]{NC}")
        else:
            bput(f"  {D}No active users detected{NC}")
    except Exception as e:
        bput(f"  {R}Error: {e}{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def speed_test():
    os.system("clear"); print(); box(); center(f"{G}🌐{NC} {BD}Speed Test{NC}"); bsep()
    bput(f"{D}  Testing download speed...{NC}")
    print(f"\r", end="")
    try:
        r = subprocess.run("curl -s -o /dev/null -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=10000000",
                           shell=True, capture_output=True,text=True,timeout=30)
        bps = float(r.stdout.strip().replace("'",""))
        mbps = bps * 8 / 1_000_000
        bput(f"  {WHT}{mbps:.1f} Mbps{NC} download")
    except:
        bput(f"  {R}Test failed{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def web_dashboard():
    os.system("clear"); print(); box(); center(f"{C}🖥️{NC} {BD}Web Dashboard{NC}"); bsep()
    ip = get_ip()
    running = is_web_running()
    if running:
        bput(f"  {G}✅{NC} Web Dashboard is {G}RUNNING{NC}")
        bput(f"  {D}Open: {WHT}http://{ip}:{WEB_PORT}{NC}")
        bput("")
        bput(f"  {Y}[1]{NC} Stop Web Server")
        bput(f"  {Y}[2]{NC} Restart Web Server")
        bput(f"  {Y}[0]{NC} Back")
        ch = input(f"  {Y}>>{NC} Choose: ").strip()
        if ch == "1":
            subprocess.run(f"pkill -f 'python3.*hysteria-menu.py.*web'", shell=True, capture_output=True)
            subprocess.run(f"pkill -f 'python3 -m http.server {WEB_PORT}'", shell=True, capture_output=True)
            time.sleep(1)
            bput(f"  {G}✅{NC} Web server stopped")
            time.sleep(1.5)
        elif ch == "2":
            subprocess.run(f"pkill -f 'python3.*hysteria-menu.py.*web'", shell=True, capture_output=True)
            subprocess.run(f"pkill -f 'python3 -m http.server {WEB_PORT}'", shell=True, capture_output=True)
            time.sleep(1)
            Thread(target=start_web_server, daemon=True).start()
            time.sleep(2)
            bput(f"  {G}✅{NC} Web server restarted")
            time.sleep(1.5)
    else:
        bput(f"  {R}❌{NC} Web Dashboard is {R}STOPPED{NC}")
        bput("")
        bput(f"  {Y}[1]{NC} Start Web Server")
        bput(f"  {Y}[0]{NC} Back")
        ch = input(f"  {Y}>>{NC} Choose: ").strip()
        if ch == "1":
            Thread(target=start_web_server, daemon=True).start()
            time.sleep(2)
            if is_web_running():
                bput(f"  {G}✅{NC} Web server started!")
                bput(f"  {D}Open: {WHT}http://{ip}:{WEB_PORT}{NC}")
            else:
                bput(f"  {R}❌{NC} Failed to start")
            time.sleep(2)
    bsep(); bot(); print()

# ══ Main ══
if __name__ == "__main__":
    os.system("chmod 600 " + HYST_CONFIG + " 2>/dev/null")
    # Start web server in background if not running
    if not is_web_running():
        Thread(target=start_web_server, daemon=True).start()
    while True:
        try:
            ch = show_menu()
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
            elif ch == "12": web_dashboard()
            elif ch == "00":
                os.system("clear"); print()
                box(); center(f"{G}👋{NC} {BD}Thank You - IDA UDPHysteria{NC}"); bot()
                print()
                break
            else:
                if ch: pass
        except KeyboardInterrupt: break
        except Exception as e:
            print(f"  {R}Error: {e}{NC}"); time.sleep(2)
    os.system("clear"); print(); box(); center(f"{G}👋{NC} {BD}Thank You - IDA UDPHysteria{NC}"); bot(); print()
