#!/bin/bash
# Setup script for development workflow scripts
# This configures the scripts with your actual server details

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🛠️  Development Scripts Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prompt for server details
echo -e "${YELLOW}Enter your Asus server details:${NC}"
echo ""

read -p "Asus server hostname or IP [asus-server]: " ASUS_HOST
ASUS_HOST=${ASUS_HOST:-asus-server}

read -p "Asus server username: " ASUS_USER

if [ -z "$ASUS_USER" ]; then
    echo -e "${RED}Error: Username is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📝 Updating scripts with your configuration...${NC}"
echo ""

# Update all scripts with the server details
for script in sync-to-asus.sh watch-and-sync.sh rebuild-on-asus.sh logs.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        # Replace ASUS_HOST placeholder
        sed -i.bak "s/ASUS_HOST=\"asus-server\"/ASUS_HOST=\"$ASUS_HOST\"/g" "$SCRIPT_DIR/$script"

        # Replace ASUS_USER placeholder if present
        sed -i.bak "s/ASUS_USER=\"your-username\"/ASUS_USER=\"$ASUS_USER\"/g" "$SCRIPT_DIR/$script"

        # Make script executable
        chmod +x "$SCRIPT_DIR/$script"

        # Remove backup file
        rm -f "$SCRIPT_DIR/$script.bak"

        echo -e "  ${GREEN}✓${NC} Updated $script"
    fi
done

echo ""
echo -e "${YELLOW}🔍 Testing SSH connection...${NC}"

if ssh -o ConnectTimeout=5 "$ASUS_USER@$ASUS_HOST" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✅ SSH connection successful!${NC}"
else
    echo -e "${RED}❌ SSH connection failed${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. Server is running"
    echo "  2. SSH is enabled"
    echo "  3. You have SSH key access (run: ssh-copy-id $ASUS_USER@$ASUS_HOST)"
    echo "  4. Server address is correct"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Available commands:"
echo "  ${GREEN}./scripts/sync-to-asus.sh flow${NC}              # Sync Flow project"
echo "  ${GREEN}./scripts/watch-and-sync.sh flow${NC}            # Auto-sync on changes"
echo "  ${GREEN}./scripts/rebuild-on-asus.sh flow flow-api${NC}  # Rebuild service"
echo "  ${GREEN}./scripts/logs.sh flow flow-api${NC}             # View logs"
echo ""
echo "Quick start:"
echo "  1. Clone your projects to ~/projects/flow and ~/projects/tradewhispr"
echo "  2. Run: ${GREEN}./scripts/watch-and-sync.sh flow${NC} (in background terminal)"
echo "  3. Edit code in VS Code"
echo "  4. Changes auto-sync to Asus"
echo "  5. View in browser: http://flow.local"
echo ""
echo "For full workflow guide, see: ${BLUE}DEVELOPMENT_WORKFLOW.md${NC}"
