#!/bin/bash
# Remove project completely: code, containers, volumes, networks, and local config

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}🗑️  Remove Project Completely${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load configuration
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
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

# Get project name
PROJECT=$1

if [ -z "$PROJECT" ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo ""
    echo "Usage: $0 <project-name>"
    echo ""
    echo "Example:"
    echo "  $0 tradewhispr"
    exit 1
fi

REMOTE_PROJECT_DIR="$REMOTE_PROJECTS_DIR/$PROJECT"
LOCAL_CONFIG_DIR="$REPO_ROOT/projects/$PROJECT"

# Confirmation
echo -e "${YELLOW}⚠️  WARNING: This will completely remove:${NC}"
echo -e "  ${RED}✗${NC} All containers for $PROJECT"
echo -e "  ${RED}✗${NC} All volumes (databases will be lost!)"
echo -e "  ${RED}✗${NC} All networks"
echo -e "  ${RED}✗${NC} Project code on Asus: $REMOTE_PROJECT_DIR"
echo -e "  ${RED}✗${NC} Local config: $LOCAL_CONFIG_DIR"
echo ""
read -p "Are you sure you want to remove '$PROJECT'? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${BLUE}Cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}🗑️  Removing project...${NC}"

# ============================================================================
# STEP 1: Stop and remove containers on Asus
# ============================================================================
echo -e "${YELLOW}1. Stopping and removing containers...${NC}"

ssh "$ASUS_SSH_ALIAS" << EOF
    cd $REMOTE_PROJECT_DIR 2>/dev/null || exit 0

    # Stop and remove containers, volumes, networks
    if [ -f docker-compose.yml ]; then
        docker-compose down -v --remove-orphans 2>/dev/null || true
        echo "  ✓ Containers, volumes, and networks removed"
    else
        echo "  ℹ️  No docker-compose.yml found"
    fi
EOF

# ============================================================================
# STEP 2: Remove project directory on Asus
# ============================================================================
echo -e "${YELLOW}2. Removing project directory on Asus...${NC}"

ssh "$ASUS_SSH_ALIAS" "rm -rf $REMOTE_PROJECT_DIR 2>/dev/null || true"
echo -e "${GREEN}  ✓ Removed $REMOTE_PROJECT_DIR${NC}"

# ============================================================================
# STEP 3: Remove local configuration
# ============================================================================
echo -e "${YELLOW}3. Removing local configuration...${NC}"

if [ -d "$LOCAL_CONFIG_DIR" ]; then
    rm -rf "$LOCAL_CONFIG_DIR"
    echo -e "${GREEN}  ✓ Removed $LOCAL_CONFIG_DIR${NC}"
else
    echo -e "${BLUE}  ℹ️  No local config found${NC}"
fi

# ============================================================================
# STEP 4: Remove from /etc/hosts (optional)
# ============================================================================
echo -e "${YELLOW}4. Cleaning up /etc/hosts...${NC}"

if grep -q "$PROJECT.local" /etc/hosts 2>/dev/null; then
    echo -e "${BLUE}  Found $PROJECT.local in /etc/hosts${NC}"
    read -p "  Remove from /etc/hosts? (yes/no): " REMOVE_HOSTS

    if [ "$REMOVE_HOSTS" = "yes" ]; then
        sudo sed -i.bak "/$PROJECT.local/d" /etc/hosts
        echo -e "${GREEN}  ✓ Removed from /etc/hosts${NC}"
    else
        echo -e "${BLUE}  Skipped /etc/hosts cleanup${NC}"
    fi
else
    echo -e "${BLUE}  ℹ️  Not found in /etc/hosts${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project '$PROJECT' completely removed!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}To redeploy, run:${NC}"
echo -e "  ${GREEN}onboard${NC}"
echo ""
