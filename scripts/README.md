# Scripts Guide

This directory contains automation scripts for managing your Asus mini-server development workflow. Each script serves a specific purpose and can be used standalone or as part of your daily workflow.

## 🚀 Quick Start

### First Time Setup

1. **Onboard your first project:**
   ```bash
   ./onboard-project.sh
   ```
   This will prompt for sudo password **once** to setup `/opt/projects`, then guide you through cloning and deploying your project.

2. **(Optional) Make scripts globally available:**
   See [MAKE_SCRIPTS_GLOBAL.md](../MAKE_SCRIPTS_GLOBAL.md) for instructions on creating symlinks.

## 📜 Scripts Reference

### 🎯 Primary Workflow Scripts

These are the main scripts you'll use daily:

#### `onboard-project.sh` - Smart Project Onboarding
**When to use:** First time setting up a new project on the Asus server

**What it does:**
- Prompts for sudo password **once** to setup `/opt/projects` (first run only)
- Clones git repository to Asus server automatically
- Auto-detects project type (Laravel, Docker, Node.js, Django)
- Generates Docker configuration from templates
- Creates docker-compose.yml with Traefik integration
- Configures domains (project.local, api.project.local)
- Deploys and starts all services

**Usage:**
```bash
./onboard-project.sh

# Or if symlinked globally:
onboard
```

**Interactive prompts:**
- Git repository URL (e.g., `git@github.com:user/project.git`)
- Project name (auto-detected from URL)
- Domain (defaults to `<project>.local`)

**Example:**
```bash
$ ./onboard-project.sh
Git repository URL: git@github.com:mrnamthang/handover.git
Project name: handover
Domain: handover.local

✓ Cloned to /opt/projects/handover
✓ Detected Laravel project (PHP 8.2)
✓ Generated Docker stack (Nginx, PHP-FPM, MySQL, Redis)
✓ Deployed and started all services
```

**First run:** Prompts for sudo password to setup `/opt/projects`
**Subsequent runs:** No sudo password needed

---

#### `dev.sh` - Unified Development Workflow
**When to use:** Active development - edit on Mac, run on Asus

**What it does:**
- Watches local files for changes
- Auto-syncs to Asus server
- Smart rebuild detection (rebuilds only when needed)
- Shows logs in real-time
- All-in-one development experience

**Usage:**
```bash
./dev.sh <project> [mode]

# Modes:
#   auto       - Watch, sync, smart rebuild, logs (default)
#   sync-only  - Only watch and sync (no rebuild)
#   logs-only  - Only show logs (no sync)
```

**Examples:**
```bash
# Full auto mode (recommended)
./dev.sh handover

# Just sync, no rebuild
./dev.sh handover sync-only

# Just show logs
./dev.sh handover logs-only
```

