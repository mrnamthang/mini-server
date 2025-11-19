#!/bin/bash
# Unified development workflow: Edit on Mac, run on Asus
# Watches files, syncs, smart rebuilds, shows logs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please create .dev-config from .dev-config.example"
    exit 1
fi

# Parse arguments
PROJECT=$1
MODE=${2:-"auto"}  # auto|sync-only|logs-only

if [ -z "$PROJECT" ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo ""
    echo "Usage: $0 <project> [mode]"
    echo ""
    echo "Modes:"
    echo "  auto        - Watch, sync, smart rebuild, show logs (default)"
    echo "  sync-only   - Only watch and sync (no rebuild)"
    echo "  logs-only   - Only show logs (no sync)"
    echo ""
    echo "Examples:"
    echo "  $0 flow              # Full auto mode"
    echo "  $0 flow sync-only    # Just sync, no rebuild"
    echo "  $0 flow logs-only    # Just show logs"
    exit 1
fi

LOCAL_DIR="$LOCAL_PROJECTS_DIR/$PROJECT"
REMOTE_DIR="$REMOTE_PROJECTS_DIR/$PROJECT"

# Check if fswatch is installed
if [ "$MODE" != "logs-only" ] && ! command -v fswatch &> /dev/null; then
    echo -e "${RED}Error: fswatch is not installed${NC}"
    echo ""
    echo "Install fswatch on Mac:"
    echo "  brew install fswatch"
    exit 1
fi

# Check if local directory exists
if [ "$MODE" != "logs-only" ] && [ ! -d "$LOCAL_DIR" ]; then
    echo -e "${RED}Error: Local directory not found: $LOCAL_DIR${NC}"
    echo ""
    echo "Expected path: $LOCAL_DIR"
    echo "Please clone your project to: $LOCAL_PROJECTS_DIR/$PROJECT"
    exit 1
fi

# Banner
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🚀 Mac ↔ Asus Development Workflow${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Project:${NC}  $PROJECT"
echo -e "${GREEN}Mode:${NC}     $MODE"
echo -e "${GREEN}Local:${NC}    $LOCAL_DIR"
echo -e "${GREEN}Remote:${NC}   $ASUS_USER@$ASUS_HOST:$REMOTE_DIR"
echo ""

# Logs-only mode (Default for Git-based workflow)
if [ "$MODE" == "logs-only" ] || [ "$MODE" == "auto" ]; then
    echo -e "${YELLOW}📋 Viewing logs from Asus server...${NC}"
    echo -e "${BLUE}ℹ️  Note: Live sync is disabled. Please commit & push changes, then run 'make deploy-$PROJECT'${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose logs -f --tail=100"
    exit 0
fi

# Legacy sync code removed
echo -e "${RED}Error: Sync mode is no longer supported.${NC}"
echo "Please use Git-based deployment:"
echo "  1. git push"
echo "  2. make deploy-$PROJECT"
exit 1
