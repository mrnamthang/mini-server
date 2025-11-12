# Development Workflow: Mac ↔ Asus Mini Server

This guide explains the day-to-day development workflow when using your MacBook Air M1 for code editing and the Asus server for heavy workloads.

## 🎯 Philosophy

**Mac (Light Work):**
- Code editing (VS Code, Cursor, etc.)
- Frontend hot-reload development
- Git operations
- Running lightweight dev servers

**Asus Server (Heavy Work):**
- Docker image builds
- Running production-like environments
- Database servers
- Backend API services
- Celery workers
- Python/Node.js runtime

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MacBook Air M1                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  VS Code     │  │   Browser    │  │  Terminal    │      │
│  │  (Editing)   │  │ flow.local   │  │  Git/Ansible │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         │                  │                  │              │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          │ SSH/Rsync        │ HTTP             │ SSH/Ansible
          │                  │                  │
┌─────────▼──────────────────▼──────────────────▼──────────────┐
│                    Asus Mini Server                           │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                    Traefik                            │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │    │
│  │  │ flow.local │  │tradewhispr │  │ traefik    │     │    │
│  │  └────────────┘  └────────────┘  └────────────┘     │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
│  │ Flow      │  │Tradewhispr│  │ PostgreSQL│               │
│  │ .NET + React│  │FastAPI+Vue│  │  + Redis  │               │
│  └───────────┘  └───────────┘  └───────────┘               │
└───────────────────────────────────────────────────────────────┘
```

---

## 📋 Workflow Scenarios

### Scenario 1: Frontend Development (React/Vue)

**Goal:** Edit frontend code with hot-reload while using real backend on Asus.

#### Option A: Full Development on Asus (Recommended)

```bash
# 1. On Mac: Edit code locally
cd ~/projects/flow
code .  # Open in VS Code

# 2. Sync changes to Asus in real-time
# Install fswatch on Mac if not already: brew install fswatch
fswatch -o . | while read; do
  rsync -avz --exclude 'node_modules' --exclude '.git' \
    ~/projects/flow/ asus-server:/opt/projects/flow/src/
done

# 3. On Asus: Run in development mode with hot-reload
ssh asus-server
cd /opt/projects/flow
docker-compose -f docker-compose.dev.yml up

# 4. On Mac: Access via browser
open http://flow.local
```

Your changes will:
1. Auto-sync from Mac to Asus (via rsync + fswatch)
2. Hot-reload picks up changes on Asus
3. Browser refreshes automatically

#### Option B: Frontend on Mac, Backend on Asus

```bash
# 1. On Mac: Run only the frontend
cd ~/projects/flow/src/flow-web
npm install
npm run dev  # Runs on localhost:5173

# 2. Configure frontend to use Asus backend
# Edit .env.local
VITE_API_URL=http://api.flow.local

# 3. On Mac: Access local frontend
open http://localhost:5173

# Frontend runs on Mac (port 5173)
# Backend runs on Asus (api.flow.local)
```

**Pros:**
- Fastest hot-reload (frontend on Mac)
- No network latency for frontend changes

**Cons:**
- Need to manage two environments

---

### Scenario 2: Backend Development (.NET/Python)

**Goal:** Edit backend code and test changes quickly.

#### Flow (.NET) Backend Development

```bash
# 1. On Mac: Edit code
cd ~/projects/flow
code src/Flow.Api/Controllers/ProjectsController.cs

# 2. Sync to Asus
rsync -avz --exclude 'bin' --exclude 'obj' \
  ~/projects/flow/src/ asus-server:/opt/projects/flow/src/

# 3. Rebuild and restart on Asus
ssh asus-server "cd /opt/projects/flow && docker-compose build flow-api && docker-compose restart flow-api"

# 4. Test changes
curl http://api.flow.local/api/projects

# 5. Watch logs from Mac
ssh asus-server "docker logs flow-api -f"
```

#### Tradewhispr (FastAPI) Backend Development

```bash
# 1. On Mac: Edit code
cd ~/projects/tradewhispr
code src/backend/app/api/endpoints/stocks.py

