#!/usr/bin/env python3
"""IDA UDPHysteria Manager v4.0 — All-in-One (ShowOn features merged)"""
import os, subprocess, re, unicodedata, json, socket, time, sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from threading import Thread

# ══ Config ══
HYST_CONFIG = "/opt/hysteria/config-v1.json"
WEB_DIR = "/opt/hysteria/web"
WEB_PORT = 82
SWAP_FILE = "/swapfile"

# ══ Colors ══
R = '\033[0;31m'; G = '\033[0;32m'; O = '\033[0;33m'
Y = '\033[1;33m'; B = '\033[0;34m'; M = '\033[0;35m'
C = '\033[0;36m'; WHT = '\033[1;37m'; BD = '\033[1m'
D = '\033[2m'; NC = '\033[0m'

# ══ Box (W=60) ══
W = 60
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
    bput(f"  {pad(left, 27)}  {pad(right, 23)}")

# ══ System Detection ══
def get_ip():
    try: return subprocess.check_output("curl -s --connect-timeout 3 ifconfig.me", shell=True, timeout=5).decode().strip()
    except: return "N/A"
def get_nic():
    try:
        r = subprocess.run("ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\") print $(i+1)}' | head -1",
                          shell=True, capture_output=True,text=True,timeout=3)
        return r.stdout.strip() or "eth0"
    except: return "eth0"
def read_config():
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        port = d.get("listen", ":25000").split(":")[-1]
        return port, d.get("auth_str", ""), d.get("obfs", "")
    except: return "25000", "", ""
def get_status():
    try: return subprocess.run(["systemctl","is-active","hysteria"], capture_output=True,text=True,timeout=3).stdout.strip()
    except: return "inactive"
def get_uptime():
    try:
        r = subprocess.run("uptime -p", shell=True, capture_output=True,text=True,timeout=3)
        return r.stdout.strip().replace("up ", "")
    except: return ""

# ══ Online Detection (ShowOn-style) ══
def count_ssh():
    count = 0
    try:
        r = subprocess.run("ss -tn state established 2>/dev/null | grep -E ':22\\s' | wc -l",
                          shell=True, capture_output=True,text=True,timeout=3)
        count = int(r.stdout.strip() or 0)
    except: pass
    return count

def count_dropbear():
    count = 0
    try:
        r = subprocess.run("ps aux | grep '[d]ropbear' | wc -l", shell=True, capture_output=True,text=True,timeout=3)
        count = max(0, int(r.stdout.strip() or 0) - 1)
    except: pass
    return count

def count_openvpn():
    count = 0
    try:
        status_file = "/etc/openvpn/server/openvpn-status.log"
        if os.path.exists(status_file):
            r = subprocess.run(f"grep -c '^CLIENT_LIST' {status_file}", shell=True, capture_output=True,text=True,timeout=3)
            count = int(r.stdout.strip() or 0)
    except: pass
    return count

def count_hysteria():
    p, _, _ = read_config()
    ips = {}
    try:
        r = subprocess.run(f"conntrack -L -p udp 2>/dev/null | grep -F 'dport={p}'",
                          shell=True, capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'src=(\d+\.\d+\.\d+\.\d+)', r.stdout):
            ip = m.group(1)
            if not ip.startswith("127.") and not ip.startswith("10.") and not ip.startswith("192.168."):
                ips[ip] = True
    except: pass
    return len(ips)

def get_hysteria_ips():
    p, _, _ = read_config()
    ips = {}
    try:
        r = subprocess.run(f"conntrack -L -p udp 2>/dev/null | grep -F 'dport={p}'",
                          shell=True, capture_output=True,text=True,timeout=5)
        for m in re.finditer(r'src=(\d+\.\d+\.\d+\.\d+)', r.stdout):
            ip = m.group(1)
            if not ip.startswith("127.") and not ip.startswith("10.") and not ip.startswith("192.168."):
                ips[ip] = ips.get(ip, 0) + 1
    except: pass
    return ips

