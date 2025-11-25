#!/bin/bash
# Smart project onboarding - Auto-clones, detects tech stack, and deploys

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🚀 Smart Project Onboarding${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load configuration
# Resolve symlinks to find the actual script location
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

# Get project details
read -p "Git repository URL or local path: " GIT_REPO
read -p "Project name (lowercase, no spaces, default: auto-detect): " PROJECT_NAME
read -p "Domain (default: <project-name>.local): " DOMAIN

# Auto-detect project name from git URL if not provided
if [ -z "$PROJECT_NAME" ] && [[ "$GIT_REPO" =~ ^(https?|git)://|^git@ ]]; then
    PROJECT_NAME=$(echo "$GIT_REPO" | sed -E 's/.*[\/:]([^\/]+)(\.git)?$/\1/' | sed 's/\.git$//' | tr '[:upper:]' '[:lower:]' | tr '.' '-')
    echo -e "${GREEN}✓ Auto-detected project name: $PROJECT_NAME${NC}"
fi

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    DOMAIN="${PROJECT_NAME}.local"
fi

REMOTE_PROJECT_DIR="$REMOTE_PROJECTS_DIR/$PROJECT_NAME"

echo ""
echo -e "${YELLOW}📋 Project Configuration:${NC}"
echo "  Name: $PROJECT_NAME"
echo "  Domain: $DOMAIN"
echo "  Git Repo: ${GIT_REPO:-Manual deployment}"
echo "  Remote Path: $REMOTE_PROJECT_DIR"
echo ""

# ============================================================================
# STEP 0: Ensure /opt/projects is accessible
# ============================================================================
echo -e "${YELLOW}🔐 Checking server permissions...${NC}"

# Check if /opt/projects is writable
CAN_WRITE=$(ssh "$ASUS_SSH_ALIAS" "test -w $REMOTE_PROJECTS_DIR && echo yes || echo no" 2>/dev/null || echo "no")

if [ "$CAN_WRITE" = "no" ]; then
    echo -e "${BLUE}ℹ️  Setting up /opt/projects directory (requires sudo)${NC}"
    echo -e "${YELLOW}→ You'll be prompted for your sudo password on the remote server${NC}"

    # Use -t flag to allocate TTY for sudo password prompt
    ssh -t "$ASUS_SSH_ALIAS" << 'SETUP_EOF'
        # Validate sudo access and cache credentials
        sudo -v

        # Create base directory if it doesn't exist
        if [ ! -d /opt/projects ]; then
            sudo mkdir -p /opt/projects
        fi

        # Make user owner of /opt/projects
        sudo chown -R $USER:$USER /opt/projects

        echo "✓ /opt/projects is now accessible"
SETUP_EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Server permissions configured${NC}"
    else
        echo -e "${RED}✗ Failed to configure permissions${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ /opt/projects is accessible${NC}"
fi

echo ""

# ============================================================================
# STEP 1: Clone project to Asus
# ============================================================================
echo -e "${YELLOW}📦 Step 1: Cloning project to Asus server...${NC}"

if [[ "$GIT_REPO" =~ ^(https?|git)://|^git@ ]]; then
    # Git URL provided - clone to Asus
    echo -e "${BLUE}ℹ️  Cloning from: $GIT_REPO${NC}"

    ssh "$ASUS_SSH_ALIAS" << EOF
        # Clone repository
        if [ -d "$REMOTE_PROJECT_DIR" ]; then
            echo "Directory exists, pulling latest changes..."
            cd $REMOTE_PROJECT_DIR
            git pull
        else
            git clone $GIT_REPO $REMOTE_PROJECT_DIR
        fi
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Project cloned to Asus${NC}"
    else
        echo -e "${RED}✗ Failed to clone project${NC}"
        echo -e "${YELLOW}⚠️  Make sure:${NC}"
        echo "  1. Git is configured on Asus (run: ./scripts/setup-git-on-asus.sh)"
        echo "  2. SSH key is added to GitHub/GitLab"
        echo "  3. You have access to the repository"
        exit 1
    fi
elif [ -d "$GIT_REPO" ]; then
    # Local directory provided - rsync to Asus
    echo -e "${BLUE}ℹ️  Syncing from local: $GIT_REPO${NC}"

    ssh "$ASUS_SSH_ALIAS" "mkdir -p $REMOTE_PROJECT_DIR"

    rsync -az --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude 'vendor' \
        --exclude 'bin' \
        --exclude 'obj' \
        --exclude '__pycache__' \
        --exclude '.env' \
        "$GIT_REPO/" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"

    echo -e "${GREEN}✓ Project synced to Asus${NC}"
else
    echo -e "${RED}Error: Invalid git URL or local path${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 2: Analyze project and detect tech stack
# ============================================================================
echo -e "${YELLOW}🔍 Step 2: Analyzing project...${NC}"

# Get file list from Asus and detect tech stack (disable exit on error temporarily)
set +e
FILES=$(ssh "$ASUS_SSH_ALIAS" "ls -1 $REMOTE_PROJECT_DIR 2>/dev/null")
HAS_DOCKER_COMPOSE=$(echo "$FILES" | grep -E "^docker-compose\.ya?ml$" && echo "yes" || echo "")
HAS_COMPOSER=$(echo "$FILES" | grep "^composer.json$" && echo "yes" || echo "")
HAS_ARTISAN=$(ssh "$ASUS_SSH_ALIAS" "test -f $REMOTE_PROJECT_DIR/artisan && echo yes" || echo "")
HAS_PACKAGE_JSON=$(echo "$FILES" | grep "^package.json$" && echo "yes" || echo "")
HAS_REQUIREMENTS=$(echo "$FILES" | grep "^requirements.txt$" && echo "")
HAS_MANAGE_PY=$(echo "$FILES" | grep "^manage.py$" && echo "yes" || echo "")
set -e

# Determine project type
PROJECT_TYPE=""

if [ -n "$HAS_DOCKER_COMPOSE" ]; then
    PROJECT_TYPE="docker-existing"
    echo -e "${GREEN}✓ Found existing docker-compose.yml${NC}"
elif [ -n "$HAS_COMPOSER" ] && [ -n "$HAS_ARTISAN" ]; then
    PROJECT_TYPE="laravel"
    echo -e "${GREEN}✓ Detected Laravel project${NC}"

    # Detect PHP version from composer.json (disable exit on error temporarily)
    set +e
    PHP_VERSION=$(ssh "$ASUS_SSH_ALIAS" "cat $REMOTE_PROJECT_DIR/composer.json 2>/dev/null | grep -oP '\"php\":\s*\"\^?\K[0-9]+\.[0-9]+'" || echo "8.2")
    set -e
    echo -e "${BLUE}  → PHP Version: $PHP_VERSION${NC}"

    # Detect database preference
    DB_TYPE="mysql"
    echo -e "${BLUE}  → Database: MySQL (default)${NC}"
elif [ -n "$HAS_PACKAGE_JSON" ]; then
    PROJECT_TYPE="nodejs"
    echo -e "${GREEN}✓ Detected Node.js project${NC}"
elif [ -n "$HAS_REQUIREMENTS" ] && [ -n "$HAS_MANAGE_PY" ]; then
    PROJECT_TYPE="django"
    echo -e "${GREEN}✓ Detected Django project${NC}"
else
    echo -e "${RED}✗ Cannot auto-detect project type${NC}"
    echo -e "${YELLOW}⚠️  Please add a docker-compose.yml to your project${NC}"
    exit 1
fi

echo ""

# ============================================================================
# STEP 3: Generate or copy Docker configuration
# ============================================================================
echo -e "${YELLOW}🔧 Step 3: Setting up Docker configuration...${NC}"

LOCAL_CONFIG_DIR="$REPO_ROOT/projects/$PROJECT_NAME"
mkdir -p "$LOCAL_CONFIG_DIR"

case $PROJECT_TYPE in
    "docker-existing")
        echo -e "${BLUE}ℹ️  Using existing docker-compose.yml${NC}"

        # Download existing compose file (keep it unchanged)
        scp "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/docker-compose.yml" "$LOCAL_CONFIG_DIR/docker-compose.original.yml"
        cp "$LOCAL_CONFIG_DIR/docker-compose.original.yml" "$LOCAL_CONFIG_DIR/docker-compose.yml"

        # Generate docker-compose.dev.yml for Traefik integration
        echo -e "${BLUE}ℹ️  Generating docker-compose.dev.yml for Asus/Traefik...${NC}"

        # Detect web-facing services (backend, frontend, web, api, app, nginx)
        SERVICES=$(grep -E "^  [a-zA-Z0-9_-]+:" "$LOCAL_CONFIG_DIR/docker-compose.yml" | sed 's/://g' | tr -d ' ')
        WEB_SERVICES=$(echo "$SERVICES" | grep -E "(backend|frontend|web|api|app|nginx)" || echo "")

        # Generate docker-compose.dev.yml
        cat > "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" << EOF
# Generated by onboard-project.sh for Asus dev server
# This file adds Traefik routing for local .local domains
# Gitignored - not needed in production

services:
EOF

        # Add Traefik labels for each web service
        for SERVICE in $WEB_SERVICES; do
            # Determine subdomain (api.domain or just domain)
            if [[ "$SERVICE" =~ (api|backend) ]]; then
                SUBDOMAIN="api.$DOMAIN"
                RULE="Host(\`$DOMAIN\`) || Host(\`api.$DOMAIN\`)"
            else
                SUBDOMAIN="$DOMAIN"
                RULE="Host(\`$DOMAIN\`)"
            fi

            cat >> "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" << EOF
  $SERVICE:
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$PROJECT_NAME-$SERVICE.rule=$RULE"
      - "traefik.http.routers.$PROJECT_NAME-$SERVICE.entrypoints=web"
      - "traefik.http.services.$PROJECT_NAME-$SERVICE.loadbalancer.server.port=8000"
      - "traefik.docker.network=traefik-public"

EOF
        done

        # Add traefik-public network
        cat >> "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" << EOF
networks:
  traefik-public:
    external: true
EOF

        echo -e "${GREEN}✓ Docker configuration prepared${NC}"
        ;;

    "laravel")
        echo -e "${BLUE}ℹ️  Generating Laravel Docker stack...${NC}"

        # Copy template and replace variables
        TEMPLATE_DIR="$REPO_ROOT/templates/laravel"

        # Prepare database configuration
        DB_IMAGE="mysql:8.0"
        DB_PORT="3306"
        DB_DATA_PATH="mysql"
        DB_ENV_VARS="MYSQL_ROOT_PASSWORD: \${DB_ROOT_PASSWORD:-secret}
      MYSQL_DATABASE: \${DB_DATABASE:-${PROJECT_NAME}}
      MYSQL_USER: \${DB_USERNAME:-${PROJECT_NAME}}
      MYSQL_PASSWORD: \${DB_PASSWORD:-secret}"
        DB_HEALTHCHECK='["CMD", "mysqladmin", "ping", "-h", "localhost"]'

        # Generate docker-compose.yml
        sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            -e "s/{{DOMAIN}}/$DOMAIN/g" \
            -e "s/{{PHP_VERSION}}/$PHP_VERSION/g" \
            -e "s/{{DB_TYPE}}/$DB_TYPE/g" \
            -e "s/{{DB_IMAGE}}/$DB_IMAGE/g" \
            -e "s/{{DB_PORT}}/$DB_PORT/g" \
            -e "s/{{DB_DATA_PATH}}/$DB_DATA_PATH/g" \
            -e "s|{{DB_ENV_VARS}}|$DB_ENV_VARS|g" \
            -e "s|{{DB_HEALTHCHECK}}|$DB_HEALTHCHECK|g" \
            "$TEMPLATE_DIR/docker-compose.yml" > "$LOCAL_CONFIG_DIR/docker-compose.yml"

        # Generate Dockerfile
        sed -e "s/{{PHP_VERSION}}/$PHP_VERSION/g" \
            "$TEMPLATE_DIR/Dockerfile" > "$LOCAL_CONFIG_DIR/Dockerfile"

        # Copy Nginx configuration
        mkdir -p "$LOCAL_CONFIG_DIR/nginx/conf.d"
        cp "$TEMPLATE_DIR/nginx.conf" "$LOCAL_CONFIG_DIR/nginx/"
        cp "$TEMPLATE_DIR/laravel.conf" "$LOCAL_CONFIG_DIR/nginx/conf.d/"

        echo -e "${GREEN}✓ Laravel Docker stack generated${NC}"
        echo -e "${BLUE}  → Services: Nginx, PHP $PHP_VERSION, MySQL, Redis${NC}"
        ;;

    *)
        echo -e "${RED}✗ Unsupported project type: $PROJECT_TYPE${NC}"
        echo -e "${YELLOW}⚠️  Currently supported: Laravel, Docker Compose projects${NC}"
        exit 1
        ;;
esac

# Generate .env.example
cat > "$LOCAL_CONFIG_DIR/.env.example" << EOF
# $PROJECT_NAME - Environment Variables

# Docker Compose - Use both base and dev files on Asus
COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml

APP_ENV=production
APP_DEBUG=false
APP_URL=https://$DOMAIN

DB_CONNECTION=$DB_TYPE
DB_HOST=${PROJECT_NAME}-db
DB_PORT=$DB_PORT
DB_DATABASE=$PROJECT_NAME
DB_USERNAME=$PROJECT_NAME
DB_PASSWORD=secret
DB_ROOT_PASSWORD=secret

REDIS_HOST=${PROJECT_NAME}-redis
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOF

echo -e "${GREEN}✓ Configuration files created${NC}"
echo ""

# ============================================================================
# STEP 4: Deploy configuration to Asus
# ============================================================================
echo -e "${YELLOW}📤 Step 4: Deploying to Asus server...${NC}"

# Copy docker-compose files
scp "$LOCAL_CONFIG_DIR/docker-compose.yml" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"

# Copy docker-compose.dev.yml if it exists
if [ -f "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" ]; then
    scp "$LOCAL_CONFIG_DIR/docker-compose.dev.yml" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"

    # Add to .gitignore on server
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && grep -q 'docker-compose.dev.yml' .gitignore 2>/dev/null || echo 'docker-compose.dev.yml' >> .gitignore"
fi

# Copy additional files for Laravel
if [ "$PROJECT_TYPE" == "laravel" ]; then
    scp "$LOCAL_CONFIG_DIR/Dockerfile" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"
    scp -r "$LOCAL_CONFIG_DIR/nginx" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"
fi

# Copy .env
scp "$LOCAL_CONFIG_DIR/.env.example" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/.env"

echo -e "${GREEN}✓ Configuration deployed${NC}"
echo ""

# ============================================================================
# STEP 5: Start services
# ============================================================================
echo -e "${YELLOW}🚀 Step 5: Starting services...${NC}"

ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose up -d --build"

echo -e "${GREEN}✓ Services started${NC}"

# Laravel-specific setup (run separately)
if [ "$PROJECT_TYPE" == "laravel" ]; then
    echo -e "${YELLOW}⚙️  Running Laravel setup...${NC}"
    sleep 5  # Wait for containers to be ready

    # Install dependencies
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose exec -T app composer install --no-dev --optimize-autoloader" || true

    # Generate app key if not exists
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose exec -T app test -f .env || docker-compose exec -T app cp .env.example .env" || true
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose exec -T app php artisan key:generate --force" || true

    # Run migrations
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose exec -T app php artisan migrate --force" || echo "⚠️  Migrations failed (database might not be ready yet)"

    # Set permissions
    ssh "$ASUS_SSH_ALIAS" "cd $REMOTE_PROJECT_DIR && docker-compose exec -T app chmod -R 775 storage bootstrap/cache" || true

    echo -e "${GREEN}✓ Laravel setup complete${NC}"
fi
echo ""

# ============================================================================
# STEP 5.5: Generate INFRASTRUCTURE.md
# ============================================================================
echo -e "${YELLOW}📚 Generating infrastructure documentation...${NC}"

# Create INFRASTRUCTURE.md in local project directory
cat > "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md" <<'INFRA_EOF'
# Infrastructure Documentation

## Overview

This project runs on an Asus server (Ubuntu 22.04) using Docker + Traefik reverse proxy. This document explains the infrastructure setup so Claude Code understands the deployment architecture when working inside this project directory.

## Architecture Pattern

**Mac (Development) → Asus Server (Execution)**

- **Edit code**: On Mac using any editor
- **Auto-sync**: Files sync to Asus via `rsync`
- **Execution**: All containers, databases, and services run on Asus
- **Access**: Via Traefik reverse proxy using `.local` domains

## Access URLs

| Service | URL | Description |
|---------|-----|-------------|
| Main App | `https://DOMAIN` | Application frontend |
| API | `https://api.DOMAIN` | Backend API (if applicable) |

**Note**: Replace `DOMAIN` with your actual domain (e.g., `project.local`)

## Development Workflow

### From Mini-Server Repository

```bash
# Start development (auto-sync + rebuild + logs)
cd /path/to/mini-server
./scripts/dev.sh PROJECT_NAME

# View logs
./scripts/logs.sh PROJECT_NAME [service]

# Restart services
./scripts/projects.sh restart PROJECT_NAME

# Force rebuild after backend changes
./scripts/rebuild-on-asus.sh PROJECT_NAME [service]
```

### From This Directory

When working directly in this project directory:

```bash
# Sync changes to Asus
rsync -avz --exclude 'node_modules' --exclude '.git' \
  ./ asus-server:/opt/projects/PROJECT_NAME/

# Restart services on Asus
ssh asus-server "cd /opt/projects/PROJECT_NAME && docker-compose up -d"

# View logs
ssh asus-server "cd /opt/projects/PROJECT_NAME && docker-compose logs -f [service]"

# Rebuild specific service
ssh asus-server "cd /opt/projects/PROJECT_NAME && docker-compose build SERVICE && docker-compose up -d SERVICE"
```

## Traefik Configuration

### How Routing Works

1. **Traefik listens** on ports 80 (HTTP) and 443 (HTTPS)
2. **Docker labels** define routing rules
3. **Traefik routes** traffic based on `Host()` rules
4. **Containers** connect to `traefik-public` network
5. **SSL** handled by mkcert certificates

### Label Pattern for New Services

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=traefik-public"

  # Define service (port where container listens)
  - "traefik.http.services.{name}.loadbalancer.server.port=8000"

  # HTTP router (redirects to HTTPS)
  - "traefik.http.routers.{name}.rule=Host(`subdomain.local`)"
  - "traefik.http.routers.{name}.entrypoints=web"
  - "traefik.http.routers.{name}.service={name}"
  - "traefik.http.routers.{name}.middlewares=redirect-to-https"

  # HTTPS router (secure endpoint)
  - "traefik.http.routers.{name}-secure.rule=Host(`subdomain.local`)"
  - "traefik.http.routers.{name}-secure.entrypoints=websecure"
  - "traefik.http.routers.{name}-secure.service={name}"
  - "traefik.http.routers.{name}-secure.tls=true"

  # Middleware definition
  - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
```

### Important Rules

1. **One service per container** - Don't define multiple services for the same container
2. **Explicit service linking** - Use `.service={name}` to link routers to services
3. **traefik-public network** - All exposed services must join this network
4. **traefik.docker.network** label - Required when container is on multiple networks

## Network Architecture

```
[Mac]
  ↓ rsync
[Asus Server: 192.168.1.10]
  ↓
[Traefik :80/:443] ← TLS certificates
  ↓
  └─→ project.local → containers
```

## SSL Certificates

Certificates generated using mkcert:

```bash
# On Mac (if not already done)
brew install mkcert
mkcert -install

# From mini-server repository
./scripts/secure-local.sh
```

Certificates stored at: `/opt/traefik/certs/local-cert.pem`

## Troubleshooting

### Services Not Accessible

```bash
# Check Traefik status
ssh asus-server "docker ps | grep traefik"

# Check project services
ssh asus-server "docker ps | grep PROJECT_NAME"

# Check Traefik logs
ssh asus-server "tail -100 /opt/traefik/logs/traefik.log"

# Check Traefik dashboard
http://192.168.1.10:8080/dashboard/
```

### 404 Errors

1. Verify containers are on `traefik-public` network:
   ```bash
   ssh asus-server "docker inspect CONTAINER_NAME | jq '.[0].NetworkSettings.Networks'"
   ```

2. Check Traefik labels are correct:
   ```bash
   ssh asus-server "docker inspect CONTAINER_NAME | jq '.[0].Config.Labels'"
   ```

3. Verify routers in Traefik:
   ```bash
   curl -s http://192.168.1.10:8080/api/http/routers | jq
   ```

## SSH Configuration

Required in `~/.ssh/config`:

```
Host asus-server
    HostName 192.168.1.10
    User thang
```

## Important Notes for Claude Code

1. **Never run Docker commands locally on Mac** - All containers run on Asus
2. **Always sync before testing** - Changes must be copied to Asus to take effect
3. **Use Traefik labels** - Don't expose ports directly, route through Traefik
4. **Backend changes need rebuild** - Frontend hot-reloads, backend needs container rebuild
5. **Check Traefik logs first** - Most routing issues are visible in Traefik logs

## Parent Repository

This project is managed by the parent infrastructure repository:

```bash
/path/to/mini-server/
```

For infrastructure changes, deployment, or Traefik configuration, refer to the parent repository's documentation.
INFRA_EOF

# Replace placeholders with actual values
sed -i.bak "s|PROJECT_NAME|$PROJECT_NAME|g" "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md"
sed -i.bak "s|DOMAIN|$DOMAIN|g" "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md"
sed -i.bak "s|/path/to/mini-server|$REPO_ROOT|g" "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md"
rm -f "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md.bak"

# Copy to Asus
scp "$LOCAL_PROJECT_DIR/INFRASTRUCTURE.md" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"

echo -e "${GREEN}✓ Infrastructure documentation created${NC}"
echo ""

# ============================================================================
# STEP 6: Configure local access
# ============================================================================
echo -e "${YELLOW}🌐 Step 6: Configuring local access...${NC}"

# Add to /etc/hosts
if grep -q "$DOMAIN" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✓ $DOMAIN already in /etc/hosts${NC}"
else
    echo -e "${YELLOW}Adding $DOMAIN to /etc/hosts...${NC}"
    sudo sh -c "echo '$ASUS_HOST $DOMAIN api.$DOMAIN' >> /etc/hosts"
    echo -e "${GREEN}✓ Added to /etc/hosts${NC}"
fi

echo ""

# ============================================================================
# STEP 7: Optional SSL/HTTPS setup
# ============================================================================
echo -e "${YELLOW}🔒 Step 7: SSL/HTTPS Setup (optional)...${NC}"
echo ""
echo "Would you like to enable HTTPS for this project now?"
echo -e "${CYAN}This will:${NC}"
echo "  • Set up mkcert certificates (one-time)"
echo "  • Configure Traefik for HTTPS"
echo "  • Enable HTTP → HTTPS redirect"
echo "  • Add security headers (HSTS, etc.)"
echo ""
read -p "Enable HTTPS now? (y/n, default: n): " ENABLE_SSL

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}→ Running SSL setup...${NC}"

    # Check if secure-local.sh has been run before
    SSL_ALREADY_SETUP=$(ssh "$ASUS_SSH_ALIAS" "test -f /opt/traefik/certs/local-cert.pem && echo yes || echo no" 2>/dev/null || echo "no")

    if [ "$SSL_ALREADY_SETUP" = "no" ]; then
        echo -e "${BLUE}ℹ️  First-time SSL setup for all .local domains${NC}"
        "$SCRIPT_DIR/secure-local.sh"
    else
        echo -e "${GREEN}✓ SSL infrastructure already configured${NC}"
    fi

    # Run project-specific SSL configuration
    echo -e "${YELLOW}→ Enabling HTTPS for $PROJECT_NAME...${NC}"
    "$SCRIPT_DIR/secure.sh" "$PROJECT_NAME"

    echo -e "${GREEN}✓ HTTPS enabled for $PROJECT_NAME${NC}"
    HTTPS_ENABLED=true
else
    echo -e "${YELLOW}⏭  Skipped SSL setup${NC}"
    echo -e "${CYAN}ℹ️  You can enable HTTPS later by running:${NC}"
    echo -e "  ${YELLOW}./scripts/secure-local.sh${NC} (one-time setup)"
    echo -e "  ${YELLOW}./scripts/secure.sh $PROJECT_NAME${NC} (for this project)"
    HTTPS_ENABLED=false
fi

echo ""

# ============================================================================
# FINAL: Success message
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project $PROJECT_NAME deployed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}🎯 Access your application:${NC}"
if [ "$HTTPS_ENABLED" = true ]; then
    echo -e "  ${GREEN}https://$DOMAIN${NC} (auto-redirects from HTTP)"
    echo -e "  ${GREEN}https://api.$DOMAIN${NC} (if API exists)"
else
    echo -e "  ${GREEN}http://$DOMAIN${NC}"
    echo -e "  ${GREEN}http://api.$DOMAIN${NC} (if API exists)"
fi
echo ""
echo -e "${CYAN}📁 Files location on Asus:${NC}"
echo -e "  Code: ${BLUE}$REMOTE_SRC_DIR${NC}"
echo -e "  Config: ${BLUE}$REMOTE_PROJECT_DIR${NC}"
echo ""
echo -e "${CYAN}💻 Start coding with VS Code Remote-SSH:${NC}"
echo -e "  1. Press ${YELLOW}Cmd+Shift+P${NC}"
echo -e "  2. Select: ${YELLOW}Remote-SSH: Connect to Host${NC}"
echo -e "  3. Choose: ${YELLOW}$ASUS_SSH_ALIAS${NC}"
echo -e "  4. Open folder: ${YELLOW}$REMOTE_SRC_DIR${NC}"
echo ""

if [ "$PROJECT_TYPE" == "laravel" ]; then
    echo -e "${CYAN}🔧 Laravel Commands (on Asus):${NC}"
    echo -e "  ssh $ASUS_SSH_ALIAS 'cd $REMOTE_PROJECT_DIR && docker-compose exec app php artisan migrate'"
    echo -e "  ssh $ASUS_SSH_ALIAS 'cd $REMOTE_PROJECT_DIR && docker-compose exec app php artisan tinker'"
    echo -e "  ssh $ASUS_SSH_ALIAS 'cd $REMOTE_PROJECT_DIR && docker-compose logs -f app'"
    echo ""
fi

if [ "$HTTPS_ENABLED" != true ]; then
    echo -e "${CYAN}🔒 Enable HTTPS (optional):${NC}"
    echo -e "  ${YELLOW}./scripts/secure-local.sh${NC} (one-time infrastructure setup)"
    echo -e "  ${YELLOW}./scripts/secure.sh $PROJECT_NAME${NC} (enable for this project)"
    echo ""
fi

echo -e "${CYAN}📊 View logs:${NC}"
echo -e "  ${YELLOW}./scripts/dev.sh $PROJECT_NAME logs-only${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