# 2. Sync to Asus
rsync -avz --exclude '__pycache__' --exclude '.pytest_cache' \
  ~/projects/tradewhispr/src/ asus-server:/opt/projects/tradewhispr/src/

# 3. Restart FastAPI (has auto-reload in dev mode)
ssh asus-server "cd /opt/projects/tradewhispr && docker-compose restart tradewhispr-backend"

# 4. Test changes
open http://api.tradewhispr.local/docs  # Swagger UI

# 5. Watch logs
ssh asus-server "docker logs tradewhispr-backend -f"
```

---

### Scenario 3: Database Operations

**Goal:** Access databases running on Asus from Mac.

#### Direct Database Connection

```bash
# 1. Create SSH tunnel from Mac
ssh -L 5432:localhost:5432 asus-server  # Flow PostgreSQL
ssh -L 5433:localhost:5432 asus-server  # Tradewhispr PostgreSQL

# 2. Connect with local tools
# Using psql
psql -h localhost -p 5432 -U flowuser -d flowdb

# Using GUI tools (DBeaver, Postico, DataGrip)
Host: localhost
Port: 5432
User: flowuser
Database: flowdb
Password: (from .env)
```

#### Run Migrations from Mac

```bash
# Flow migrations
ssh asus-server "docker exec flow-api dotnet ef migrations add NewMigration"
ssh asus-server "docker exec flow-api dotnet ef database update"

# Tradewhispr migrations
ssh asus-server "docker exec tradewhispr-backend alembic revision --autogenerate -m 'new migration'"
ssh asus-server "docker exec tradewhispr-backend alembic upgrade head"
```

---

### Scenario 4: Docker Build Offloading

**Goal:** Build Docker images on Asus (powerful) instead of Mac (limited).

#### Method 1: Docker Context (Simplest)

```bash
# One-time setup on Mac
docker context create asus \
  --docker "host=ssh://your-username@asus-server-ip"

# Switch to Asus context
docker context use asus

# Now all docker commands run on Asus!
docker build -t myapp:latest .
docker images
docker ps

# Switch back to local
docker context use default
```

#### Method 2: Remote Docker Buildx

```bash
# One-time setup on Mac
docker buildx create --name asus-builder \
  --platform linux/amd64,linux/arm64 \
  --driver docker-container \
  ssh://your-username@asus-server-ip

docker buildx use asus-builder

# Build multi-platform images on Asus
cd ~/projects/flow
docker buildx build --platform linux/amd64 -t flow-api:latest . --load

# Build and push to registry
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/yourusername/flow-api:latest . --push
```

#### Method 3: Build via Ansible

```bash
# From Mac, trigger build on Asus
make deploy-flow  # Builds and deploys

# Or manually
ansible mini_servers -i ansible/inventory/hosts.yml \
  -m shell -a "cd /opt/projects/flow && docker-compose build" -b
```

---

### Scenario 5: Full Development Workflow

**Goal:** Typical day of development across both machines.

#### Morning: Start Development

```bash
# 1. On Mac: Check server status
make status

# 2. On Mac: Pull latest code
cd ~/projects/flow
git pull origin main

# 3. On Mac: Sync to Asus
./scripts/sync-to-asus.sh  # We'll create this script

# 4. On Mac: Open project
code .

# 5. On Mac: View logs in split terminal
tmux new-session -s dev
# Split window
tmux split-window -v
# In second pane: ssh asus-server "docker logs flow-api -f"
```

#### During Development: Make Changes

```bash
# 1. Edit code on Mac (VS Code)
# File: src/Flow.Api/Controllers/ProjectsController.cs

# 2. Auto-sync watches for changes
# Or manually sync
./scripts/sync-to-asus.sh

# 3. Rebuild on Asus
ssh asus-server "cd /opt/projects/flow && docker-compose build flow-api && docker-compose up -d"

# 4. Test in browser
open http://flow.local

