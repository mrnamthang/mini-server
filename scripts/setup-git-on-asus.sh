#!/bin/bash
# Setup Git configuration on Asus server

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

NAME=$1
EMAIL=$2

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Name and email required${NC}"
    echo "Usage: $0 \"Your Name\" \"your@email.com\""
    exit 1
fi

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_SSH_ALIAS="asus-server"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔧 Setting up Git on Asus Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Configure Git
echo -e "${YELLOW}1. Configuring Git...${NC}"
ssh "$ASUS_SSH_ALIAS" << EOF
git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

# Useful Git settings
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor nano

echo "Git configured:"
git config --global --list
EOF

echo -e "${GREEN}✓ Git configured${NC}"
echo ""

# SSH key setup
echo -e "${YELLOW}2. Setting up SSH key for GitHub/GitLab...${NC}"
echo -e "${BLUE}ℹ️  Checking for existing SSH key...${NC}"

ssh "$ASUS_SSH_ALIAS" << 'EOF'
if [ -f ~/.ssh/id_ed25519.pub ]; then
    echo "✓ SSH key already exists"
else
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
    echo "✓ SSH key generated"
fi

echo ""
echo "Your public SSH key (add this to GitHub/GitLab):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat ~/.ssh/id_ed25519.pub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

echo ""
echo -e "${GREEN}✓ SSH key ready${NC}"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Git Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy the SSH public key above"
echo "2. Add to GitHub: https://github.com/settings/ssh/new"
echo "3. Or GitLab: https://gitlab.com/-/profile/keys"
echo ""
echo -e "${YELLOW}Test SSH connection:${NC}"
echo "  ssh $ASUS_SSH_ALIAS 'ssh -T git@github.com'"
echo ""
echo -e "${YELLOW}Clone a repo:${NC}"
echo "  ssh $ASUS_SSH_ALIAS 'cd /opt/projects/myproject && git clone git@github.com:user/repo.git src'"
echo ""
