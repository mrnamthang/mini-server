#!/bin/bash
# View logs from Asus server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT=$1
SERVICE=$2

if [ -z "$PROJECT" ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo "Usage: ./logs.sh [flow|tradewhispr] [service-name]"
    echo ""
    echo "Examples:"
    echo "  ./logs.sh flow                    # All Flow services"
    echo "  ./logs.sh flow flow-api           # Just Flow API"
    echo "  ./logs.sh tradewhispr             # All Tradewhispr services"
    echo "  ./logs.sh tradewhispr tradewhispr-backend  # Just backend"
    exit 1
fi

ASUS_HOST="asus-server"  # Update with your server hostname/IP

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -z "$SERVICE" ]; then
    echo -e "${GREEN}📋 Viewing logs for all $PROJECT services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    # Show all project logs
    ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose logs -f --tail=100"
else
    echo -e "${GREEN}📋 Viewing logs for $SERVICE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    # Show specific service logs
    ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose logs -f --tail=100 $SERVICE"
fi