def get_vnstat_traffic():
    rx, tx = 0, 0
    try:
        r = subprocess.run("vnstat --json a 2>/dev/null", shell=True, capture_output=True,text=True,timeout=5)
        if r.stdout:
            d = json.loads(r.stdout)
            rx = d.get("interfaces", [{}])[0].get("traffic", {}).get("total", {}).get("rx", 0)
            tx = d.get("interfaces", [{}])[0].get("traffic", {}).get("total", {}).get("tx", 0)
    except: pass
    return rx, tx

def get_sysinfo():
    info = {}
    try:
        r = subprocess.run("uptime -p", shell=True, capture_output=True,text=True,timeout=3)
        info["uptime"] = r.stdout.strip().replace("up ", "")
    except: info["uptime"] = "N/A"
    try:
        r = subprocess.run("top -bn1 | awk '/Cpu\\(s\\)/ {print $8}'", shell=True, capture_output=True,text=True,timeout=3)
        cpu_free = float(r.stdout.strip() or 0)
        info["cpu"] = f"{100 - cpu_free:.1f}%"
    except: info["cpu"] = "N/A"
    try:
        r = subprocess.run("free -m | awk 'NR==2{printf \"%s/%sMB\",$3,$2}'", shell=True, capture_output=True,text=True,timeout=3)
        info["ram"] = r.stdout.strip()
    except: info["ram"] = "N/A"
    try:
        r = subprocess.run("df -h / | awk 'NR==2{printf \"%s/%s\",$3,$2}'", shell=True, capture_output=True,text=True,timeout=3)
        info["disk"] = r.stdout.strip()
    except: info["disk"] = "N/A"
    try:
        r = subprocess.run("cat /proc/loadavg | awk '{print $1}'", shell=True, capture_output=True,text=True,timeout=3)
        info["load"] = r.stdout.strip()
    except: info["load"] = "N/A"
    return info

def get_swap_info():
    try:
        r = subprocess.run("free -h | awk '/Swap:/{print $2}'", shell=True, capture_output=True,text=True,timeout=3)
        return r.stdout.strip()
    except: return "N/A"

