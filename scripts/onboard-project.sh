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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"

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
REMOTE_SRC_DIR="$REMOTE_PROJECT_DIR/src"

echo ""
echo -e "${YELLOW}📋 Project Configuration:${NC}"
echo "  Name: $PROJECT_NAME"
echo "  Domain: $DOMAIN"
echo "  Git Repo: ${GIT_REPO:-Manual deployment}"
echo "  Remote Path: $REMOTE_SRC_DIR"
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
        # Create directory (now in /opt/projects which user owns)
        mkdir -p $REMOTE_PROJECT_DIR

        # Clone repository
        if [ -d "$REMOTE_SRC_DIR" ]; then
            echo "Directory exists, pulling latest changes..."
            cd $REMOTE_SRC_DIR
            git pull
        else
            git clone $GIT_REPO $REMOTE_SRC_DIR
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

    ssh "$ASUS_SSH_ALIAS" "mkdir -p $REMOTE_SRC_DIR"

    rsync -az --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude 'vendor' \
        --exclude 'bin' \
        --exclude 'obj' \
        --exclude '__pycache__' \
        --exclude '.env' \
        "$GIT_REPO/" "$ASUS_USER@$ASUS_HOST:$REMOTE_SRC_DIR/"

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

# Get file list from Asus
FILES=$(ssh "$ASUS_SSH_ALIAS" "ls -1 $REMOTE_SRC_DIR" 2>/dev/null || echo "")

# Detect tech stack
HAS_DOCKER_COMPOSE=$(echo "$FILES" | grep -E "^docker-compose\.ya?ml$" && echo "yes" || echo "")
HAS_COMPOSER=$(echo "$FILES" | grep "^composer.json$" && echo "yes" || echo "")
HAS_ARTISAN=$(ssh "$ASUS_SSH_ALIAS" "test -f $REMOTE_SRC_DIR/artisan && echo yes" || echo "")
HAS_PACKAGE_JSON=$(echo "$FILES" | grep "^package.json$" && echo "yes" || echo "")
HAS_REQUIREMENTS=$(echo "$FILES" | grep "^requirements.txt$" && echo "")
HAS_MANAGE_PY=$(echo "$FILES" | grep "^manage.py$" && echo "yes" || echo "")

# Determine project type
PROJECT_TYPE=""

if [ -n "$HAS_DOCKER_COMPOSE" ]; then
    PROJECT_TYPE="docker-existing"
    echo -e "${GREEN}✓ Found existing docker-compose.yml${NC}"
elif [ -n "$HAS_COMPOSER" ] && [ -n "$HAS_ARTISAN" ]; then
    PROJECT_TYPE="laravel"
    echo -e "${GREEN}✓ Detected Laravel project${NC}"

    # Detect PHP version from composer.json
    PHP_VERSION=$(ssh "$ASUS_SSH_ALIAS" "cat $REMOTE_SRC_DIR/composer.json 2>/dev/null | grep -oP '\"php\":\s*\"\^?\K[0-9]+\.[0-9]+'" || echo "8.2")
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

LOCAL_CONFIG_DIR="$SCRIPT_DIR/../projects/$PROJECT_NAME"
mkdir -p "$LOCAL_CONFIG_DIR"

case $PROJECT_TYPE in
    "docker-existing")
        echo -e "${BLUE}ℹ️  Using existing docker-compose.yml${NC}"

        # Download existing compose file
        scp "$ASUS_USER@$ASUS_HOST:$REMOTE_SRC_DIR/docker-compose.yml" "$LOCAL_CONFIG_DIR/docker-compose.original.yml"
        cp "$LOCAL_CONFIG_DIR/docker-compose.original.yml" "$LOCAL_CONFIG_DIR/docker-compose.yml"

        # Add Traefik network if not present
        if ! grep -q "traefik-public" "$LOCAL_CONFIG_DIR/docker-compose.yml"; then
            echo "" >> "$LOCAL_CONFIG_DIR/docker-compose.yml"
            echo "# Added by onboard-project.sh" >> "$LOCAL_CONFIG_DIR/docker-compose.yml"
            echo "networks:" >> "$LOCAL_CONFIG_DIR/docker-compose.yml"
            echo "  traefik-public:" >> "$LOCAL_CONFIG_DIR/docker-compose.yml"
            echo "    external: true" >> "$LOCAL_CONFIG_DIR/docker-compose.yml"
        fi

        echo -e "${GREEN}✓ Docker configuration copied${NC}"
        ;;

    "laravel")
        echo -e "${BLUE}ℹ️  Generating Laravel Docker stack...${NC}"

        # Copy template and replace variables
        TEMPLATE_DIR="$SCRIPT_DIR/../templates/laravel"

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

# Copy docker-compose.yml
scp "$LOCAL_CONFIG_DIR/docker-compose.yml" "$ASUS_USER@$ASUS_HOST:$REMOTE_PROJECT_DIR/"

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

ssh "$ASUS_SSH_ALIAS" << EOF
    cd $REMOTE_PROJECT_DIR

    # Start services
    docker-compose up -d --build

    # Laravel-specific setup
    if [ "$PROJECT_TYPE" == "laravel" ]; then
        echo "Running Laravel setup..."
        sleep 5  # Wait for containers to be ready

        # Install dependencies
        docker-compose exec -T app composer install --no-dev --optimize-autoloader

        # Generate app key if not exists
        if ! docker-compose exec -T app test -f .env; then
            docker-compose exec -T app cp .env.example .env || true
        fi

        docker-compose exec -T app php artisan key:generate --force || true

        # Run migrations
        docker-compose exec -T app php artisan migrate --force || echo "⚠️  Migrations failed (database might not be ready yet)"

        # Set permissions
        docker-compose exec -T app chmod -R 775 storage bootstrap/cache || true
    fi
EOF

echo -e "${GREEN}✓ Services started${NC}"
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
# FINAL: Success message
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project $PROJECT_NAME deployed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}🎯 Access your application:${NC}"
echo -e "  ${GREEN}http://$DOMAIN${NC}"
echo -e "  ${GREEN}http://api.$DOMAIN${NC} (if API exists)"
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

echo -e "${CYAN}🔒 Enable HTTPS:${NC}"
echo -e "  Run: ${YELLOW}./scripts/secure-local.sh${NC} (one-time setup for all projects)"
echo ""
echo -e "${CYAN}📊 View logs:${NC}"
echo -e "  ${YELLOW}./scripts/dev.sh $PROJECT_NAME logs-only${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