# 5. Check logs
ssh asus-server "docker logs flow-api --tail=50 -f"
```

#### End of Day: Commit and Deploy

```bash
# 1. Run tests on Asus
ssh asus-server "cd /opt/projects/flow/src && docker-compose run --rm flow-api dotnet test"

# 2. On Mac: Commit changes
git add .
git commit -m "Add new project filtering feature"
git push origin feature/project-filters

# 3. Deploy to "production" on Asus
make deploy-flow
```

---

## 🔧 Development Scripts

Let me create some helper scripts to streamline your workflow.

### Auto-Sync Script

**File: `scripts/sync-to-asus.sh`**

```bash
#!/bin/bash
# Sync local changes to Asus server

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo "Usage: ./sync-to-asus.sh [flow|tradewhispr]"
    exit 1
fi

ASUS_HOST="asus-server"  # Update with your server hostname/IP
LOCAL_DIR="$HOME/projects/$PROJECT"
REMOTE_DIR="/opt/projects/$PROJECT/src"

# Rsync with exclusions
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude 'bin' \
  --exclude 'obj' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude 'venv' \
  --exclude '.env' \
  "$LOCAL_DIR/" "$ASUS_HOST:$REMOTE_DIR/"

echo "✅ Synced $PROJECT to Asus server"
```

### Auto-Watch Script

**File: `scripts/watch-and-sync.sh`**

```bash
#!/bin/bash
# Watch for changes and auto-sync

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo "Usage: ./watch-and-sync.sh [flow|tradewhispr]"
    exit 1
fi

LOCAL_DIR="$HOME/projects/$PROJECT"

echo "👀 Watching $LOCAL_DIR for changes..."
echo "Press Ctrl+C to stop"

fswatch -o "$LOCAL_DIR" | while read change; do
    echo "🔄 Change detected, syncing..."
    ./scripts/sync-to-asus.sh "$PROJECT"
done
```

### Quick Rebuild Script

**File: `scripts/rebuild-on-asus.sh`**

```bash
#!/bin/bash
# Rebuild and restart service on Asus

PROJECT=$1
SERVICE=$2

if [ -z "$PROJECT" ] || [ -z "$SERVICE" ]; then
    echo "Usage: ./rebuild-on-asus.sh [flow|tradewhispr] [service-name]"
    echo "Examples:"
    echo "  ./rebuild-on-asus.sh flow flow-api"
    echo "  ./rebuild-on-asus.sh tradewhispr tradewhispr-backend"
    exit 1
fi

ASUS_HOST="asus-server"

echo "🔨 Building $SERVICE..."
ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose build $SERVICE"

echo "🔄 Restarting $SERVICE..."
ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose up -d $SERVICE"

echo "📋 Service status:"
ssh "$ASUS_HOST" "docker ps --filter name=$SERVICE"

echo "✅ Done! View logs with: ssh $ASUS_HOST 'docker logs $SERVICE -f'"
```

### Logs Viewer Script

**File: `scripts/logs.sh`**

```bash
#!/bin/bash
# View logs from Asus server

PROJECT=$1
SERVICE=$2

if [ -z "$PROJECT" ]; then
    echo "Usage: ./logs.sh [flow|tradewhispr] [service-name]"
    echo "Examples:"
    echo "  ./logs.sh flow flow-api"
    echo "  ./logs.sh tradewhispr tradewhispr-backend"
    exit 1
fi

ASUS_HOST="asus-server"

if [ -z "$SERVICE" ]; then
    # Show all project logs
    ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose logs -f --tail=100"
else
    # Show specific service logs
    ssh "$ASUS_HOST" "cd /opt/projects/$PROJECT && docker-compose logs -f --tail=100 $SERVICE"
fi
```

---

## 🚀 Recommended Daily Workflow

### Morning Routine

```bash
# 1. Check server health
make status

# 2. Pull latest code
cd ~/projects/flow && git pull
cd ~/projects/tradewhispr && git pull

# 3. Start auto-sync (in background terminal)
./scripts/watch-and-sync.sh flow &
./scripts/watch-and-sync.sh tradewhispr &

