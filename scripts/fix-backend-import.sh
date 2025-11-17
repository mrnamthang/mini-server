#!/bin/bash
# Fix TradeWhispr backend import error - investigate and fix missing get_db

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}🔧 Fixing TradeWhispr Backend Import Error${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_HOST="192.168.1.10"
    ASUS_USER="thang"
    ASUS_SSH_ALIAS="asus-server"
fi

PROJECT="tradewhispr"
REMOTE_PROJECT_DIR="/opt/projects/$PROJECT"

# =============================================================================
# Step 1: Check current deps.py file
# =============================================================================
echo -e "${YELLOW}1. Checking app/api/deps.py content...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Content of app/api/deps.py ==="
cat backend/app/api/deps.py 2>/dev/null || echo "ERROR: File not found"
echo ""
echo "=== Functions defined in deps.py ==="
grep -E "^(def|async def) " backend/app/api/deps.py 2>/dev/null || echo "Could not parse functions"
echo ""
EOF

# =============================================================================
# Step 2: Check what screener.py is trying to import
# =============================================================================
echo -e "${YELLOW}2. Checking what screener.py is trying to import...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Import statements in screener.py ==="
grep -n "from app.api.deps import" backend/app/api/routes/screener.py 2>/dev/null || echo "ERROR: File not found"
echo ""
EOF

# =============================================================================
# Step 3: Check database configuration
# =============================================================================
echo -e "${YELLOW}3. Checking database configuration files...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr
echo "=== Database models file ==="
ls -la backend/app/models/ 2>/dev/null || echo "Models directory not found"
echo ""
echo "=== Database configuration ==="
if [ -f "backend/app/db/__init__.py" ]; then
    echo "✓ backend/app/db/__init__.py exists"
    cat backend/app/db/__init__.py
elif [ -f "backend/app/database.py" ]; then
    echo "✓ backend/app/database.py exists"
    cat backend/app/database.py
else
    echo "✗ No database configuration found"
fi
echo ""
EOF

# =============================================================================
# Step 4: Check if there's a database.py or db folder
# =============================================================================
echo -e "${YELLOW}4. Searching for database session setup...${NC}"
echo ""
ssh "$ASUS_SSH_ALIAS" << 'EOF'
cd /opt/projects/tradewhispr/backend
echo "=== Backend directory structure ==="
find app -type f -name "*.py" | grep -E "(database|db|session)" | head -20
echo ""
echo "=== Searching for SessionLocal or get_db patterns ==="
grep -r "SessionLocal\|get_db\|async def.*db" app --include="*.py" 2>/dev/null | head -20
echo ""
EOF

# =============================================================================
# Summary and Recommendations
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Common Fixes:${NC}"
echo ""
echo -e "${YELLOW}Option 1: get_db function is missing from deps.py${NC}"
echo "  You need to add the get_db dependency function to backend/app/api/deps.py"
echo "  Example:"
echo "    from app.db.session import SessionLocal"
echo ""
echo "    async def get_db():"
echo "        db = SessionLocal()"
echo "        try:"
echo "            yield db"
echo "        finally:"
echo "            await db.close()"
echo ""
echo -e "${YELLOW}Option 2: Import path is wrong in screener.py${NC}"
echo "  The get_db function might be in a different file"
echo "  Update the import in backend/app/api/routes/screener.py"
echo ""
echo -e "${YELLOW}Option 3: Database setup is incomplete${NC}"
echo "  You might need to create the database session configuration"
echo ""
echo -e "${CYAN}📖 Next Steps:${NC}"
echo "1. Review the output above to identify where get_db should be"
echo "2. Either add get_db to deps.py or fix the import path"
echo "3. SSH into the server and edit the file:"
echo "   $ ssh asus-server"
echo "   $ cd /opt/projects/tradewhispr/backend"
echo "   $ vim app/api/deps.py"
echo "4. Rebuild the backend container:"
echo "   $ cd /opt/projects/tradewhispr"
echo "   $ docker-compose up -d --build tradewhispr-backend"
echo "5. Check logs:"
echo "   $ docker logs -f tradewhispr-backend"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