**Smart rebuild logic:**
- Frontend changes (JS, CSS, HTML) → sync only
- Backend changes (PHP, Python, C#) → sync + rebuild
- Dependencies (composer.json, package.json) → sync + rebuild

---

#### `sync-to-asus.sh` - Manual Sync
**When to use:** Manual one-time sync without watching

**What it does:**
- Syncs local project to Asus server
- Uses rsync for fast incremental updates
- Excludes unnecessary files (node_modules, .git, etc.)

**Usage:**
```bash
./sync-to-asus.sh <project>
```

**Example:**
```bash
./sync-to-asus.sh handover
```

---

### 🔧 Management Scripts

#### `projects.sh` - Multi-Project Management
**When to use:** Managing multiple projects at once

**What it does:**
- Shows status of all projects
- Start/stop/restart projects
- Quick overview of running services

**Usage:**
```bash
./projects.sh [status|start|stop|restart] [project]

# Show all projects
./projects.sh status

# Restart specific project
./projects.sh restart handover

# Stop all projects
./projects.sh stop
```

---

#### `status.sh` - Server Dashboard
**When to use:** Quick health check of server and services

**What it does:**
- Server health (CPU, memory, disk usage)
- Running containers overview
- Traefik status
- Docker network info
- Resource usage per container

**Usage:**
```bash
./status.sh
```

**Example output:**
```
🖥️  Server Health
CPU Usage: 15%
Memory: 8.2GB / 16GB (51%)
Disk: 120GB / 512GB (23%)

🐳 Running Containers
handover-nginx
handover-php
handover-mysql
handover-redis
traefik

🌐 Traefik Status
✓ Running on ports 80, 443
```

---

#### `logs.sh` - View Container Logs
**When to use:** Debugging, monitoring application output

**What it does:**
- Shows last 100 lines of container logs
- Follows logs in real-time (like `tail -f`)
- Can view specific service or all services

**Usage:**
```bash
./logs.sh <project> [service]

# All services
./logs.sh handover

# Specific service
./logs.sh handover handover-php
./logs.sh handover handover-nginx
```

**Press Ctrl+C to stop following logs**

---

#### `rebuild-on-asus.sh` - Rebuild Containers
**When to use:**
- Backend code changes
- Dockerfile changes
- Dependency updates
- Configuration changes

**What it does:**
- Rebuilds Docker images on Asus
- Restarts containers
- Shows updated status

**Usage:**
```bash
./rebuild-on-asus.sh <project> [service]

# Rebuild entire project
./rebuild-on-asus.sh handover

# Rebuild specific service
./rebuild-on-asus.sh handover handover-php
```

**Not needed for:**
- Frontend hot-reload changes (automatic via dev server)
- Simple file edits (just sync)

---

### 🔐 Setup & Configuration Scripts

#### `setup-git-on-asus.sh` - Git Configuration
**When to use:** First time setting up Git on Asus server

**What it does:**
- Configures Git username and email
- Generates SSH key for GitHub/GitLab
- Displays public key to add to GitHub

**Usage:**
```bash
./setup-git-on-asus.sh
```

**Interactive prompts:**
- Your name (for git commits)
- Your email (for git commits)

**One-time setup** - Only run when setting up Asus server initially

---

#### `secure-local.sh` - Local SSL/HTTPS Setup
**When to use:** Need HTTPS for .local domains (PWA, Service Workers, etc.)

**What it does:**
- Installs mkcert (locally-trusted certificates)
- Generates wildcard certificate for *.local
- Configures Traefik for HTTPS
- Updates project docker-compose.yml for HTTPS

**Usage:**
```bash
./secure-local.sh
```

**Requirements:**
- Homebrew (Mac)
- mkcert will be installed automatically

**Result:**
- `https://handover.local` works with no browser warnings
- `https://api.handover.local` works with no browser warnings

**Optional** - Most local development works fine with HTTP

See [LOCAL_SSL_SETUP.md](../LOCAL_SSL_SETUP.md) for details

---

### 🐛 Troubleshooting Scripts

#### `troubleshoot-404.sh` - Diagnose Routing Issues
**When to use:** Getting 404 errors on .local domains

**What it does:**
- Checks if containers are running
- Verifies Traefik labels
- Tests DNS resolution (/etc/hosts)
- Validates routing configuration
- Shows detailed diagnostics

**Usage:**
```bash
./troubleshoot-404.sh <project>
```

**Example:**
```bash
./troubleshoot-404.sh handover
```

**Checks:**
1. ✓ Containers running
2. ✓ Traefik labels configured
3. ✓ /etc/hosts entry exists
4. ✓ Routing rules active
5. ✓ Network connectivity

---

## 🎯 Common Workflows

### Workflow 1: Onboarding New Project
```bash
# 1. Run onboard script (will prompt for sudo password once)
./onboard-project.sh

# Enter details:
Git repository URL: git@github.com:user/my-app.git
Project name: my-app
Domain: my-app.local

# 2. Add to /etc/hosts on Mac
sudo sh -c 'echo "192.168.1.10 my-app.local api.my-app.local" >> /etc/hosts'

# 3. Visit in browser
open http://my-app.local
```

### Workflow 2: Daily Development
```bash
# Terminal 1: Run dev workflow
./dev.sh handover

# Edit code on Mac in VS Code
# Changes auto-sync and rebuild as needed
# Logs stream in real-time

# Test in browser
open http://handover.local
```

### Workflow 3: Backend Development
```bash
# 1. Edit code on Mac
code ~/projects/handover/app/Http/Controllers/

# 2. Sync changes
./sync-to-asus.sh handover

# 3. Rebuild backend
./rebuild-on-asus.sh handover handover-php

# 4. View logs
./logs.sh handover handover-php

# 5. Test API
curl http://api.handover.local/api/users
```

### Workflow 4: Managing Multiple Projects
```bash
# Check all projects
./projects.sh status

# Restart specific project
./projects.sh restart flow

# Stop all projects
./projects.sh stop

# Start specific project
./projects.sh start handover
```

### Workflow 5: Debugging 404 Issues
```bash
# Run diagnostics
./troubleshoot-404.sh handover

# Check server status
./status.sh

# View Traefik logs
./logs.sh traefik

# Check project logs
./logs.sh handover
```

---

## 🔧 Configuration

### .dev-config File
All scripts read configuration from `.dev-config` in the repository root:

```bash
ASUS_HOST="192.168.1.10"
ASUS_USER="thang"
ASUS_SSH_ALIAS="asus-server"
REMOTE_PROJECTS_DIR="/opt/projects"
LOCAL_PROJECTS_DIR="$HOME/projects"
```

**First time:** Copy from `.dev-config.example` and customize

### SSH Configuration
Add to `~/.ssh/config`:

```
Host asus-server
    HostName 192.168.1.10
    User thang
    IdentityFile ~/.ssh/id_ed25519
```

---

## 📊 Script Comparison

| Script | Purpose | Frequency | Sudo Required | Interactive |
|--------|---------|-----------|---------------|-------------|
| onboard-project.sh | Setup new project | Once per project | First run only | Yes |
| dev.sh | Active development | Daily | No | Runs continuously |
| sync-to-asus.sh | Manual sync | As needed | No | No |
| projects.sh | Manage projects | As needed | No | No |
| status.sh | Check health | As needed | No | No |
| logs.sh | View logs | Debugging | No | Runs continuously |
| rebuild-on-asus.sh | Rebuild services | After backend changes | No | No |
| setup-git-on-asus.sh | Git setup | Once (initial setup) | On remote server | Yes |
| secure-local.sh | HTTPS setup | Optional | Local Mac only | Yes |
| troubleshoot-404.sh | Debug routing | When issues occur | No | No |

---

## 💡 Tips & Best Practices

### 1. Use tmux for Persistent Sessions
```bash
# Create new session
tmux new -s dev

# Split panes
Ctrl+b, then "    # Horizontal split
Ctrl+b, then %    # Vertical split

# Switch panes
Ctrl+b, then arrow keys

# Detach
Ctrl+b, then d

# Reattach
tmux attach -t dev
```

### 2. Create Shell Aliases
Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Quick access to scripts
alias dev-handover='~/projects/mini-server/scripts/dev.sh handover'
alias logs-handover='~/projects/mini-server/scripts/logs.sh handover'
alias sync-handover='~/projects/mini-server/scripts/sync-to-asus.sh handover'
alias rebuild-handover='~/projects/mini-server/scripts/rebuild-on-asus.sh handover'

# Global commands (if symlinked)
alias dev='dev.sh'
alias sync='sync-to-asus.sh'
alias rebuild='rebuild-on-asus.sh'
```

### 3. Typical Daily Setup
```bash
# Terminal 1: Auto-sync development
tmux new -s dev
cd ~/projects/mini-server/scripts
./dev.sh handover

# Terminal 2: Edit code
cd ~/projects/handover
code .

# Terminal 3: View logs
tmux attach -t dev
Ctrl+b "  # Split pane
./logs.sh handover
```

### 4. Global Script Access
For convenience, symlink scripts to `/usr/local/bin`:

```bash
sudo ln -s "$(pwd)/onboard-project.sh" /usr/local/bin/onboard
sudo ln -s "$(pwd)/dev.sh" /usr/local/bin/dev
sudo ln -s "$(pwd)/status.sh" /usr/local/bin/asus-status
```

Then use anywhere:
```bash
onboard           # Instead of ./onboard-project.sh
dev handover      # Instead of ./dev.sh handover
asus-status       # Instead of ./status.sh
```

See [MAKE_SCRIPTS_GLOBAL.md](../MAKE_SCRIPTS_GLOBAL.md) for details

---

## 🆘 Troubleshooting

### "Permission denied" Errors
```bash
# Make scripts executable
chmod +x *.sh
```

### "Cannot connect to server"
```bash
# Test SSH connection
ssh asus-server

# If fails, setup SSH keys
ssh-copy-id thang@192.168.1.10
```

### "sudo password required"
```bash
# Run onboard script once to setup /opt/projects
./onboard-project.sh

# This will prompt for sudo password once, then you're done
```

### 404 Errors
```bash
# Run diagnostics
./troubleshoot-404.sh handover

# Check /etc/hosts
cat /etc/hosts | grep handover

# Add if missing
sudo sh -c 'echo "192.168.1.10 handover.local api.handover.local" >> /etc/hosts'
```

### Services Not Starting
```bash
# Check server status
./status.sh

# Check project logs
./logs.sh handover

# Restart project
./projects.sh restart handover

# Rebuild if needed
./rebuild-on-asus.sh handover
```

---

## 📚 Related Documentation

- [WORKFLOW_QUICKSTART.md](../WORKFLOW_QUICKSTART.md) - Quick workflow overview
- [VALET_TO_ASUS_MIGRATION.md](../VALET_TO_ASUS_MIGRATION.md) - Laravel Valet migration guide
- [VSCODE_REMOTE_SSH.md](../VSCODE_REMOTE_SSH.md) - VS Code Remote-SSH setup
- [LOCAL_SSL_SETUP.md](../LOCAL_SSL_SETUP.md) - HTTPS setup for .local domains
- [MAKE_SCRIPTS_GLOBAL.md](../MAKE_SCRIPTS_GLOBAL.md) - Global script access

---

## 🎓 Learning Path

**Day 1: Setup**
1. Run `./setup-git-on-asus.sh` (one-time Git setup)
2. Run `./onboard-project.sh` (setup first project)
3. Add domain to `/etc/hosts` on Mac
4. Test in browser

**Day 2: Development Workflow**
1. Try `./dev.sh <project>` for auto-sync development
2. Edit code on Mac, watch it sync and rebuild
3. Use `./logs.sh <project>` to debug

**Day 3: Advanced**
1. Setup tmux for multi-pane terminal
2. Create shell aliases for common commands
3. Explore `./status.sh` and `./projects.sh`
4. Try `./secure-local.sh` for HTTPS (optional)

**Day 4: Troubleshooting**
1. Learn `./troubleshoot-404.sh` for debugging
2. Understand when to use `./rebuild-on-asus.sh`
3. Practice `./projects.sh` for multi-project management

---

Happy coding! 🚀

For questions or issues, check the troubleshooting section above or refer to the related documentation.
