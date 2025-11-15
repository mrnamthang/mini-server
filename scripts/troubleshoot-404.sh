#!/bin/bash
# Troubleshoot 404 errors for local domains

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT=${1:-"tradewhispr"}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔍 Troubleshooting 404 for $PROJECT.local${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_HOST="192.168.1.10"
    ASUS_SSH_ALIAS="asus-server"
fi

# 1. Check /etc/hosts on Mac
echo -e "${YELLOW}1. Checking /etc/hosts on Mac...${NC}"
if grep -q "$PROJECT.local" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✓ $PROJECT.local is in /etc/hosts${NC}"
    grep "$PROJECT.local" /etc/hosts
else
    echo -e "${RED}✗ $PROJECT.local NOT in /etc/hosts${NC}"
    echo -e "${BLUE}ℹ️  Add this line to /etc/hosts:${NC}"
    echo -e "   sudo sh -c 'echo \"$ASUS_HOST $PROJECT.local api.$PROJECT.local\" >> /etc/hosts'"
fi
echo ""

# 2. Check if Asus is reachable
echo -e "${YELLOW}2. Checking Asus server connectivity...${NC}"
if ping -c 1 -W 2 "$ASUS_HOST" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Asus server is reachable${NC}"
else
    echo -e "${RED}✗ Cannot reach Asus server${NC}"
    exit 1
fi
echo ""

# 3. Check if Traefik is running
echo -e "${YELLOW}3. Checking Traefik status...${NC}"
TRAEFIK_STATUS=$(ssh "$ASUS_SSH_ALIAS" "docker ps --filter name=traefik --format '{{.Status}}' 2>/dev/null" || echo "Not running")
if [[ "$TRAEFIK_STATUS" == *"Up"* ]]; then
    echo -e "${GREEN}✓ Traefik is running${NC}"
    echo "   Status: $TRAEFIK_STATUS"
else
    echo -e "${RED}✗ Traefik is not running${NC}"
    echo -e "${BLUE}ℹ️  Start Traefik:${NC}"
    echo "   ssh $ASUS_SSH_ALIAS 'cd /opt/traefik && docker-compose up -d'"
    exit 1
fi
echo ""

# 4. Check if project containers are running
echo -e "${YELLOW}4. Checking $PROJECT containers...${NC}"
PROJECT_CONTAINERS=$(ssh "$ASUS_SSH_ALIAS" "docker ps --filter name=$PROJECT --format '{{.Names}}' 2>/dev/null" || echo "")
if [ -n "$PROJECT_CONTAINERS" ]; then
    echo -e "${GREEN}✓ $PROJECT containers running:${NC}"
    echo "$PROJECT_CONTAINERS" | sed 's/^/   /'
else
    echo -e "${RED}✗ No $PROJECT containers running${NC}"
    echo -e "${BLUE}ℹ️  Start services:${NC}"
    echo "   ssh $ASUS_SSH_ALIAS 'cd /opt/projects/$PROJECT && docker-compose up -d'"
    exit 1
fi
echo ""

# 5. Check Traefik network
echo -e "${YELLOW}5. Checking Traefik network connections...${NC}"
NETWORK_CHECK=$(ssh "$ASUS_SSH_ALIAS" "docker network inspect traefik-public -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null" || echo "")
if [[ "$NETWORK_CHECK" == *"$PROJECT"* ]]; then
    echo -e "${GREEN}✓ $PROJECT containers connected to traefik-public${NC}"
else
    echo -e "${RED}✗ $PROJECT containers NOT on traefik-public network${NC}"
    echo -e "${BLUE}ℹ️  Containers need to join traefik-public network${NC}"
fi
echo ""

# 6. Check Traefik routes
echo -e "${YELLOW}6. Checking Traefik routes...${NC}"
echo -e "${BLUE}ℹ️  Fetching routes from Traefik API...${NC}"
ROUTES=$(curl -s http://$ASUS_HOST:8080/api/http/routers 2>/dev/null | grep -o "\"rule\":\"Host(\`[^)]*" | sed 's/"rule":"Host(`//' || echo "")
if [[ "$ROUTES" == *"$PROJECT"* ]]; then
    echo -e "${GREEN}✓ Traefik has routes for $PROJECT${NC}"
    echo "$ROUTES" | grep "$PROJECT" | sed 's/^/   /'
else
    echo -e "${RED}✗ No routes found for $PROJECT in Traefik${NC}"
    echo -e "${BLUE}ℹ️  Check Traefik labels in docker-compose.yml${NC}"
fi
echo ""

# 7. Test actual HTTP request
echo -e "${YELLOW}7. Testing HTTP request...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PROJECT.local 2>/dev/null || echo "000")
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ HTTP 200 OK - Service is working!${NC}"
elif [ "$HTTP_CODE" == "404" ]; then
    echo -e "${RED}✗ HTTP 404 - Traefik responds but can't route to service${NC}"
    echo -e "${BLUE}ℹ️  Possible causes:${NC}"
    echo "   1. Service container not connected to traefik-public network"
    echo "   2. Traefik labels missing or incorrect in docker-compose.yml"
    echo "   3. Service not listening on expected port"
elif [ "$HTTP_CODE" == "502" ] || [ "$HTTP_CODE" == "503" ]; then
    echo -e "${YELLOW}⚠️  HTTP $HTTP_CODE - Service unavailable (starting up?)${NC}"
    echo -e "${BLUE}ℹ️  Wait a few seconds and try again${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_CODE - Unexpected response${NC}"
fi
echo ""

# 8. Show container logs
echo -e "${YELLOW}8. Recent container logs:${NC}"
echo -e "${BLUE}ℹ️  Showing last 10 lines from each container...${NC}"
ssh "$ASUS_SSH_ALIAS" "cd /opt/projects/$PROJECT && docker-compose logs --tail=10" 2>&1 | head -50
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📋 Quick Fixes:${NC}"
echo ""
echo "If /etc/hosts missing:"
echo "  sudo sh -c 'echo \"$ASUS_HOST $PROJECT.local api.$PROJECT.local\" >> /etc/hosts'"
echo ""
echo "If containers not running:"
echo "  ssh $ASUS_SSH_ALIAS 'cd /opt/projects/$PROJECT && docker-compose up -d'"
echo ""
echo "View Traefik dashboard:"
echo "  open http://$ASUS_HOST:8080"
echo ""
echo "View full logs:"
echo "  ssh $ASUS_SSH_ALIAS 'cd /opt/projects/$PROJECT && docker-compose logs -f'"
echo ""
