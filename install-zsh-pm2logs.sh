#!/usr/bin/env bash
# =============================================================================
# ZSH + PM2Logs Environment Installer
# Target: Ubuntu/Debian LXC (tested on Ubuntu 24.04 Noble)
# Installs: zsh, Oh My Zsh, Powerlevel10k, plugins, p10k config, ccze, Node.js, PM2, pm2logs
# Run as: root
# =============================================================================
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
die()     { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

TARGET_HOME="${HOME}"
TARGET_USER="${USER}"
OMZ_DIR="${TARGET_HOME}/.oh-my-zsh"

echo -e "\n${CYAN}=== ZSH + PM2Logs Installer | User: ${TARGET_USER} | Home: ${TARGET_HOME} ===${NC}\n"

# =============================================================================
# 1. Packages
# =============================================================================
info "Installing packages..."
apt-get update -q
apt-get install -y -q zsh git curl wget ccze
success "Packages installed (zsh, git, curl, wget, ccze)"

# =============================================================================
# 2. Oh My Zsh
# =============================================================================
if [[ -d "$OMZ_DIR" ]]; then
    warn "Oh My Zsh already present at $OMZ_DIR — skipping"
else
    info "Installing Oh My Zsh..."
    ZSH="$OMZ_DIR" RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh installed at $OMZ_DIR"
fi

# =============================================================================
# 3. Powerlevel10k
# =============================================================================
P10K_DIR="${OMZ_DIR}/custom/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
    warn "Powerlevel10k present — updating..."; git -C "$P10K_DIR" pull --quiet
else
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    success "Powerlevel10k installed"
fi

# =============================================================================
# 4. Plugins
# =============================================================================
CUSTOM_PLUGINS="${OMZ_DIR}/custom/plugins"
mkdir -p "$CUSTOM_PLUGINS"

ZSH_AUTO="${CUSTOM_PLUGINS}/zsh-autosuggestions"
if [[ -d "$ZSH_AUTO" ]]; then
    warn "zsh-autosuggestions present — updating..."; git -C "$ZSH_AUTO" pull --quiet
else
    info "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTO"
    success "zsh-autosuggestions installed"
fi

ZSH_SYNTAX="${CUSTOM_PLUGINS}/zsh-syntax-highlighting"
if [[ -d "$ZSH_SYNTAX" ]]; then
    warn "zsh-syntax-highlighting present — updating..."; git -C "$ZSH_SYNTAX" pull --quiet
else
    info "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_SYNTAX"
    success "zsh-syntax-highlighting installed"
fi

# =============================================================================
# 5. .zshrc
# =============================================================================
info "Writing .zshrc..."
cat > "${TARGET_HOME}/.zshrc" << ZSHRC_EOF
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

export ZSH="\$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source \$ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC_EOF
success ".zshrc written"

# =============================================================================
# =============================================================================
# 6. .p10k.zsh — fetched directly from GitHub
# =============================================================================
info "Downloading .p10k.zsh..."
P10K_URL="https://raw.githubusercontent.com/calebv2/ZSH/main/p10k.zsh"
if curl -fsSL "$P10K_URL" -o "${TARGET_HOME}/.p10k.zsh"; then
    success ".p10k.zsh downloaded"
else
    warn "Could not download .p10k.zsh — run 'p10k configure' to set up your prompt"
fi


# =============================================================================
# 7. pm2logs script
# =============================================================================
info "Installing pm2logs..."
cat > /usr/local/bin/pm2logs << 'PM2LOGS_EOF'
#!/usr/bin/env python3
import sys, re, json, subprocess

COLORS=["\033[1;32m","\033[1;34m","\033[1;33m","\033[1;36m","\033[1;35m","\033[1;31m","\033[1;37m","\033[1;38;5;208m"]
RESET="\033[0m";DIM="\033[0;90m";RED="\033[1;31m";YELLOW="\033[1;33m";CYAN="\033[1;36m";GREEN="\033[1;32m"

SKIP_RE=re.compile(r'^(/root/\.pm2/|\[TAILING\]|PM2\s+\|)')
LIVE_RE=re.compile(r'^(?:\S+\s+)?(\d+)\|(\S+)\s*\|\s*(.*)')
HIST_RE=re.compile(r'^\[(\S+)\]\s*(.*)')
IP_RE=re.compile(r'(\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?)')
TB_RE=re.compile(r'^(Traceback|  File "|TypeError:|ValueError:|KeyError:|AttributeError:|Exception:|RuntimeError:)')

def get_processes():
    try:
        raw=subprocess.check_output(["pm2","jlist"],stderr=subprocess.DEVNULL)
        return [(p["name"],str(p["pm_id"])) for p in json.loads(raw)]
    except: return []

def clean_msg(msg):
    msg=re.sub(r'^\s*\[\d+\]\s*','',msg)
    msg=re.sub(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[.,]?\d*\s*-?\s*','',msg)
    msg=re.sub(r'^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}[.,]?\d*\s*-?\s*','',msg)
    return msg.strip()

def get_msg_color(msg):
    if re.search(r'[🛑❌💥🔴]',msg): return RED
    if re.search(r'[✅🟢💚]',msg): return GREEN
    if re.search(r'[⚠️🟡]',msg): return YELLOW
    if re.search(r'(CRITICAL|critical|FATAL|fatal)',msg): return "\033[1;41m"
    if re.search(r'(ERROR|Error|error)',msg): return RED
    if re.search(r'(WARNING|Warning|warning|WARN|warn)',msg): return YELLOW
    if re.search(r'(DEBUG|Debug|debug)',msg): return DIM
    if re.search(r'(INFO|Info|info)',msg): return "\033[0;37m"
    return "\033[0;37m"

def colorize_http(msg,bc):
    return re.sub(r'\b([2345]\d{2})\b',lambda m:f"{GREEN if int(m.group(1))<300 else CYAN if int(m.group(1))<400 else YELLOW if int(m.group(1))<500 else RED}{m.group(1)}{bc}",msg)

def colorize_keywords(msg,bc):
    kw={
        r'\b(COMPLETED|Completed|completed|SUCCESS|Success|success|online|OK)\b':GREEN,
        r'\b(STARTING|Starting|starting|Restarting|restarting)\b':CYAN,
        r'\b(STOPPING|Stopping|stopping|offline|exited|Exited)\b':YELLOW,
        r'\b(BLOCKING|Blocking|blocking|BLOCKED|REJECTED|rejected)\b':RED,
        r'\b(Sleeping|sleeping|waiting|Waiting|idle|Idle)\b':DIM,
    }
    for pat,col in kw.items():
        msg=re.sub(pat,lambda m,c=col:f"{c}{m.group(0)}{bc}",msg)
    return msg

def format_line(pname,msg,name_color):
    mc=get_msg_color(msg)
    BOLD_WHITE="\033[1;37m"
    LIGHT_BLUE="\033[0;94m"
    ts_bracket=""
    ts_m=re.match(r'^(\[\d{4}-\d{2}-\d{2}[^\]]+\])\s*(.*)',msg)
    if ts_m:
        ts_bracket=ts_m.group(1)
        msg=ts_m.group(2)
    level=""
    level_m=re.match(r'^((INFO|WARNING|WARN|ERROR|DEBUG|CRITICAL)\S*)\s*(.*)',msg)
    if level_m:
        level=level_m.group(1)
        msg=level_m.group(3)
    msg=IP_RE.sub(DIM+r'\1'+mc,msg)
    msg=colorize_keywords(msg,mc)
    parts=f"{name_color}[{pname}]{RESET}"
    if ts_bracket:
        parts+=f" {LIGHT_BLUE}{ts_bracket}{RESET}"
    if level:
        parts+=f" {mc}{level}{RESET}"
    parts+=f" {BOLD_WHITE}{msg}{RESET}\n"
    return parts

def colorize_stream(stream,color_map,errors_only=False):
    in_tb=False; tb_nc=RESET; seen=[]
    for raw in stream:
        line=raw if isinstance(raw,str) else raw.decode("utf-8",errors="replace")
        if SKIP_RE.match(line): continue
        m=LIVE_RE.match(line); h=HIST_RE.match(line) if not m else None
        if m:
            _,pname,msg=m.group(1),m.group(2),m.group(3)
            nc=RESET
            for fn,c in color_map.items():
                if fn.startswith(pname.rstrip(".")): nc=c; pname=fn; break
            msg=clean_msg(msg)
            if not msg: continue
            if msg in seen[-10:]: continue
            seen.append(msg)
            if errors_only and not re.search(r'(ERROR|error|WARNING|warning|WARN|CRITICAL|critical|🛑|❌)',msg): continue
            if TB_RE.match(msg): in_tb=True; tb_nc=nc; sys.stdout.write(f"{nc}[{pname}]{RESET} {RED}{msg}{RESET}\n")
            elif in_tb:
                if msg: sys.stdout.write(f"{tb_nc}[{pname}]{RESET} {RED}{msg}{RESET}\n")
                else: in_tb=False
            else: sys.stdout.write(format_line(pname,msg,nc))
        elif h:
            pname,msg=h.group(1),h.group(2)
            nc=RESET
            for fn,c in color_map.items():
                if fn==pname or fn.startswith(pname.rstrip(".")): nc=c; pname=fn; break
            msg=clean_msg(msg)
            if not msg: continue
            if msg in seen[-10:]: continue
            seen.append(msg)
            if errors_only and not re.search(r'(ERROR|error|WARNING|warning|WARN|CRITICAL|critical|🛑|❌)',msg): continue
            if TB_RE.match(msg): in_tb=True; tb_nc=nc; sys.stdout.write(f"{nc}[{pname}]{RESET} {RED}{msg}{RESET}\n")
            elif in_tb:
                if msg: sys.stdout.write(f"{tb_nc}[{pname}]{RESET} {RED}{msg}{RESET}\n")
                else: in_tb=False
            else: sys.stdout.write(format_line(pname,msg,nc))
        else:
            if not line.strip(): in_tb=False; continue
            mc=get_msg_color(line)
            sys.stdout.write(f"{mc}{line.rstrip()}{RESET}\n")
        sys.stdout.flush()

def print_header(procs,color_map,target,target_display,lines):
    print(f"\n{RESET}╔══════════════════════════════════════════════════")
    print(f"║          {COLORS[0]}PM2 Colored Log Stream{RESET}")
    print(f"╠══════════════════════════════════════════════════")
    for name,pid in procs:
        color=color_map.get(name,RESET); label=f"{name} [{pid}]"
        active=(not target) or (name==target) or (pid==target)
        print(f"║  {color}● {label}{RESET}" if active else f"║    {label}{RESET}")
    filter_msg=f"Filter: {target_display}" if target else "Showing: ALL"
    lines_label=f"History: {lines} lines" if lines>0 else "Live only"
    print(f"╠══════════════════════════════════════════════════")
    print(f"║  {filter_msg}")
    print(f"║  {lines_label} │ Ctrl+C to stop")
    print(f"╠══════════════════════════════════════════════════")
    print(f"║  {DIM}pm2logs <id>            filter by process id{RESET}")
    print(f"║  {DIM}pm2logs <name>          filter by process name{RESET}")
    print(f"║  {DIM}pm2logs <id> <lines>    show last N lines{RESET}")
    print(f"║  {DIM}pm2logs --errors        errors & warnings only{RESET}")
    print(f"╚══════════════════════════════════════════════════\n")

def main():
    raw_args=sys.argv[1:]; target=""; lines=0; errors_only=False; positional=[]
    for arg in raw_args:
        if arg=="--errors": errors_only=True
        else: positional.append(arg)
    if len(positional)>=1: target=positional[0]
    if len(positional)>=2:
        try: lines=int(positional[1])
        except: pass
    procs=get_processes()
    if not procs: print("No PM2 processes running."); sys.exit(1)
    color_map={name:COLORS[i%len(COLORS)] for i,(name,_) in enumerate(procs)}
    target_display=""
    if target:
        if target.isdigit():
            for name,pid in procs:
                if pid==target: target_display=f"{name} (id:{target})"; break
            if not target_display:
                print(f"{RED}Error: No PM2 process with ID {target}{RESET}")
                [print(f"  [{pid}] {name}") for name,pid in procs]; sys.exit(1)
        else: target_display=target
    print_header(procs,color_map,target,target_display,lines)
    cmd=["pm2","logs",target,"--timestamp","--lines",str(lines)] if target else ["pm2","logs","--timestamp","--lines",str(lines)]
    try:
        pm2_proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        ccze_proc=subprocess.Popen(["ccze","-A"],stdin=pm2_proc.stdout,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
        pm2_proc.stdout.close()
        for line in iter(ccze_proc.stdout.readline,b""):
            decoded=line.decode("utf-8",errors="replace")
            if errors_only and not re.search(r'(ERROR|error|WARNING|warning|WARN|CRITICAL|critical)',decoded): continue
            sys.stdout.write(decoded)
            sys.stdout.flush()
    except KeyboardInterrupt: print(f"\n{DIM}Stream stopped.{RESET}")
    finally:
        try: pm2_proc.terminate()
        except: pass
        try: ccze_proc.terminate()
        except: pass

if __name__=="__main__": main()
PM2LOGS_EOF
chmod +x /usr/local/bin/pm2logs
success "pm2logs installed at /usr/local/bin/pm2logs"

# =============================================================================
# 8. Set zsh as default shell
# =============================================================================
ZSH_BIN=$(which zsh)
info "Setting zsh as default shell..."
chsh -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null || \
    sed -i "s|^\(${TARGET_USER}:.*\):[^:]*$|\1:${ZSH_BIN}|" /etc/passwd 2>/dev/null || \
    warn "Could not set default shell — run: chsh -s $ZSH_BIN"
success "Default shell set to zsh"

# =============================================================================
# 9. Node.js + PM2
# =============================================================================
if command -v pm2 &>/dev/null; then
    warn "PM2 already installed ($(pm2 --version)) — skipping"
else
    info "Installing Node.js (LTS) + PM2..."
    # Use NodeSource LTS setup script
    if ! command -v node &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &>/dev/null
        apt-get install -y -q nodejs
        success "Node.js $(node -v) installed"
    else
        warn "Node.js already present ($(node -v)) — skipping Node install"
    fi
    npm install -g pm2 --quiet
    pm2 startup systemd -u root --hp /root &>/dev/null || true
    success "PM2 $(pm2 --version) installed and startup configured"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  All done!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo "  Installed:"
echo "    ✓ zsh + Oh My Zsh"
echo "    ✓ Powerlevel10k + zsh-autosuggestions + zsh-syntax-highlighting"
echo "    ✓ .zshrc + .p10k.zsh"
echo "    ✓ ccze"
echo "    ✓ Node.js + PM2"
echo "    ✓ pm2logs → /usr/local/bin/pm2logs"
echo ""
echo "  Next step:  exec zsh"
echo ""
echo -e "${YELLOW}  Note: terminal needs a Nerd Font for Powerlevel10k glyphs.${NC}"
