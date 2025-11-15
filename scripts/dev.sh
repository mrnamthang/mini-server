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
REMOTE_DIR="$REMOTE_PROJECTS_DIR/$PROJECT/src"

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

# Logs-only mode
if [ "$MODE" == "logs-only" ]; then
    echo -e "${YELLOW}📋 Viewing logs from Asus server...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose logs -f --tail=100"
    exit 0
fi

# Ensure remote directory exists
echo -e "${YELLOW}🔍 Checking remote directory...${NC}"
if ! ssh "$ASUS_SSH_ALIAS" "test -d $REMOTE_DIR" 2>/dev/null; then
    echo -e "${YELLOW}📁 Creating remote directory structure...${NC}"
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
else
    echo -e "${GREEN}✓ Remote directory exists${NC}"
fi
echo ""

# Initial sync
echo -e "${YELLOW}🔄 Initial sync to Asus...${NC}"
rsync -az --delete \
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
  "$LOCAL_DIR/" "$ASUS_USER@$ASUS_HOST:$REMOTE_DIR/" 2>&1 | grep -v "^sending\|^sent\|^total size" || true

echo -e "${GREEN}✓ Initial sync complete${NC}"
echo ""

# Start services if not running
echo -e "${YELLOW}🔍 Checking if services are running...${NC}"

# Check if docker-compose.yml exists on remote
if ! ssh "$ASUS_SSH_ALIAS" "test -f $REMOTE_PROJECTS_DIR/$PROJECT/docker-compose.yml" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  No docker-compose.yml found on Asus${NC}"

    # Check if we have it locally and can auto-copy it
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOCAL_COMPOSE="$SCRIPT_DIR/../projects/$PROJECT/docker-compose.yml"

    if [ -f "$LOCAL_COMPOSE" ]; then
        echo -e "${YELLOW}📄 Found docker-compose.yml locally, copying to Asus...${NC}"
        scp "$LOCAL_COMPOSE" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECTS_DIR/$PROJECT/" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ docker-compose.yml copied successfully${NC}"

            # Also copy .env.example if it exists
            LOCAL_ENV="$SCRIPT_DIR/../projects/$PROJECT/.env.example"
            if [ -f "$LOCAL_ENV" ]; then
                echo -e "${YELLOW}📄 Copying .env.example...${NC}"
                scp "$LOCAL_ENV" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECTS_DIR/$PROJECT/.env" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ .env.example copied as .env${NC}"
                    echo -e "${BLUE}ℹ️  Remember to edit .env on Asus with your actual values${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Failed to copy docker-compose.yml${NC}"
            echo -e "${BLUE}ℹ️  Manual copy: scp projects/$PROJECT/docker-compose.yml $ASUS_USER@$ASUS_HOST:$REMOTE_PROJECTS_DIR/$PROJECT/${NC}"
            echo ""
        fi
    else
        echo -e "${BLUE}ℹ️  Copy your docker-compose.yml to the server:${NC}"
        echo -e "   scp projects/$PROJECT/docker-compose.yml $ASUS_USER@$ASUS_HOST:$REMOTE_PROJECTS_DIR/$PROJECT/"
        echo ""
    fi
fi

