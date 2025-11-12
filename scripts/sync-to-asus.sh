#!/bin/bash
# Sync local changes to Asus server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo "Usage: ./sync-to-asus.sh [flow|tradewhispr]"
    echo ""
    echo "Examples:"
    echo "  ./sync-to-asus.sh flow"
    echo "  ./sync-to-asus.sh tradewhispr"
    exit 1
fi

# Configuration - Update these values
ASUS_HOST="asus-server"  # Update with your server hostname/IP
ASUS_USER="your-username"  # Update with your username

# Get the actual project directory (assumes you cloned to ~/projects/)
LOCAL_DIR="$HOME/projects/$PROJECT"
REMOTE_DIR="/opt/projects/$PROJECT/src"

# Check if local directory exists
if [ ! -d "$LOCAL_DIR" ]; then
    echo -e "${RED}Error: Local directory not found: $LOCAL_DIR${NC}"
    echo "Please update LOCAL_DIR in this script or ensure project is cloned to ~/projects/$PROJECT"
    exit 1
fi

echo -e "${YELLOW}📦 Syncing $PROJECT to Asus server...${NC}"
echo "Local:  $LOCAL_DIR"
echo "Remote: $ASUS_USER@$ASUS_HOST:$REMOTE_DIR"
echo ""

# Rsync with exclusions
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude 'bin' \
  --exclude 'obj' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude 'venv' \
  --exclude '.env' \
  --exclude '.vscode' \
  --exclude '.idea' \
  --exclude 'dist' \
  --exclude 'build' \
  --exclude '*.log' \
  --progress \
  "$LOCAL_DIR/" "$ASUS_USER@$ASUS_HOST:$REMOTE_DIR/"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Successfully synced $PROJECT to Asus server${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Rebuild: ./scripts/rebuild-on-asus.sh $PROJECT <service-name>"
    echo "  2. View logs: ./scripts/logs.sh $PROJECT"
    echo "  3. Access: http://$PROJECT.local"
else
    echo -e "${RED}❌ Sync failed${NC}"
    exit 1
fi
