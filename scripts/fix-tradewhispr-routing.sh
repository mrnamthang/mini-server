#!/bin/bash
# Fix TradeWhispr routing issue - deploy missing docker-compose.dev.yml

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔧 Fixing TradeWhispr Routing${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_HOST="192.168.1.10"
    ASUS_USER="thang"
    ASUS_SSH_ALIAS="asus-server"
    REMOTE_PROJECTS_DIR="/opt/projects"
fi

PROJECT="tradewhispr"
REMOTE_PROJECT_DIR="$REMOTE_PROJECTS_DIR/$PROJECT"
LOCAL_CONFIG_DIR="$REPO_ROOT/projects/$PROJECT"

# Step 1: Check /etc/hosts
echo -e "${YELLOW}1. Checking /etc/hosts...${NC}"
if grep -q "tradewhispr.local" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✓ tradewhispr.local already in /etc/hosts${NC}"
else
    echo -e "${YELLOW}Adding tradewhispr.local to /etc/hosts...${NC}"
    sudo sh -c "echo '$ASUS_HOST tradewhispr.local api.tradewhispr.local' >> /etc/hosts"
    echo -e "${GREEN}✓ Added to /etc/hosts${NC}"
fi
echo ""

# Step 2: Deploy docker-compose.dev.yml
echo -e "${YELLOW}2. Deploying docker-compose.dev.yml to Asus...${NC}"
if [ ! -f "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" ]; then
    echo -e "${RED}✗ docker-compose.dev.yml not found in $LOCAL_CONFIG_DIR${NC}"
    exit 1
fi

scp "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"
echo -e "${GREEN}✓ Deployed docker-compose.dev.yml${NC}"
echo ""

# Step 3: Update .env to use both compose files
echo -e "${YELLOW}3. Updating .env on Asus...${NC}"
ssh "$ASUS_SSH_ALIAS" << 'EOF'
    cd /opt/projects/tradewhispr

    # Add or update COMPOSE_FILE in .env
    if grep -q "^COMPOSE_FILE=" .env 2>/dev/null; then
        sed -i 's|^COMPOSE_FILE=.*|COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml|' .env
    else
        echo "COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml" >> .env
    fi

    # Add docker-compose.dev.yml to .gitignore if not already there
    grep -q "docker-compose.dev.yml" .gitignore 2>/dev/null || echo "docker-compose.dev.yml" >> .gitignore

    echo "✓ Updated .env"
EOF
echo -e "${GREEN}✓ Environment configured${NC}"
echo ""

# Step 4: Restart containers
echo -e "${YELLOW}4. Restarting containers with new configuration...${NC}"
ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose down && docker-compose up -d"
echo -e "${GREEN}✓ Containers restarted${NC}"
echo ""

# Step 5: Wait for services to be healthy
echo -e "${YELLOW}5. Waiting for services to start (15 seconds)...${NC}"
sleep 15
echo -e "${GREEN}✓ Services should be ready${NC}"
echo ""

# Step 6: Test connectivity
echo -e "${YELLOW}6. Testing connectivity...${NC}"
echo ""

# Test frontend
echo -e "${BLUE}Testing http://tradewhispr.local ...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://tradewhispr.local 2>/dev/null || echo "000")
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Frontend: HTTP 200 OK${NC}"
elif [ "$HTTP_CODE" == "404" ]; then
    echo -e "${RED}✗ Frontend: HTTP 404 - Still routing issue${NC}"
elif [ "$HTTP_CODE" == "502" ] || [ "$HTTP_CODE" == "503" ]; then
    echo -e "${YELLOW}⚠️  Frontend: HTTP $HTTP_CODE - Service starting up, wait a moment${NC}"
else
    echo -e "${RED}✗ Frontend: HTTP $HTTP_CODE${NC}"
fi

# Test backend
echo -e "${BLUE}Testing http://api.tradewhispr.local/health ...${NC}"
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://api.tradewhispr.local/health 2>/dev/null || echo "000")
if [ "$API_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Backend: HTTP 200 OK${NC}"
elif [ "$API_CODE" == "404" ]; then
    echo -e "${YELLOW}⚠️  Backend: HTTP 404 - Check if /health endpoint exists${NC}"
elif [ "$API_CODE" == "502" ] || [ "$API_CODE" == "503" ]; then
    echo -e "${YELLOW}⚠️  Backend: HTTP $API_CODE - Service starting up, wait a moment${NC}"
else
    echo -e "${RED}✗ Backend: HTTP $API_CODE${NC}"
fi
echo ""

# Final message
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Fix script completed!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}🌐 Try accessing:${NC}"
echo -e "  ${GREEN}http://tradewhispr.local${NC}"
echo -e "  ${GREEN}http://api.tradewhispr.local/health${NC}"
echo ""
echo -e "${CYAN}📊 View logs:${NC}"
echo -e "  ${YELLOW}ssh asus-server 'cd /opt/projects/tradewhispr && docker-compose logs -f'${NC}"
echo ""
echo -e "${CYAN}🔍 View Traefik dashboard:${NC}"
echo -e "  ${YELLOW}http://$ASUS_HOST:8080${NC}"
echo ""
echo -e "${CYAN}🐛 If still 404, run troubleshoot:${NC}"
echo -e "  ${YELLOW}./scripts/troubleshoot-404.sh tradewhispr${NC}"
echo ""
