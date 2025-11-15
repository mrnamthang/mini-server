#!/bin/bash
# Rebuild and restart service on Asus server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT=$1
SERVICE=$2

if [ -z "$PROJECT" ] || [ -z "$SERVICE" ]; then
    echo -e "${RED}Error: Project and service name required${NC}"
    echo "Usage: ./rebuild-on-asus.sh [flow|tradewhispr] [service-name]"
    echo ""
    echo "Examples:"
    echo "  ./rebuild-on-asus.sh flow flow-api"
    echo "  ./rebuild-on-asus.sh flow flow-web"
    echo "  ./rebuild-on-asus.sh tradewhispr tradewhispr-backend"
    echo "  ./rebuild-on-asus.sh tradewhispr tradewhispr-frontend"
    exit 1
fi

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_SSH_ALIAS="asus-server"
    REMOTE_PROJECTS_DIR="/opt/projects"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🔨 Rebuilding $SERVICE on Asus server...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Build the service
echo -e "${YELLOW}📦 Building Docker image...${NC}"
ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose build $SERVICE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build complete${NC}"
echo ""

# Restart the service
echo -e "${YELLOW}🔄 Restarting service...${NC}"
ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose up -d $SERVICE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Restart failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Service restarted${NC}"
echo ""

# Wait a moment for service to start
sleep 3

# Show service status
echo -e "${BLUE}📊 Service status:${NC}"
ssh "$ASUS_SSH_ALIAS" "docker ps --filter name=$SERVICE --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ $SERVICE is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  • View logs: ./scripts/logs.sh $PROJECT $SERVICE"
echo "  • Access app: http://$PROJECT.local"
echo "  • Check Traefik: http://traefik.local"
