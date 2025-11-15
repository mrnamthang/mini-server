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

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Fallback to defaults
    ASUS_HOST="192.168.1.10"
    ASUS_USER="thang"
    ASUS_SSH_ALIAS="asus-server"
    LOCAL_PROJECTS_DIR="$HOME/projects"
    REMOTE_PROJECTS_DIR="/opt/projects"
fi

# Get the actual project directory
LOCAL_DIR="$LOCAL_PROJECTS_DIR/$PROJECT"
REMOTE_DIR="$REMOTE_PROJECTS_DIR/$PROJECT/src"

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

# Check SSH connectivity
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$ASUS_SSH_ALIAS" exit 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to $ASUS_SSH_ALIAS${NC}"
    echo "Please check:"
    echo "  1. Server is running (ping $ASUS_HOST)"
    echo "  2. SSH config in ~/.ssh/config"
    echo "  3. SSH keys are set up"
    exit 1
fi

# Ensure remote directory exists
if ! ssh "$ASUS_SSH_ALIAS" "test -d $REMOTE_DIR" 2>/dev/null; then
    echo -e "${YELLOW}📁 Creating remote directory...${NC}"
    ssh "$ASUS_SSH_ALIAS" "mkdir -p $REMOTE_DIR && chown $ASUS_USER:$ASUS_USER $REMOTE_DIR" 2>/dev/null || \
        ssh "$ASUS_SSH_ALIAS" "sudo mkdir -p $REMOTE_DIR && sudo chown $ASUS_USER:$ASUS_USER $REMOTE_DIR"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Remote directory created${NC}"
    else
        echo -e "${RED}Error: Failed to create remote directory${NC}"
        echo "Please run on Asus server:"
        echo "  sudo mkdir -p $REMOTE_DIR"
        echo "  sudo chown $ASUS_USER:$ASUS_USER $REMOTE_DIR"
        exit 1
    fi
fi

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