# Try to start services if docker-compose.yml exists now
if ssh "$ASUS_SSH_ALIAS" "test -f $REMOTE_PROJECTS_DIR/$PROJECT/docker-compose.yml" 2>/dev/null; then
    RUNNING=$(ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose ps -q" 2>/dev/null || echo "")
    if [ -z "$RUNNING" ]; then
        echo -e "${YELLOW}⚡ Starting services on Asus...${NC}"
        ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose up -d" 2>&1 | tail -5
        echo -e "${GREEN}✓ Services started${NC}"
    else
        echo -e "${GREEN}✓ Services already running${NC}"
    fi
fi
echo ""

# Show access URLs
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Ready for development!${NC}"
echo ""
echo -e "${CYAN}Access your app:${NC}"
echo -e "  🌐 http://$PROJECT.local"
echo -e "  🌐 http://api.$PROJECT.local"
echo ""
echo -e "${CYAN}Workflow:${NC}"
echo -e "  1. Edit code on Mac (any editor)"
echo -e "  2. Files auto-sync to Asus"
if [ "$MODE" == "auto" ]; then
    echo -e "  3. Backend changes trigger rebuild"
    echo -e "  4. View changes in browser"
else
    echo -e "  3. View changes in browser"
fi
echo ""
echo -e "${YELLOW}Watching for changes... Press Ctrl+C to stop${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Track last change for debouncing
LAST_CHANGE_TIME=0
REBUILD_NEEDED=false
CHANGED_FILES=()

# Detect if files need rebuild
needs_rebuild() {
    local file=$1

    # Backend file patterns that require rebuild
    if [[ "$file" =~ \.(cs|csproj|py|requirements\.txt|Dockerfile)$ ]]; then
        return 0  # true
    fi

    # Frontend files don't need rebuild (hot-reload handles it)
    if [[ "$file" =~ \.(tsx?|jsx?|vue|css|scss|html)$ ]]; then
        return 1  # false
    fi

    # Config changes might need rebuild
    if [[ "$file" =~ (package\.json|docker-compose|\.env\.example)$ ]]; then
        return 0  # true
    fi

    # Default: don't rebuild
    return 1
}

# Sync function
do_sync() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local changed_count=${#CHANGED_FILES[@]}

    echo -e "${CYAN}[$timestamp]${NC} 🔄 Syncing $changed_count file(s)..."

    # Show what changed (first 5 files)
    local display_count=$((changed_count < 5 ? changed_count : 5))
    for ((i=0; i<display_count; i++)); do
        local file=${CHANGED_FILES[$i]}
        local rel_path=${file#$LOCAL_DIR/}
        echo -e "  ${BLUE}•${NC} $rel_path"
    done
    if [ $changed_count -gt 5 ]; then
        echo -e "  ${BLUE}•${NC} ... and $((changed_count - 5)) more"
    fi

    # Sync
    rsync -az --delete \
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
      "$LOCAL_DIR/" "$ASUS_USER@$ASUS_HOST:$REMOTE_DIR/" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${CYAN}[$timestamp]${NC} ${GREEN}✓${NC} Sync complete"

        # Check if rebuild needed
        if [ "$MODE" == "auto" ] && [ "$REBUILD_NEEDED" == "true" ]; then
            echo -e "${CYAN}[$timestamp]${NC} ${YELLOW}🔨 Backend changes detected, rebuilding...${NC}"

            # Rebuild and restart
            ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose build" 2>&1 | \
                grep -E "Step|Successfully|ERROR|WARN" | \
                sed 's/^/  /'

            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose up -d" >/dev/null 2>&1
                echo -e "${CYAN}[$timestamp]${NC} ${GREEN}✓${NC} Rebuild complete, services restarted"

                # Show brief logs
                if [ "$AUTO_SHOW_LOGS" == "true" ]; then
                    echo -e "${CYAN}[$timestamp]${NC} ${BLUE}📋 Recent logs:${NC}"
                    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECTS_DIR/$PROJECT && docker-compose logs --tail=10" 2>&1 | sed 's/^/  /'
                fi
            else
                echo -e "${CYAN}[$timestamp]${NC} ${RED}✗${NC} Rebuild failed"
            fi

            REBUILD_NEEDED=false
        fi
    else
        echo -e "${CYAN}[$timestamp]${NC} ${RED}✗${NC} Sync failed"
    fi

    # Reset tracking
    CHANGED_FILES=()
    echo ""
}

# Watch for changes
fswatch -r -l $SYNC_DELAY \
  --exclude='\.git/' \
  --exclude='node_modules/' \
  --exclude='__pycache__/' \
  --exclude='\.pytest_cache/' \
  --exclude='bin/' \
  --exclude='obj/' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='\.vscode/' \
  --exclude='\.idea/' \
  --exclude='\.DS_Store' \
  --exclude='.*\.swp' \
  --exclude='.*\.log' \
  "$LOCAL_DIR" | while read change; do

    # Add to changed files
    CHANGED_FILES+=("$change")

    # Check if rebuild needed
    if [ "$MODE" == "auto" ]; then
        if needs_rebuild "$change"; then
            REBUILD_NEEDED=true
        fi
    fi

    # Debounce: wait for batch of changes
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_CHANGE_TIME))

    if [ $TIME_DIFF -ge $SYNC_DELAY ]; then
        # Enough time has passed, trigger sync
        do_sync
        LAST_CHANGE_TIME=$CURRENT_TIME
    fi
done
