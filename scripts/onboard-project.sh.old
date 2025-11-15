#!/bin/bash
# Smart project onboarding - Auto-detects tech stack from existing Docker config

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📦 Smart Project Onboarding${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get project details
read -p "Project name (lowercase, no spaces): " PROJECT_NAME
read -p "Git repository URL (or path to local project): " GIT_REPO
read -p "Domain (default: ${PROJECT_NAME}.local): " DOMAIN

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    DOMAIN="${PROJECT_NAME}.local"
fi

echo ""
echo -e "${YELLOW}🔍 Analyzing project...${NC}"
echo ""

# Determine source directory
SOURCE_DIR=""
if [ -d "$GIT_REPO" ]; then
    # Local directory provided
    SOURCE_DIR="$GIT_REPO"
    echo "Using local directory: $SOURCE_DIR"
elif [[ "$GIT_REPO" =~ ^(https?|git)://|^git@ ]]; then
    # Git URL provided - clone to temp
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    echo "Cloning repository..."
    if git clone --depth 1 "$GIT_REPO" "$TEMP_DIR/repo" >/dev/null 2>&1; then
        SOURCE_DIR="$TEMP_DIR/repo"
    else
        echo -e "${RED}Error: Failed to clone repository${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: Please provide a valid git URL or local directory path${NC}"
    exit 1
fi

# Find docker-compose files
COMPOSE_FILE=""
for file in docker-compose.yml docker-compose.yaml docker-compose.prod.yml; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        COMPOSE_FILE="$SOURCE_DIR/$file"
        echo -e "${GREEN}✓ Found: $file${NC}"
        break
    fi
done

if [ -z "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: No docker-compose.yml found in project${NC}"
    echo "Please ensure your project has a docker-compose.yml file"
    exit 1
fi

# Analyze docker-compose.yml
echo ""
echo -e "${BLUE}📊 Analyzing Docker Compose...${NC}"

# Detect services and tech stack
HAS_POSTGRES=$(grep -i "image.*postgres" "$COMPOSE_FILE" && echo "yes" || echo "")
HAS_REDIS=$(grep -i "image.*redis" "$COMPOSE_FILE" && echo "yes" || echo "")
HAS_NODE=$(grep -iE "image.*(node|npm)" "$COMPOSE_FILE" && echo "yes" || echo "")
HAS_PYTHON=$(grep -iE "image.*(python|fastapi|django)" "$COMPOSE_FILE" && echo "yes" || echo "")
HAS_DOTNET=$(grep -iE "image.*(dotnet|aspnet|mcr.microsoft)" "$COMPOSE_FILE" && echo "yes" || echo "")
HAS_MYSQL=$(grep -i "image.*mysql" "$COMPOSE_FILE" && echo "yes" || echo "")

# Display detected stack
echo "Detected:"
[ -n "$HAS_NODE" ] && echo -e "  ${GREEN}✓${NC} Node.js"
[ -n "$HAS_PYTHON" ] && echo -e "  ${GREEN}✓${NC} Python"
[ -n "$HAS_DOTNET" ] && echo -e "  ${GREEN}✓${NC} .NET"
[ -n "$HAS_POSTGRES" ] && echo -e "  ${GREEN}✓${NC} PostgreSQL"
[ -n "$HAS_REDIS" ] && echo -e "  ${GREEN}✓${NC} Redis"
[ -n "$HAS_MYSQL" ] && echo -e "  ${GREEN}✓${NC} MySQL"

echo ""
echo -e "${YELLOW}🔧 Creating project configuration...${NC}"

# Create project directory
mkdir -p "projects/${PROJECT_NAME}"

# Copy and backup original
cp "$COMPOSE_FILE" "projects/${PROJECT_NAME}/docker-compose.original.yml"
cp "$COMPOSE_FILE" "projects/${PROJECT_NAME}/docker-compose.yml"

# Add Traefik network and labels
cat >> "projects/${PROJECT_NAME}/docker-compose.yml" << EOF

# Added by onboard-project.sh
networks:
  traefik-public:
    external: true
EOF

echo -e "${GREEN}✓ Docker Compose copied${NC}"

# Generate .env.example
cat > "projects/${PROJECT_NAME}/.env.example" << EOF
# ${PROJECT_NAME} - Environment Variables

# =============================================================================
# DOMAIN CONFIGURATION
# =============================================================================
${PROJECT_NAME^^}_DOMAIN=${DOMAIN}
${PROJECT_NAME^^}_API_DOMAIN=api.${DOMAIN}

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
$([ -n "$HAS_POSTGRES" ] && echo "POSTGRES_DB=${PROJECT_NAME}db
POSTGRES_USER=${PROJECT_NAME}user
POSTGRES_PASSWORD=change-me-in-production")
$([ -n "$HAS_MYSQL" ] && echo "MYSQL_DATABASE=${PROJECT_NAME}db
MYSQL_USER=${PROJECT_NAME}user
MYSQL_PASSWORD=change-me-in-production
MYSQL_ROOT_PASSWORD=change-me-in-production")

# =============================================================================
# APPLICATION
# =============================================================================
# Add your environment variables here
EOF

echo -e "${GREEN}✓ .env.example generated${NC}"

# Create deployment README
cat > "projects/${PROJECT_NAME}/README.md" << EOF
# ${PROJECT_NAME} Deployment

## Auto-Detected Stack

$([ -n "$HAS_NODE" ] && echo "- ✅ Node.js")
$([ -n "$HAS_PYTHON" ] && echo "- ✅ Python")
$([ -n "$HAS_DOTNET" ] && echo "- ✅ .NET")
$([ -n "$HAS_POSTGRES" ] && echo "- ✅ PostgreSQL")
$([ -n "$HAS_REDIS" ] && echo "- ✅ Redis")
$([ -n "$HAS_MYSQL" ] && echo "- ✅ MySQL")

## Quick Deploy

### 1. Clone to Asus

\`\`\`bash
ssh thang@192.168.1.10
sudo mkdir -p /opt/projects/${PROJECT_NAME}/src
sudo chown thang:thang /opt/projects/${PROJECT_NAME}/src
cd /opt/projects/${PROJECT_NAME}
$([ -n "$GIT_REPO" ] && [[ "$GIT_REPO" =~ ^(https?|git) ]] && echo "git clone ${GIT_REPO} src" || echo "# Copy your source code to src/")
exit
\`\`\`

### 2. Deploy Configuration

\`\`\`bash
# Copy docker-compose.yml
scp projects/${PROJECT_NAME}/docker-compose.yml thang@192.168.1.10:/opt/projects/${PROJECT_NAME}/

# Copy environment template
scp projects/${PROJECT_NAME}/.env.example thang@192.168.1.10:/opt/projects/${PROJECT_NAME}/.env
\`\`\`

### 3. Configure & Start

\`\`\`bash
ssh thang@192.168.1.10
cd /opt/projects/${PROJECT_NAME}

# Configure environment
nano .env

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f
exit
\`\`\`

### 4. Access

Add to your Mac's \`/etc/hosts\`:
\`\`\`
192.168.1.10 ${DOMAIN}
192.168.1.10 api.${DOMAIN}
\`\`\`

Then visit:
- http://${DOMAIN}
- http://api.${DOMAIN}

## Manual Traefik Configuration

To enable Traefik routing, add these labels to your web services in docker-compose.yml:

\`\`\`yaml
services:
  your-web-service:
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-public"
      - "traefik.http.routers.${PROJECT_NAME}-web.rule=Host(\\\`${DOMAIN}\\\`)"
      - "traefik.http.routers.${PROJECT_NAME}-web.entrypoints=web"
      - "traefik.http.services.${PROJECT_NAME}-web.loadbalancer.server.port=80"

  your-api-service:
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-public"
      - "traefik.http.routers.${PROJECT_NAME}-api.rule=Host(\\\`api.${DOMAIN}\\\`)"
      - "traefik.http.routers.${PROJECT_NAME}-api.entrypoints=web"
      - "traefik.http.services.${PROJECT_NAME}-api.loadbalancer.server.port=3000"
\`\`\`

## Files

- \`docker-compose.yml\` - Ready for mini-server
- \`docker-compose.original.yml\` - Your original (backup)
- \`.env.example\` - Environment template
EOF

echo -e "${GREEN}✓ README generated${NC}"

# Create helper script to add Traefik labels
cat > "projects/${PROJECT_NAME}/add-traefik-labels.txt" << EOF
# Add these sections to your docker-compose.yml

# 1. For each web-facing service, add to networks:
    networks:
      - traefik-public

# 2. Add labels for routing:
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-public"
      - "traefik.http.routers.${PROJECT_NAME}-SERVICENAME.rule=Host(\`YOURDOMAIN\`)"
      - "traefik.http.routers.${PROJECT_NAME}-SERVICENAME.entrypoints=web"
      - "traefik.http.services.${PROJECT_NAME}-SERVICENAME.loadbalancer.server.port=PORT"

# 3. At the bottom, add:
networks:
  traefik-public:
    external: true

# Examples based on your services:
# - Frontend service: Use domain ${DOMAIN}
# - API service: Use domain api.${DOMAIN}
# - Port: Check your service's exposed port (80, 3000, 8000, etc.)
EOF

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project ${PROJECT_NAME} configured!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📁 Generated files in projects/${PROJECT_NAME}/:${NC}"
echo "  - docker-compose.yml"
echo "  - docker-compose.original.yml (backup)"
echo "  - .env.example"
echo "  - README.md (deployment guide)"
echo "  - add-traefik-labels.txt (manual config guide)"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Manual step required${NC}"
echo "You need to add Traefik labels to your docker-compose.yml"
echo "See: projects/${PROJECT_NAME}/add-traefik-labels.txt"
echo "Or refer to projects/flow/ or projects/tradewhispr/ for examples"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Review and edit: ${BLUE}projects/${PROJECT_NAME}/docker-compose.yml${NC}"
echo "2. Add Traefik labels to web-facing services"
echo "3. Follow deployment steps in: ${BLUE}projects/${PROJECT_NAME}/README.md${NC}"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