# 4. Open projects in editor
code ~/projects/flow
code ~/projects/tradewhispr

# 5. Access services
open http://flow.local
open http://tradewhispr.local
open http://traefik.local  # Dashboard
```

### Development Loop

```bash
# Edit code on Mac → Auto-syncs to Asus → Hot-reload on Asus → View in browser

# If backend changes (requires rebuild):
./scripts/rebuild-on-asus.sh flow flow-api

# View logs
./scripts/logs.sh flow flow-api
```

### Testing

```bash
# Run tests on Asus
ssh asus-server "cd /opt/projects/flow/src && dotnet test"
ssh asus-server "cd /opt/projects/tradewhispr/src/backend && pytest"

# Run specific test
ssh asus-server "docker exec flow-api dotnet test --filter 'ProjectsControllerTests'"
```

### Deployment

```bash
# Deploy to "production" on Asus
make deploy-flow
make deploy-tradewhispr

# Or deploy both
make deploy-all

# View deployment status
make status
```

---

## 🛠️ VS Code Setup

### Recommended Extensions

```json
// .vscode/extensions.json
{
  "recommendations": [
    "ms-vscode-remote.remote-ssh",      // Edit files directly on Asus
    "ms-azuretools.vscode-docker",      // Docker support
    "github.copilot",                   // AI assistance
    "esbenp.prettier-vscode",           // Code formatting
    "dbaeumer.vscode-eslint"            // Linting
  ]
}
```

### Remote Development (Optional)

You can edit files directly on Asus via SSH:

```bash
# In VS Code
# 1. Install "Remote - SSH" extension
# 2. Press Cmd+Shift+P → "Remote-SSH: Connect to Host"
# 3. Enter: asus-server
# 4. Open folder: /opt/projects/flow/src

# Now you're editing directly on Asus!
# Changes are instant, no sync needed
```

### Tasks Configuration

**File: `.vscode/tasks.json`**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Sync to Asus",
      "type": "shell",
      "command": "./scripts/sync-to-asus.sh flow",
      "problemMatcher": [],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    },
    {
      "label": "Rebuild on Asus",
      "type": "shell",
      "command": "./scripts/rebuild-on-asus.sh flow flow-api",
      "problemMatcher": []
    },
    {
      "label": "View Logs",
      "type": "shell",
      "command": "./scripts/logs.sh flow flow-api",
      "problemMatcher": []
    }
  ]
}
```

Now you can:
- Press `Cmd+Shift+B` to sync
- Use Command Palette to run tasks

---

## 📊 Monitoring & Debugging

### View All Service Status

```bash
# From Mac
make status

# Or directly
ssh asus-server "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### Monitor Resource Usage

```bash
# CPU, Memory, Network
ssh asus-server "docker stats"

# Disk usage
ssh asus-server "df -h"
ssh asus-server "docker system df"
```

### Access Container Shell

```bash
# Flow API
ssh asus-server "docker exec -it flow-api bash"

# Tradewhispr Backend
ssh asus-server "docker exec -it tradewhispr-backend bash"

# Database
ssh asus-server "docker exec -it flow-db psql -U flowuser -d flowdb"
```

### Debugging

```bash
# 1. Check container logs
./scripts/logs.sh flow flow-api

# 2. Check container inspect
ssh asus-server "docker inspect flow-api"

# 3. Check network connectivity
ssh asus-server "docker exec flow-api ping flow-db"

# 4. Check environment variables
ssh asus-server "docker exec flow-api env"
```

---

## 🎯 Performance Tips

### 1. Use Persistent SSH Connections

Add to `~/.ssh/config` on Mac:

```ssh-config
Host asus-server
    HostName 192.168.1.100
    User your-username
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 60
    Compression yes
