#!/bin/bash
# Watch for changes and auto-sync to Asus server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo "Usage: ./watch-and-sync.sh [flow|tradewhispr]"
    echo ""
    echo "Examples:"
    echo "  ./watch-and-sync.sh flow"
    echo "  ./watch-and-sync.sh tradewhispr"
    exit 1
fi

LOCAL_DIR="$HOME/projects/$PROJECT"

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo -e "${RED}Error: fswatch is not installed${NC}"
    echo ""
    echo "Install fswatch:"
    echo "  macOS: brew install fswatch"
    echo "  Linux: apt install fswatch"
    exit 1
fi

# Check if local directory exists
if [ ! -d "$LOCAL_DIR" ]; then
    echo -e "${RED}Error: Local directory not found: $LOCAL_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}👀 Watching $PROJECT for changes...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Directory: $LOCAL_DIR"
echo ""
echo -e "${YELLOW}Changes will be automatically synced to Asus server${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Watch for changes and sync
# Using -r for recursive, -l for latency (wait 2 seconds for batch changes)
fswatch -r -l 2 \
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
  "$LOCAL_DIR" | while read change; do

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$TIMESTAMP] 🔄 Change detected, syncing...${NC}"

    # Run sync script
    "$SCRIPT_DIR/sync-to-asus.sh" "$PROJECT" 2>&1 | grep -v "^sending\|^sent\|^total size"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[$TIMESTAMP] ✅ Sync complete${NC}"
        echo ""
    else
        echo -e "${RED}[$TIMESTAMP] ❌ Sync failed${NC}"
        echo ""
    fi
done
