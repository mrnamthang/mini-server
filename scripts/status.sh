#!/bin/bash
# Quick status dashboard for Mac ↔ Asus workflow

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_SSH_ALIAS="asus-server"
    ASUS_HOST="192.168.1.10"
fi

# Clear screen
clear

# Banner
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Mac ↔ Asus Mini Server - Development Status${NC}                   ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check connectivity
echo -e "${YELLOW}🔌 Connectivity${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ping -c 1 -W 2 "$ASUS_HOST" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Asus server reachable: $ASUS_HOST"
else
    echo -e "  ${RED}✗${NC} Asus server unreachable: $ASUS_HOST"
    echo ""
    exit 1
fi

if ssh -q -o BatchMode=yes -o ConnectTimeout=3 "$ASUS_SSH_ALIAS" exit 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SSH connection working"
else
    echo -e "  ${RED}✗${NC} SSH connection failed"
    echo ""
    exit 1
fi

echo ""

# Asus Server Resources
echo -e "${YELLOW}💻 Asus Server Resources${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

ssh "$ASUS_SSH_ALIAS" "
# Memory
MEM_INFO=\$(free -h | grep Mem)
MEM_USED=\$(echo \$MEM_INFO | awk '{print \$3}')
MEM_TOTAL=\$(echo \$MEM_INFO | awk '{print \$2}')
MEM_PERCENT=\$(free | grep Mem | awk '{print int(\$3/\$2 * 100)}')

echo -e \"  Memory: \$MEM_USED / \$MEM_TOTAL (\$MEM_PERCENT%)\"

# CPU Load
CPU_LOAD=\$(uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}')
echo -e \"  CPU Load: \$CPU_LOAD\"

# Disk
DISK_INFO=\$(df -h / | tail -1)
DISK_USED=\$(echo \$DISK_INFO | awk '{print \$3}')
DISK_TOTAL=\$(echo \$DISK_INFO | awk '{print \$2}')
DISK_PERCENT=\$(echo \$DISK_INFO | awk '{print \$5}')
echo -e \"  Disk: \$DISK_USED / \$DISK_TOTAL (\$DISK_PERCENT)\"
" | sed 's/^/  /'

echo ""

# Docker Services
echo -e "${YELLOW}🐳 Docker Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check Traefik
TRAEFIK_STATUS=$(ssh "$ASUS_SSH_ALIAS" "docker ps --filter name=traefik --format '{{.Status}}' 2>/dev/null" || echo "Not running")
if [[ "$TRAEFIK_STATUS" == *"Up"* ]]; then
    echo -e "  ${GREEN}✓${NC} Traefik: ${GREEN}Running${NC} - http://$ASUS_HOST:8080"
else
    echo -e "  ${RED}✗${NC} Traefik: ${RED}Not running${NC}"
fi

# Check projects
PROJECTS=("flow" "tradewhispr" "client-a" "client-b" "client-c" "client-d")

for project in "${PROJECTS[@]}"; do
    CONTAINERS=$(ssh "$ASUS_SSH_ALIAS" "docker ps --filter name=$project --format '{{.Names}}' 2>/dev/null" || echo "")

    if [ -n "$CONTAINERS" ]; then
        COUNT=$(echo "$CONTAINERS" | wc -l | xargs)
        echo -e "  ${GREEN}✓${NC} $project: ${GREEN}$COUNT container(s) running${NC} - http://$project.local"
    else
        echo -e "  ${BLUE}○${NC} $project: ${BLUE}Stopped${NC}"
    fi
done

echo ""

# Container Resource Usage (top 5)
echo -e "${YELLOW}📊 Top 5 Containers by Resource Usage${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

ssh "$ASUS_SSH_ALIAS" "
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | head -6
" | sed 's/^/  /' || echo "  No containers running"

echo ""

# Quick Actions
echo -e "${YELLOW}⚡ Quick Commands${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Start dev mode:    ./scripts/dev.sh <project>"
echo "  View logs:         ./scripts/dev.sh <project> logs-only"
echo "  Rebuild:           ./scripts/rebuild-on-asus.sh <project> <service>"
echo "  Manage projects:   ./scripts/projects.sh status|start|stop|restart"
echo "  Open Traefik:      open http://$ASUS_HOST:8080"
echo ""

echo -e "${GREEN}✅ Ready for development!${NC}"
echo ""