```

Benefits:
- Faster SSH connections (reuses existing connection)
- Less overhead for rsync/scripts

### 2. Use Incremental Sync

Rsync only syncs changed files - very fast for small edits.

### 3. Keep Frontend on Mac for Hot-Reload

If hot-reload is slow over network, run frontend locally and only backend on Asus.

### 4. Use Docker BuildKit

Already enabled in the setup - much faster builds with caching.

---

## 🔐 Security Best Practices

### 1. Use SSH Keys (Already Configured)

```bash
# Verify SSH key is used
ssh -v asus-server 2>&1 | grep "Authentication"
```

### 2. Don't Commit Secrets

```bash
# Ensure .env is gitignored
echo ".env" >> .gitignore
```

### 3. Use Environment Variables

Never hardcode passwords/secrets in code - always use .env files.

### 4. Regular Backups

```bash
# Automated daily backup
make backup-all

# Or manual
ssh asus-server "docker exec flow-db pg_dump -U flowuser flowdb > /opt/backups/flow_$(date +%Y%m%d).sql"
```

---

## 🔄 Git Workflow Integration

### Feature Development

```bash
# 1. On Mac: Create feature branch
cd ~/projects/flow
git checkout -b feature/new-feature

# 2. Develop with auto-sync to Asus
./scripts/watch-and-sync.sh flow &

# 3. Test on Asus environment
open http://flow.local

# 4. Commit when done
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# 5. Deploy to test on Asus
make deploy-flow
```

### Code Review

```bash
# Reviewer can test on their own Asus setup
git checkout feature/new-feature
./scripts/sync-to-asus.sh flow
make deploy-flow
open http://flow.local
```

---

## 📱 Mobile Testing

Test on your phone/tablet while on same network:

```bash
# 1. Ensure your phone is on same Wi-Fi
# 2. Access via Asus server IP:
http://192.168.1.100  # Traefik will route based on Host header

# Or setup mDNS (avahi)
ssh asus-server "sudo apt install avahi-daemon"
# Access via: http://asus-mini-server.local
```

---

## 🚨 Troubleshooting Common Issues

### Changes not reflecting

```bash
# 1. Verify sync
./scripts/sync-to-asus.sh flow

# 2. Check if watching is running
ps aux | grep fswatch

# 3. Force rebuild
./scripts/rebuild-on-asus.sh flow flow-api

# 4. Clear browser cache
# Cmd+Shift+R (hard refresh)
```

### Can't connect to service

```bash
# 1. Check service is running
make status

# 2. Check Traefik routing
open http://traefik.local

# 3. Check /etc/hosts
cat /etc/hosts | grep flow.local

# 4. Test direct access
curl -v http://192.168.1.100 -H "Host: flow.local"
```

### Slow performance

```bash
# 1. Check Asus resources
ssh asus-server "htop"

# 2. Check Docker resources
ssh asus-server "docker stats"

# 3. Clean up Docker
make clean-docker

# 4. Restart services
make restart-flow
```

---

## 📈 Next Level: CI/CD Integration

### GitHub Actions + Asus Server

```yaml
# .github/workflows/deploy.yml
name: Deploy to Asus Server

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Asus
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.ASUS_SERVER_IP }}
          username: ${{ secrets.ASUS_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/projects/flow
            git pull origin main
            docker-compose build
            docker-compose up -d
```

---

## 💡 Pro Tips

1. **Use tmux on Mac** for persistent terminal sessions
2. **Create aliases** for common commands in `~/.zshrc`
3. **Use VS Code Remote-SSH** for direct editing on Asus
4. **Setup Tailscale** for remote development when away from home
5. **Use Docker Compose profiles** for dev vs prod environments
6. **Monitor with Portainer** for visual Docker management
7. **Use ngrok/Tailscale** to share your work with others

---

## 🎓 Summary

**Daily Workflow:**
1. Edit code on Mac (VS Code)
2. Auto-sync to Asus (fswatch + rsync)
3. Services run on Asus (Docker)
4. View in browser on Mac (via Traefik)
5. Monitor logs via SSH
6. Commit and push when done
7. Deploy updates via Ansible

**Key Benefits:**
- Mac stays cool and fast ⚡
- Asus handles heavy lifting 💪
- Real-time sync keeps them in sync 🔄
- Production-like environment 🏗️
- Easy deployment automation 🚀

Ready to code! 🎉
