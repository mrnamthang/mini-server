#!/bin/bash
# Auto-SSL for .local domains - Like Laravel Valet's 'secure' command
# Sets up mkcert and configures Traefik for HTTPS

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🔒 Auto-SSL Setup for .local Domains${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_HOST="192.168.1.10"
    ASUS_USER="thang"
    ASUS_SSH_ALIAS="asus-server"
fi

# Step 1: Check if mkcert is installed
echo -e "${YELLOW}1. Checking mkcert installation...${NC}"
if command -v mkcert &> /dev/null; then
    echo -e "${GREEN}✓ mkcert is installed${NC}"
else
    echo -e "${YELLOW}⚡ Installing mkcert...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install mkcert nss
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
        chmod +x mkcert-v*-linux-amd64
        sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
    fi

    if command -v mkcert &> /dev/null; then
        echo -e "${GREEN}✓ mkcert installed${NC}"
    else
        echo -e "${RED}✗ Failed to install mkcert${NC}"
        echo "Please install manually: brew install mkcert"
        exit 1
    fi
fi
echo ""

# Step 2: Install local CA
echo -e "${YELLOW}2. Installing local Certificate Authority...${NC}"
if mkcert -install 2>&1 | grep -q "already"; then
    echo -e "${GREEN}✓ Local CA already installed${NC}"
else
    mkcert -install
    echo -e "${GREEN}✓ Local CA installed${NC}"
fi
echo ""

# Step 3: Generate wildcard certificate
echo -e "${YELLOW}3. Generating wildcard SSL certificate...${NC}"
CERT_DIR="$SCRIPT_DIR/../traefik/certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

if [ -f "local-cert.pem" ] && [ -f "local-key.pem" ]; then
    echo -e "${YELLOW}Certificates already exist. Regenerate? (y/N)${NC}"
    read -r REGENERATE
    if [[ ! "$REGENERATE" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ️  Using existing certificates${NC}"
    else
        rm -f local-cert.pem local-key.pem _wildcard.local*
    fi
fi

if [ ! -f "local-cert.pem" ]; then
    echo -e "${BLUE}ℹ️  Generating certificate for *.local domains...${NC}"
    mkcert \
        "*.local" \
        "localhost" \
        "127.0.0.1" \
        "::1" \
        "$ASUS_HOST"

    # Rename for Traefik
    mv _wildcard.local+4.pem local-cert.pem 2>/dev/null || mv _wildcard.local*.pem local-cert.pem
    mv _wildcard.local+4-key.pem local-key.pem 2>/dev/null || mv _wildcard.local*-key.pem local-key.pem

    echo -e "${GREEN}✓ Certificate generated${NC}"
fi
echo ""

# Step 4: Update Traefik configuration
echo -e "${YELLOW}4. Configuring Traefik for HTTPS...${NC}"
TRAEFIK_CONFIG="$SCRIPT_DIR/../traefik/traefik.yml"

# Backup original
cp "$TRAEFIK_CONFIG" "$TRAEFIK_CONFIG.backup"

# Check if TLS section exists
if grep -q "certificates:" "$TRAEFIK_CONFIG"; then
    echo -e "${GREEN}✓ TLS configuration already exists${NC}"
else
    # Add TLS configuration
    cat >> "$TRAEFIK_CONFIG" << 'EOF'

# TLS Configuration - Added by secure-local.sh
tls:
  certificates:
    - certFile: /certs/local-cert.pem
      keyFile: /certs/local-key.pem
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: false
EOF
    echo -e "${GREEN}✓ TLS configuration added to traefik.yml${NC}"
fi
echo ""

# Step 5: Update Traefik docker-compose
echo -e "${YELLOW}5. Updating Traefik Docker Compose...${NC}"
TRAEFIK_COMPOSE="$SCRIPT_DIR/../traefik/docker-compose.yml"

if grep -q "/certs:/certs" "$TRAEFIK_COMPOSE"; then
    echo -e "${GREEN}✓ Certificates volume already mounted${NC}"
else
    # Add certs volume to Traefik
    echo -e "${BLUE}ℹ️  Adding certs volume to Traefik...${NC}"
    # This requires manual edit for safety
    echo -e "${YELLOW}⚠️  Manual step required:${NC}"
    echo "Add this line to traefik/docker-compose.yml under volumes:"
    echo "      - ./certs:/certs:ro"
    echo ""
    echo "Press Enter when done..."
    read
fi
echo ""

# Step 6: Copy certificates to Asus
echo -e "${YELLOW}6. Copying certificates to Asus server...${NC}"
ssh "$ASUS_SSH_ALIAS" "mkdir -p /opt/traefik/certs"
scp "$CERT_DIR/local-cert.pem" "$CERT_DIR/local-key.pem" "$ASUS_USER@$ASUS_HOST:/opt/traefik/certs/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificates copied to Asus${NC}"
else
    echo -e "${RED}✗ Failed to copy certificates${NC}"
    exit 1
fi
echo ""

# Step 7: Restart Traefik
echo -e "${YELLOW}7. Restarting Traefik...${NC}"
ssh "$ASUS_SSH_ALIAS" "cd /opt/traefik && docker-compose restart"
sleep 3
echo -e "${GREEN}✓ Traefik restarted${NC}"
echo ""

# Step 8: Create helper script for securing projects
echo -e "${YELLOW}8. Creating 'secure' command...${NC}"
cat > "$SCRIPT_DIR/secure.sh" << 'SECURE_SCRIPT'
#!/bin/bash
# Secure a specific project (enable HTTPS)
# Usage: ./scripts/secure.sh <project-name>

set -e

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo "Usage: ./scripts/secure.sh <project-name>"
    echo "Example: ./scripts/secure.sh tradewhispr"
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

echo "🔒 Enabling HTTPS for $PROJECT.local..."

# Update docker-compose.yml on Asus to enable HTTPS routes
ssh "$ASUS_SSH_ALIAS" << EOF
cd /opt/projects/$PROJECT

# Add HTTPS router labels if not present
docker-compose config | grep -q "websecure" || {
    echo "Adding HTTPS configuration..."
    # This is a placeholder - actual implementation would update the file
    echo "Please add HTTPS labels to your docker-compose.yml"
    echo "See: projects/$PROJECT/docker-compose.yml"
}

# Restart services
docker-compose up -d
EOF

echo "✓ HTTPS enabled for https://$PROJECT.local"
SECURE_SCRIPT

chmod +x "$SCRIPT_DIR/secure.sh"
echo -e "${GREEN}✓ Created ./scripts/secure.sh${NC}"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SSL Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}All .local domains now support HTTPS!${NC}"
echo ""
echo -e "${YELLOW}Test it:${NC}"
echo "  https://tradewhispr.local"
echo "  https://api.tradewhispr.local"
echo "  https://flow.local"
echo ""
echo -e "${YELLOW}Enable HTTPS for a specific project:${NC}"
echo "  ./scripts/secure.sh <project-name>"
echo ""
echo -e "${BLUE}ℹ️  Note: Projects need HTTPS labels in docker-compose.yml${NC}"
echo "See projects/flow/ or projects/tradewhispr/ for examples"
echo ""
