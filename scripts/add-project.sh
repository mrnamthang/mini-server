#!/bin/bash
# Add a new project to the mini-server setup

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📦 Add New Project to Mini-Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get project details
read -p "Project name (lowercase, no spaces): " PROJECT_NAME
read -p "Git repository URL (or leave empty for manual): " GIT_REPO
read -p "Domain (e.g., myproject.local): " DOMAIN

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    DOMAIN="${PROJECT_NAME}.local"
fi

echo ""
echo -e "${YELLOW}📋 Project Configuration:${NC}"
echo "  Name: $PROJECT_NAME"
echo "  Domain: $DOMAIN"
echo "  Git Repo: ${GIT_REPO:-Manual deployment}"
echo ""

read -p "Select tech stack (1=Node.js, 2=Python, 3=.NET, 4=Custom): " STACK

case $STACK in
    1) STACK_TYPE="node" ;;
    2) STACK_TYPE="python" ;;
    3) STACK_TYPE="dotnet" ;;
    4) STACK_TYPE="custom" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

echo ""
echo -e "${GREEN}Creating project configuration...${NC}"

# Create project directory locally
mkdir -p "projects/${PROJECT_NAME}"

# Create .env.example
cat > "projects/${PROJECT_NAME}/.env.example" <<EOF
# ${PROJECT_NAME} - Environment Variables

# =============================================================================
# DOMAIN CONFIGURATION
# =============================================================================
${PROJECT_NAME^^}_DOMAIN=${DOMAIN}
${PROJECT_NAME^^}_API_DOMAIN=api.${DOMAIN}

# =============================================================================
# DATABASE CONFIGURATION (if needed)
# =============================================================================
POSTGRES_DB=${PROJECT_NAME}db
POSTGRES_USER=${PROJECT_NAME}user
POSTGRES_PASSWORD=change-me-in-production

# =============================================================================
# APPLICATION CONFIGURATION
# =============================================================================
# Add your app-specific variables here
EOF

# Create basic docker-compose based on stack
if [ "$STACK_TYPE" = "node" ]; then
    cat > "projects/${PROJECT_NAME}/docker-compose.yml" <<'EOF'
---
# PROJECT_NAME - Docker Compose Configuration
# Node.js/React Application

version: '3.8'

services:
  # Database
  PROJECT_NAME-db:
    image: postgres:16-alpine
    container_name: PROJECT_NAME-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-PROJECT_NAMEdb}
      POSTGRES_USER: ${POSTGRES_USER:-PROJECT_NAMEuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
    volumes:
      - PROJECT_NAME-db-data:/var/lib/postgresql/data
    networks:
      - PROJECT_NAME-internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-PROJECT_NAMEuser}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  PROJECT_NAME-api:
    image: PROJECT_NAME-api:latest
    container_name: PROJECT_NAME-api
    restart: unless-stopped
    build:
      context: ./src/backend
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://${POSTGRES_USER:-PROJECT_NAMEuser}:${POSTGRES_PASSWORD:-changeme}@PROJECT_NAME-db:5432/${POSTGRES_DB:-PROJECT_NAMEdb}
      - PORT=3001
    depends_on:
      PROJECT_NAME-db:
        condition: service_healthy
    networks:
      - PROJECT_NAME-internal
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-public"
      - "traefik.http.routers.PROJECT_NAME-api.rule=Host(\`${PROJECT_NAME_API_DOMAIN:-api.PROJECT_NAME.local}\`)"
      - "traefik.http.routers.PROJECT_NAME-api.entrypoints=web"
      - "traefik.http.services.PROJECT_NAME-api.loadbalancer.server.port=3001"

  # Frontend
  PROJECT_NAME-web:
    image: PROJECT_NAME-web:latest
    container_name: PROJECT_NAME-web
    restart: unless-stopped
    build:
      context: ./src/frontend
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
    depends_on:
      - PROJECT_NAME-api
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-public"
      - "traefik.http.routers.PROJECT_NAME-web.rule=Host(\`${PROJECT_NAME_DOMAIN:-PROJECT_NAME.local}\`)"
      - "traefik.http.routers.PROJECT_NAME-web.entrypoints=web"
      - "traefik.http.services.PROJECT_NAME-web.loadbalancer.server.port=80"

networks:
  PROJECT_NAME-internal:
    driver: bridge
  traefik-public:
    external: true

volumes:
  PROJECT_NAME-db-data:
    driver: local
EOF
    # Replace placeholders
    sed -i.bak "s/PROJECT_NAME/${PROJECT_NAME}/g" "projects/${PROJECT_NAME}/docker-compose.yml"
    rm -f "projects/${PROJECT_NAME}/docker-compose.yml.bak"
fi

# Create README
cat > "projects/${PROJECT_NAME}/README.md" <<EOF
# ${PROJECT_NAME} Deployment

## Quick Start

### 1. Clone Repository on Asus Server

\`\`\`bash
ssh thang@192.168.1.10

cd /opt/projects/${PROJECT_NAME}
sudo mkdir -p src
sudo chown thang:thang src

${GIT_REPO:+git clone ${GIT_REPO} src}
${GIT_REPO:-# Manually copy your source code to src/}

exit
\`\`\`

### 2. Deploy

\`\`\`bash
# From Mac
make deploy-${PROJECT_NAME}
\`\`\`

### 3. Configure Environment

\`\`\`bash
ssh thang@192.168.1.10
cd /opt/projects/${PROJECT_NAME}
nano .env

# Update passwords and secrets
docker-compose restart
exit
\`\`\`

### 4. Access

- Frontend: http://${DOMAIN}
- API: http://api.${DOMAIN}

## Update /etc/hosts on Mac

\`\`\`bash
sudo nano /etc/hosts

# Add:
192.168.1.10 ${DOMAIN}
192.168.1.10 api.${DOMAIN}
\`\`\`
EOF

echo ""
echo -e "${GREEN}✅ Project configuration created!${NC}"
echo ""
echo -e "${YELLOW}📁 Files created:${NC}"
echo "  - projects/${PROJECT_NAME}/docker-compose.yml"
echo "  - projects/${PROJECT_NAME}/.env.example"
echo "  - projects/${PROJECT_NAME}/README.md"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo ""
echo "1. Review and customize docker-compose.yml for your tech stack"
echo "2. SSH into Asus and clone your repo:"
echo "   ${BLUE}ssh thang@192.168.1.10${NC}"
echo "   ${BLUE}cd /opt/projects/${PROJECT_NAME}${NC}"
echo "   ${BLUE}sudo mkdir -p src && sudo chown thang:thang src${NC}"
echo "   ${GIT_REPO:+${BLUE}git clone ${GIT_REPO} src${NC}}"
echo ""
echo "3. Update projects.sh to include this project:"
echo "   ${BLUE}nano scripts/projects.sh${NC}"
echo "   Add '${PROJECT_NAME}' to PROJECTS array"
echo ""
echo "4. Add to Makefile (optional):"
echo "   ${BLUE}nano Makefile${NC}"
echo "   Add deploy-${PROJECT_NAME} target"
echo ""
echo "5. Deploy:"
echo "   ${BLUE}make deploy-${PROJECT_NAME}${NC}"
echo ""
echo "6. Update /etc/hosts on your Mac:"
echo "   ${BLUE}sudo nano /etc/hosts${NC}"
echo "   ${BLUE}192.168.1.10 ${DOMAIN}${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