# ══ Web Dashboard ══
def get_dashboard_data():
    p, a, o = read_config()
    ip = get_ip()
    st = get_status()
    ssh = count_ssh()
    db = count_dropbear()
    ovpn = count_openvpn()
    hy = count_hysteria()
    total = ssh + db + ovpn + hy
    rx, tx = get_vnstat_traffic()
    sysinfo = get_sysinfo()
    hy_ips = get_hysteria_ips()
    return {
        "server_ip": ip, "port": p, "auth": a, "obfs": o,
        "status": st, "uptime": sysinfo["uptime"],
        "total_online": total,
        "ssh": ssh, "dropbear": db, "openvpn": ovpn, "hysteria": hy,
        "vnstat_rx": rx, "vnstat_tx": tx,
        "cpu": sysinfo["cpu"], "ram": sysinfo["ram"], "disk": sysinfo["disk"],
        "load": sysinfo["load"],
        "hysteria_users": [{"ip": ip, "count": c} for ip, c in hy_ips.items()]
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
h2{font-size:1.1rem;margin-bottom:10px;color:#58a6ff}
.muted{color:#8b949e}
.grid{display:grid;gap:16px;margin-bottom:16px}
@media(min-width:900px){.grid{grid-template-columns:1fr 1fr 1fr 1fr}}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:16px;box-shadow:0 2px 4px rgba(0,0,0,.3)}
.stat{font-size:2rem;font-weight:bold;color:#3fb950}
.stat-label{color:#8b949e;font-size:.85rem}
table{width:100%;border-collapse:collapse;margin-top:10px;font-size:.9rem}
th,td{padding:8px;text-align:left}
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
footer{text-align:center;color:#8b949e;margin-top:20px;font-size:.85rem}
.card-wide{grid-column:span 2}
@media(max-width:900px){.card-wide{grid-column:span 1}}
</style>
</head>
<body>
<div class="rainbow"></div>
<h1>&#x1F680; IDA UDPHysteria Dashboard</h1>
<div class="grid">
<div class="card"><h2>&#x1F4E1; SSH</h2><div style="text-align:center"><div class="stat" id="ssh">0</div><div class="stat-label">Online</div></div></div>
<div class="card"><h2>&#x1F510; Dropbear</h2><div style="text-align:center"><div class="stat" id="dropbear">0</div><div class="stat-label">Online</div></div></div>
<div class="card"><h2>&#x1F535; OpenVPN</h2><div style="text-align:center"><div class="stat" id="openvpn">0</div><div class="stat-label">Online</div></div></div>
<div class="card"><h2>&#x1F680; Hysteria</h2><div style="text-align:center"><div class="stat" id="hysteria">0</div><div class="stat-label">Online</div></div></div>
</div>
<div class="grid">
<div class="card"><h2>&#x1F4CA; Total Online</h2><div style="text-align:center"><div class="stat" style="font-size:2.5rem;color:#58a6ff" id="total">0</div><div class="stat-label">All Services</div></div></div>
<div class="card"><h2>&#x1F4BB; CPU</h2><div style="text-align:center"><div class="stat" id="cpu">0%</div><div class="stat-label">Usage</div></div></div>
<div class="card"><h2>&#x1F9E0; RAM</h2><div style="text-align:center"><div class="stat" style="font-size:1.5rem" id="ram">0/0MB</div><div class="stat-label">Usage</div></div></div>
<div class="card"><h2>&#x1F4BE; Disk</h2><div style="text-align:center"><div class="stat" style="font-size:1.5rem" id="disk">0/0</div><div class="stat-label">Usage</div></div></div>
</div>
<div class="grid">
<div class="card card-wide">
<h2>&#x1F310; Server Info</h2>
<table>
<tr><td class="muted">Server IP</td><td id="ip">Loading...</td></tr>
<tr><td class="muted">Port</td><td id="port">-</td></tr>
<tr><td class="muted">Auth</td><td id="auth">-</td></tr>
<tr><td class="muted">Obfs</td><td id="obfs">-</td></tr>
<tr><td class="muted">Status</td><td id="status">-</td></tr>
<tr><td class="muted">Uptime</td><td id="uptime">-</td></tr>
<tr><td class="muted">Load Avg</td><td id="load">-</td></tr>
</table>
</div>
<div class="card card-wide">
<h2>&#x1F4CA; Traffic (vnStat)</h2>
<table>
<tr><td class="muted">Download (Total)</td><td id="rx">0</td></tr>
<tr><td class="muted">Upload (Total)</td><td id="tx">0</td></tr>
</table>
</div>
</div>
<div class="card" style="margin-bottom:16px">
<h2>&#x1F465; Hysteria Users</h2>
<table>
<thead><tr><th>#</th><th>IP Address</th><th>Packets</th></tr></thead>
<tbody id="users-table"><tr><td colspan="3" class="muted">Loading...</td></tr></tbody>
</table>
</div>
<div style="text-align:center;margin-top:16px">
<button class="refresh" onclick="fetchData()">&#x1F504; Refresh</button>
<span class="muted" style="margin-left:10px">Auto-refresh: 10s</span>
</div>
<footer>IDA UDPHysteria v4.0 &mdash; Powered by conntrack + vnStat</footer>
<script>
function fmt(b){if(b>=1073741824)return(b/1073741824).toFixed(1)+" GB";if(b>=1048576)return(b/1048576).toFixed(1)+" MB";if(b>=1024)return(b/1024).toFixed(1)+" KB";return b+" B"}
async function fetchData(){
try{const r=await fetch("/api/status");const d=await r.json();
document.getElementById("ssh").textContent=d.ssh;
document.getElementById("dropbear").textContent=d.dropbear;
document.getElementById("openvpn").textContent=d.openvpn;
document.getElementById("hysteria").textContent=d.hysteria;
document.getElementById("total").textContent=d.total_online;
document.getElementById("cpu").textContent=d.cpu;
document.getElementById("ram").textContent=d.ram;
document.getElementById("disk").textContent=d.disk;
document.getElementById("ip").textContent=d.server_ip;
document.getElementById("port").textContent=d.port;
document.getElementById("auth").textContent=d.auth||"-";
document.getElementById("obfs").textContent=d.obfs||"-";
document.getElementById("status").innerHTML=d.status=="active"?'<span class="badge badge-ok">ONLINE</span>':'<span class="badge badge-err">OFFLINE</span>';
document.getElementById("uptime").textContent=d.uptime||"-";
document.getElementById("load").textContent=d.load||"-";
document.getElementById("rx").textContent=fmt(d.vnstat_rx);
document.getElementById("tx").textContent=fmt(d.vnstat_tx);
const tb=document.getElementById("users-table");
if(d.hysteria_users.length>0){tb.innerHTML=d.hysteria_users.map((u,i)=>"<tr><td>"+(i+1)+"</td><td>"+u.ip+"</td><td>"+u.count+"</td></tr>").join("")}
else{tb.innerHTML='<tr><td colspan="3" class="muted">No users online</td></tr>'}
}catch(e){console.error(e)}}
fetchData();setInterval(fetchData,10000);
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
    def log_message(self, format, *args): pass

def start_web_server():
    os.makedirs(WEB_DIR, exist_ok=True)
    try:
        server = HTTPServer(("0.0.0.0", WEB_PORT), DashboardHandler)
        server.serve_forever()
    except OSError: pass

def is_web_running():
    try:
        r = subprocess.run(f"curl -s --connect-timeout 2 http://127.0.0.1:{WEB_PORT}/api/status",
                          shell=True, capture_output=True,text=True,timeout=3)
        return "server_ip" in r.stdout
    except: return False

# ══ Menu Screen ══
def show_menu():
    p, a, o = read_config(); ip = get_ip(); st = get_status()
    u = get_uptime()
    ssh = count_ssh(); db = count_dropbear(); ovpn = count_openvpn(); hy = count_hysteria()
    total = ssh + db + ovpn + hy
    stt = f"{G}ONLINE{NC}" if st=="active" else f"{R}OFFLINE{NC}"
    web_st = f"{G}ON{NC}" if is_web_running() else f"{R}OFF{NC}"
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
        ("Status", f"{stt}  Up:{u}"),
        ("Online", f"Total:{WHT}{total}{NC}  SSH:{WHT}{ssh}{NC}  DB:{WHT}{db}{NC}  OVPN:{WHT}{ovpn}{NC}  Hy:{WHT}{hy}{NC}"),
        ("Web Panel", f"{web_st}  Port:{WEB_PORT}"),
    ]
    for label, val in info:
        bput(f"{D}{pad(label, LW)}{NC} : {val}")
    bput(f"  {R}\u258c{NC}{O}\u258c{NC}{Y}\u258c{NC}{G}\u258c{NC}{C}\u258c{NC}{B}\u258c{NC}{M}\u258c{NC}")
    bput(f"  {D}{'='*14}  {NC}SELECT OPTION{D}  {'='*14}{NC}")
    bput("")
    menu_row("01","📊","Connection Info","09","🔑","Edit AUTH")
    menu_row("02","🔄","Restart","10","🔏","Edit OBFS")
    menu_row("03","⛔","Stop","11","🔧","Change Port")
    menu_row("04","▶","Start","12","👥","Online Users")
    menu_row("05","📜","View Logs","13","🌐","Speed Test")
    menu_row("06","🔍","System Info","14","🖥️","Web Dashboard")
    menu_row("07","📈","Traffic Stats","15","💾","Setup Swap")
    menu_row("08","🐛","Debug Log","00","🚪","Exit")
    bput("")
    bsep()
    bot()
    print()
    return input(f"  {Y}>>{NC} {BD}Choose{NC} {D}[00-15]{NC} : ").strip()

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
    bput(f"{G}✅{NC} Restarted" if get_status()=="active" else f"{R}❌{NC} Failed")
    bsep(); bot(); print(); time.sleep(1.5)

def do_stop():
    os.system("clear"); print(); box(); center(f"{R}⛔{NC} {BD}Stop Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","stop","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(1); bput(f"{G}✅{NC} Stopped"); bsep(); bot(); print(); time.sleep(1.5)

def do_start():
    os.system("clear"); print(); box(); center(f"{G}▶{NC} {BD}Start Hysteria{NC}"); bsep()
    subprocess.run(["systemctl","start","hysteria"], capture_output=True,text=True,timeout=10)
    time.sleep(2)
    bput(f"{G}✅{NC} Started" if get_status()=="active" else f"{R}❌{NC} Failed")
    bsep(); bot(); print(); time.sleep(1.5)

def view_logs():
    os.system("clear"); print(); box(); center(f"{C}📜{NC} {BD}Logs (Last 10 min){NC}"); bsep()
    r = subprocess.run(["journalctl","-u","hysteria","--no-pager","-n","30","--since","10 min ago"],
                       capture_output=True,text=True,timeout=5)
    for line in r.stdout.strip().split("\n")[-20:]:
        bput(f"{D}{line[:54]}{NC}")
    if not r.stdout.strip(): bput(f"{D}  No recent logs{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def sys_info():
    os.system("clear"); print(); box(); center(f"{M}🔍{NC} {BD}System Info{NC}"); bsep()
    si = get_sysinfo()
    for label, val in [("Hostname", subprocess.run("hostname -f",shell=True,capture_output=True,text=True,timeout=3).stdout.strip()),
                       ("Kernel", subprocess.run("uname -r",shell=True,capture_output=True,text=True,timeout=3).stdout.strip()),
                       ("Uptime", si["uptime"]), ("CPU", si["cpu"]), ("RAM", si["ram"]),
                       ("Disk", si["disk"]), ("Load", si["load"]),
                       ("NIC", get_nic()), ("Swap", get_swap_info())]:
        bput(f"{D}{pad(label,12)}{NC} : {WHT}{val[:35]}{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def traffic_stats():
    os.system("clear"); print(); box(); center(f"{G}📈{NC} {BD}Traffic Stats (vnStat){NC}"); bsep()
    rx, tx = get_vnstat_traffic()
    def fmt(b):
        if b >= 1073741824: return f"{b/1073741824:.1f} GB"
        if b >= 1048576: return f"{b/1048576:.1f} MB"
        if b >= 1024: return f"{b/1024:.1f} KB"
        return f"{b} B"
    bput(f"  {D}Download (Total){NC} : {WHT}{fmt(rx)}{NC}")
    bput(f"  {D}Upload (Total){NC}   : {WHT}{fmt(tx)}{NC}")
    bput("")
    try:
        r = subprocess.run("vnstat -d 2>/dev/null | head -15", shell=True, capture_output=True,text=True,timeout=5)
        for line in r.stdout.strip().split("\n")[:12]:
            bput(f"  {D}{line[:54]}{NC}")
    except: pass
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def edit_auth():
    os.system("clear"); print(); box(); center(f"{M}🔑{NC} {BD}Edit AUTH{NC}"); bsep()
    _,old,_ = read_config()
    bput(f"Current AUTH : {WHT}{old}{NC}"); bput("")
    new = input(f"  {Y}>>{NC} New AUTH (empty=cancel) : ").strip()
    if not new: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        d["auth_str"] = new
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2); bput(f"{G}✅{NC} AUTH updated & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def edit_obfs():
    os.system("clear"); print(); box(); center(f"{M}🔏{NC} {BD}Edit OBFS{NC}"); bsep()
    _,_,old = read_config()
    bput(f"Current OBFS : {WHT}{old}{NC}"); bput("")
    new = input(f"  {Y}>>{NC} New OBFS (empty=cancel) : ").strip()
    if not new: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        d["obfs"] = new
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2); bput(f"{G}✅{NC} OBFS updated & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def change_port():
    os.system("clear"); print(); box(); center(f"{M}🔧{NC} {BD}Change Port{NC}"); bsep()
    p,_,_ = read_config()
    bput(f"Current Port : {WHT}{p}{NC}"); bput("")
    new = input(f"  {Y}>>{NC} New Port (empty=cancel) : ").strip()
    if not new: bput(f"{D}  Cancelled{NC}"); bsep(); bot(); print(); time.sleep(1); return
    if not new.isdigit() or not (1 <= int(new) <= 65535):
        bput(f"{R}❌{NC} Invalid port"); bsep(); bot(); print(); time.sleep(2); return
    try:
        with open(HYST_CONFIG) as f: d = json.load(f)
        old_listen = d.get("listen", ":25000")
        d["listen"] = f"{old_listen.rsplit(':',1)[0]}:{new}"
        with open(HYST_CONFIG, 'w') as f: json.dump(d, f, indent=2)
        subprocess.run(["systemctl","restart","hysteria"], capture_output=True,text=True,timeout=10)
        time.sleep(2); bput(f"{G}✅{NC} Port changed to {new} & restarted")
        bsep(); bot(); print(); time.sleep(2)
    except Exception as e:
        bput(f"{R}❌{NC} Error: {e}"); bsep(); bot(); print(); time.sleep(2)

def check_online():
    os.system("clear"); print(); box(); center(f"{M}👥{NC} {BD}Online Users{NC}"); bsep()
    bput(f"{D}  Scanning all services...{NC}")
    ssh = count_ssh(); db = count_dropbear(); ovpn = count_openvpn(); hy = count_hysteria()
    total = ssh + db + ovpn + hy
    bput(f"  {D}SSH:{NC} {WHT}{ssh}{NC}  {D}Dropbear:{NC} {WHT}{db}{NC}  {D}OpenVPN:{NC} {WHT}{ovpn}{NC}  {D}Hysteria:{NC} {WHT}{hy}{NC}")
    bput(f"  {WHT}Total Online: {total}{NC}")
    bsep()
    if hy > 0:
        bput(f"  {D}Hysteria Users:{NC}")
        hy_ips = get_hysteria_ips()
        for i, (ip, cnt) in enumerate(sorted(hy_ips.items(), key=lambda x: -x[1])[:10], 1):
            try: h = socket.gethostbyaddr(ip)[0][:30]
            except: h = "unknown"
            bput(f"  {G}{i:2}.{NC} {WHT}{ip}{NC}  {D}{h}{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def speed_test():
    os.system("clear"); print(); box(); center(f"{G}🌐{NC} {BD}Speed Test{NC}"); bsep()
    bput(f"{D}  Testing download speed...{NC}")
    try:
        r = subprocess.run("curl -s -o /dev/null -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=10000000",
                           shell=True, capture_output=True,text=True,timeout=30)
        mbps = float(r.stdout.strip().replace("'","")) * 8 / 1_000_000
        bput(f"  {WHT}{mbps:.1f} Mbps{NC} download")
    except: bput(f"  {R}Test failed{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

def web_dashboard():
    os.system("clear"); print(); box(); center(f"{C}🖥️{NC} {BD}Web Dashboard{NC}"); bsep()
    ip = get_ip()
    if is_web_running():
        bput(f"  {G}✅{NC} Web Dashboard {G}RUNNING{NC}")
        bput(f"  {D}Open: {WHT}http://{ip}:{WEB_PORT}{NC}")
        bput(f""); bput(f"  {Y}[1]{NC} Stop  {Y}[2]{NC} Restart  {Y}[0]{NC} Back")
        ch = input(f"  {Y}>>{NC} Choose: ").strip()
        if ch == "1":
            subprocess.run("pkill -f 'http.server 82'", shell=True, capture_output=True)
            time.sleep(1); bput(f"  {G}✅{NC} Stopped"); time.sleep(1.5)
        elif ch == "2":
            subprocess.run("pkill -f 'http.server 82'", shell=True, capture_output=True)
            time.sleep(1); Thread(target=start_web_server, daemon=True).start()
            time.sleep(2); bput(f"  {G}✅{NC} Restarted"); time.sleep(1.5)
    else:
        bput(f"  {R}❌{NC} Web Dashboard {R}STOPPED{NC}")
        bput(f""); bput(f"  {Y}[1]{NC} Start  {Y}[0]{NC} Back")
        ch = input(f"  {Y}>>{NC} Choose: ").strip()
        if ch == "1":
            Thread(target=start_web_server, daemon=True).start()
            time.sleep(2)
            if is_web_running(): bput(f"  {G}✅{NC} Started! Open: {WHT}http://{ip}:{WEB_PORT}{NC}")
            else: bput(f"  {R}❌{NC} Failed")
            time.sleep(2)
    bsep(); bot(); print()

def setup_swap():
    os.system("clear"); print(); box(); center(f"{M}💾{NC} {BD}Setup Swap{NC}"); bsep()
    si = get_sysinfo()
    ram_mb = 0
    try:
        r = subprocess.run("free -m | awk '/Mem:/{print $2}'", shell=True, capture_output=True,text=True,timeout=3)
        ram_mb = int(r.stdout.strip())
    except: pass
    if ram_mb <= 512: swap_mb = ram_mb * 2
    elif ram_mb <= 1024: swap_mb = ram_mb * 2
    elif ram_mb <= 2048: swap_mb = ram_mb
    elif ram_mb <= 4096: swap_mb = ram_mb
    else: swap_mb = 4096
    bput(f"  {D}RAM:{NC} {WHT}{ram_mb}MB{NC}  {D}Swap to create:{NC} {WHT}{swap_mb}MB{NC}")
    bput("")
    ch = input(f"  {Y}>>{NC} Create swap {swap_mb}MB? (Y/n): ").strip()
    if ch and ch.lower() != "y": bput(f"  {D}Cancelled{NC}"); bsep(); bot(); print(); return
    try:
        subprocess.run("swapoff -a 2>/dev/null", shell=True, capture_output=True,timeout=5)
        subprocess.run(f"fallocate -l {swap_mb}M {SWAP_FILE} 2>/dev/null || dd if=/dev/zero of={SWAP_FILE} bs=1M count={swap_mb}",
                      shell=True, capture_output=True,timeout=60)
        subprocess.run(f"chmod 600 {SWAP_FILE}", shell=True, capture_output=True,timeout=3)
        subprocess.run(f"mkswap {SWAP_FILE}", shell=True, capture_output=True,timeout=10)
        subprocess.run(f"swapon {SWAP_FILE}", shell=True, capture_output=True,timeout=10)
        if not os.path.exists("/etc/fstab.bak"):
            subprocess.run("cp /etc/fstab /etc/fstab.bak", shell=True, capture_output=True,timeout=3)
        subprocess.run(f"grep -q '{SWAP_FILE}' /etc/fstab || echo '{SWAP_FILE} none swap sw 0 0' >> /etc/fstab",
                      shell=True, capture_output=True,timeout=3)
        subprocess.run("sysctl vm.swappiness=10", shell=True, capture_output=True,timeout=3)
        bput(f"  {G}✅{NC} Swap created: {swap_mb}MB")
        bsep(); bot(); print()
    except Exception as e:
        bput(f"  {R}❌{NC} Error: {e}"); bsep(); bot(); print()

def debug_log():
    os.system("clear"); print(); box(); center(f"{M}🐛{NC} {BD}Debug Log{NC}"); bsep()
    log_file = "/var/log/showon-debug.log"
    if os.path.exists(log_file):
        r = subprocess.run(f"tail -n 30 {log_file}", shell=True, capture_output=True,text=True,timeout=5)
        for line in r.stdout.strip().split("\n")[:25]:
            bput(f"{D}{line[:54]}{NC}")
    else:
        bput(f"  {D}No debug log found{NC}")
    bsep(); bot(); print(); input(f"  {B}Press Enter{NC} ")

# ══ Main ══
if __name__ == "__main__":
    os.system("chmod 600 " + HYST_CONFIG + " 2>/dev/null")
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
            elif ch == "07": traffic_stats()
            elif ch == "08": debug_log()
            elif ch == "09": edit_auth()
            elif ch == "10": edit_obfs()
            elif ch == "11": change_port()
            elif ch == "12": check_online()
            elif ch == "13": speed_test()
            elif ch == "14": web_dashboard()
            elif ch == "15": setup_swap()
            elif ch == "00":
                os.system("clear"); print()
                box(); center(f"{G}👋{NC} {BD}Thank You - IDA UDPHysteria{NC}"); bot()
                print(); break
        except KeyboardInterrupt: break
        except Exception as e:
            print(f"  {R}Error: {e}{NC}"); time.sleep(2)
    os.system("clear"); print(); box(); center(f"{G}👋{NC} {BD}Thank You - IDA UDPHysteria{NC}"); bot(); print()
