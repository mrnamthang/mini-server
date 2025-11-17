#!/bin/bash
# Debug TradeWhispr deployment issues

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🔍 TradeWhispr Debug Report${NC}"
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
fi

PROJECT="tradewhispr"
REMOTE_PROJECT_DIR="/opt/projects/$PROJECT"

# =============================================================================
# 1. Check Container Status
# =============================================================================
echo -e "${YELLOW}1. Checking container status...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== All TradeWhispr Containers ==="
docker ps -a --filter "name=tradewhispr" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
EOF
echo ""

# =============================================================================
# 2. Check which compose files are being used
# =============================================================================
echo -e "${YELLOW}2. Checking docker-compose configuration...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Files in project directory ==="
ls -lah | grep -E "(docker-compose|\.env)"
echo ""
echo "=== COMPOSE_FILE setting in .env ==="
grep "COMPOSE_FILE" .env 2>/dev/null || echo "COMPOSE_FILE not set in .env"
echo ""
echo "=== Checking docker-compose.dev.yml existence ==="
if [ -f "docker-compose.dev.yml" ]; then
    echo "✓ docker-compose.dev.yml exists"
else
    echo "✗ docker-compose.dev.yml is MISSING"
fi
echo ""
EOF
echo ""

# =============================================================================
# 3. Check Frontend Container Logs
# =============================================================================
echo -e "${YELLOW}3. Checking frontend container logs (last 30 lines)...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Frontend Container Logs ==="
docker logs tradewhispr-frontend --tail 30 2>&1 || echo "Frontend container not found or not running"
echo ""
EOF
echo ""

# =============================================================================
# 4. Check Backend Container Logs
# =============================================================================
echo -e "${YELLOW}4. Checking backend container logs (last 30 lines)...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Backend Container Logs ==="
docker logs tradewhispr-backend --tail 30 2>&1 || echo "Backend container not found or not running"
echo ""
EOF
echo ""

# =============================================================================
# 5. Check Network Connections
# =============================================================================
echo -e "${YELLOW}5. Checking network connections...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
echo "=== Containers on traefik-public network ==="
docker network inspect traefik-public -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep tradewhispr || echo "No tradewhispr containers on traefik-public"
echo ""
echo "=== All networks for tradewhispr-frontend ==="
docker inspect tradewhispr-frontend -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "Container not found"
echo ""
echo "=== All networks for tradewhispr-backend ==="
docker inspect tradewhispr-backend -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "Container not found"
echo ""
EOF
echo ""

# =============================================================================
# 6. Check Traefik Routes
# =============================================================================
echo -e "${YELLOW}6. Checking Traefik routes...${NC}"
echo ""
ROUTES=$(curl -s http://$ASUS_HOST:8080/api/http/routers 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -A5 tradewhispr || echo "Could not fetch Traefik routes")
if [[ "$ROUTES" == *"tradewhispr"* ]]; then
    echo -e "${GREEN}✓ Traefik has routes for tradewhispr${NC}"
    echo "$ROUTES"
else
    echo -e "${RED}✗ No tradewhispr routes found in Traefik${NC}"
fi
echo ""

# =============================================================================
# 7. Test Docker Compose Config
# =============================================================================
echo -e "${YELLOW}7. Validating docker-compose configuration...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Testing docker-compose config ==="
docker-compose config 2>&1 | head -50
EOF
echo ""

# =============================================================================
# 8. Check if frontend build exists
# =============================================================================
echo -e "${YELLOW}8. Checking if frontend is built...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Frontend directory structure ==="
ls -la frontend/ 2>/dev/null | head -20 || echo "Frontend directory not found"
echo ""
echo "=== Frontend Dockerfile ==="
if [ -f "frontend/Dockerfile" ]; then
    echo "✓ Dockerfile exists"
    cat frontend/Dockerfile
else
    echo "✗ Dockerfile is MISSING"
fi
echo ""
EOF
echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Common Issues & Fixes:${NC}"
echo ""
echo -e "${YELLOW}Issue: Frontend container not running${NC}"
echo "  Fix: Check frontend/Dockerfile and rebuild"
echo "  $ ssh asus-server 'cd /opt/projects/tradewhispr && docker-compose up -d --build tradewhispr-frontend'"
echo ""
echo -e "${YELLOW}Issue: Container can't build${NC}"
echo "  Fix: Check frontend/Dockerfile exists and build context is correct"
echo "  $ ssh asus-server 'cd /opt/projects/tradewhispr && docker-compose build tradewhispr-frontend'"
echo ""
echo -e "${YELLOW}Issue: docker-compose.dev.yml not loaded${NC}"
echo "  Fix: Ensure COMPOSE_FILE is set in .env"
echo "  $ ssh asus-server 'cd /opt/projects/tradewhispr && echo \"COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml\" >> .env'"
echo ""
echo -e "${YELLOW}Issue: Container not on traefik-public network${NC}"
echo "  Fix: Restart containers to connect to network"
echo "  $ ssh asus-server 'cd /opt/projects/tradewhispr && docker-compose down && docker-compose up -d'"
echo ""
echo -e "${YELLOW}Issue: Port conflict or build errors${NC}"
echo "  Fix: View detailed logs"
echo "  $ ssh asus-server 'cd /opt/projects/tradewhispr && docker-compose logs -f'"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
