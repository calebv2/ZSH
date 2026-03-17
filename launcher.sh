#!/usr/bin/env bash
# =============================================================================
# ZSH + PM2Logs — Proxmox LXC Launcher
# Run on the Proxmox VE node as root
# Lets you pick one or more running LXC containers to install into
# =============================================================================
set -e

INSTALLER_URL="https://raw.githubusercontent.com/calebv2/ZSH/main/install-zsh-pm2logs.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Verify we're on a Proxmox node
if ! command -v pct &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} 'pct' not found. This script must be run on a Proxmox VE node."
    exit 1
fi

# Verify whiptail is available
if ! command -v whiptail &>/dev/null; then
    echo -e "${YELLOW}[INFO]${NC}  Installing whiptail..."
    apt-get install -y -q whiptail
fi

echo -e "\n${CYAN}=== ZSH + PM2Logs | Proxmox LXC Installer ===${NC}\n"

# Build container list from running LXCs only
CT_ITEMS=()
while IFS= read -r line; do
    CTID=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $2}')
    NAME=$(echo "$line" | awk '{print $3}')
    [[ "$STATUS" == "running" ]] && CT_ITEMS+=("$CTID" "$NAME ($CTID)" "OFF")
done < <(pct list | tail -n +2)

if [[ ${#CT_ITEMS[@]} -eq 0 ]]; then
    echo -e "${RED}[ERROR]${NC} No running LXC containers found."
    exit 1
fi

# Show checklist
CHOICES=$(whiptail \
    --title "ZSH + PM2Logs Installer" \
    --checklist "\nSelect containers to install into:\n(SPACE to select, ENTER to confirm)" \
    20 60 10 \
    "${CT_ITEMS[@]}" \
    3>&1 1>&2 2>&3) || { echo -e "\n${YELLOW}Cancelled.${NC}"; exit 0; }

# Strip quotes from whiptail output
SELECTED=$(echo "$CHOICES" | tr -d '"')

if [[ -z "$SELECTED" ]]; then
    echo -e "${YELLOW}No containers selected. Exiting.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Installing to:${NC} $SELECTED"
echo ""

# Install into each selected container
for CTID in $SELECTED; do
    CT_NAME=$(pct list | awk -v id="$CTID" '$1==id {print $3}')
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Container: ${NC}$CT_NAME (CT $CTID)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check container is still running
    STATUS=$(pct status "$CTID" | awk '{print $2}')
    if [[ "$STATUS" != "running" ]]; then
        echo -e "${RED}  Skipping — CT $CTID is not running.${NC}"
        continue
    fi

    # Run installer inside the container
    if pct exec "$CTID" -- bash -c "curl -fsSL $INSTALLER_URL | bash"; then
        echo -e "${GREEN}  CT $CTID — done.${NC}"
    else
        echo -e "${RED}  CT $CTID — install failed. Check output above.${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  All selected containers processed.${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${YELLOW}  Reminder: open a new shell in each container (exec zsh)${NC}"
echo -e "${YELLOW}  and make sure your terminal uses a Nerd Font for glyphs.${NC}"
