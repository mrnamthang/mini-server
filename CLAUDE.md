# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Infrastructure as Code (IaC) repository for running a mini-server on an Asus laptop. The architecture follows a **Mac (control) → Asus (execution)** pattern where code is edited on a MacBook Air M1 and executed on an Asus server running Ubuntu 22.04.

**Core Pattern**: Edit locally on Mac, sync automatically to Asus, run everything (Docker, databases, builds) on Asus.

## Common Development Commands

### Daily Workflow Scripts (Primary)

```bash
# Start development mode (auto-sync + smart rebuild + logs)
./scripts/dev.sh <project>

# View server/container status dashboard
./scripts/status.sh

# Manage projects (start/stop/restart/status)
./scripts/projects.sh <action> [project]

# View logs for debugging
./scripts/logs.sh <project> [service]

# Force rebuild after backend changes
./scripts/rebuild-on-asus.sh <project> [service]

# Onboard new project (first-time setup)
./scripts/onboard-project.sh
```

### Infrastructure Management (Ansible + Make)

```bash
# Initial setup (run once)
make setup              # Full setup: bootstrap + docker + traefik

# Deploy projects
make deploy-flow
make deploy-tradewhispr

# Maintenance
make restart-traefik
make logs-<project>
make ping               # Test connectivity
make status             # Show all services
```

### Configuration Files

- `.dev-config` - Development settings (ASUS_HOST, ASUS_USER, sync behavior)
- `ansible/inventory/hosts.yml` - Server inventory and connection details
- `ansible/inventory/group_vars/all.yml` - Global variables (domains, project paths)

## Architecture & Key Concepts

### Mac ↔ Asus Development Flow

1. **Edit Code**: On Mac (any editor)
2. **Auto-sync**: `dev.sh` watches files via `fswatch` and syncs with `rsync`
3. **Smart Rebuild**: Detects file type changes:
   - Frontend (`.tsx`, `.jsx`, `.vue`, `.css`) → sync only (fast)
   - Backend (`.cs`, `.py`, `requirements.txt`, `.csproj`) → sync + rebuild
4. **Auto-logs**: After rebuild, logs stream automatically

### Traefik Reverse Proxy Pattern

All projects are accessed via Traefik labels in `docker-compose.yml`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service>.rule=Host(`<project>.local`)"
  - "traefik.http.services.<service>.loadbalancer.server.port=<port>"
```

**Access Pattern**: `http://<project>.local` → Traefik (port 80) → Docker container

### Project Structure Convention

```
/opt/projects/<project>/
├── src/                    # Source code (synced from Mac)
├── docker-compose.yml      # Stack definition with Traefik labels
└── .env                    # Environment variables
```

### SSH Configuration Requirement

Scripts require `~/.ssh/config` with:

```
Host asus-server
    HostName 192.168.1.10
    User thang
```

## Important Implementation Notes

### Development Script Behavior

**`dev.sh` modes**:
- `auto` (default): Watch + sync + smart rebuild + logs
- `sync-only`: Watch + sync (no rebuild)
- `logs-only`: Only show logs (no sync)

**Smart rebuild detection** in `dev.sh`:
- Checks file extensions to determine if rebuild needed
- Batches changes with 2-second delay (prevents multiple syncs)
- Auto-starts services if not running

### Ansible Deployment Flow

1. **Bootstrap** (`01-bootstrap.yml`): Security (UFW, fail2ban), packages, directory setup
2. **Docker** (`02-docker.yml`): Install Docker Engine + Docker Compose
3. **Traefik** (`03-traefik.yml`): Setup reverse proxy with dashboard at `:8080`
4. **Deploy** (`deploy-project.yml`): Copy docker-compose.yml, create .env, start services

### Traefik Configuration Architecture

**Static config** (`traefik/traefik.yml`):
- EntryPoints: `:80` (web), `:443` (websecure), `:8080` (dashboard)
- Providers: Docker, file-based dynamic config

**Dynamic config** (docker-compose labels):
- Each project defines its own routing rules via labels
- No manual Traefik config editing needed

### Project Onboarding Process

`onboard-project.sh` auto-detects project type from `docker-compose.yml` and generates:
- Laravel → Nginx, PHP-FPM, MySQL, Redis stack
- Node.js → Node container with development server
- .NET → ASP.NET Core container with PostgreSQL
- Django → Python container with PostgreSQL

## Common Troubleshooting Patterns

### 404 Errors

Run diagnostics: `./scripts/troubleshoot-404.sh <project>`

**Common causes**:
1. Missing `/etc/hosts` entry on Mac
2. Containers not running
3. Traefik labels misconfigured
4. Traefik not running or port 80 conflict

### Services Not Starting

```bash
# Check what's running
./scripts/status.sh

# Check specific logs
./scripts/logs.sh <project>

# Restart Traefik
ssh asus-server "cd /opt/traefik && docker-compose restart"

# Rebuild project
./scripts/rebuild-on-asus.sh <project>
```

### Sync Issues

- Verify SSH connection: `ssh asus-server`
- Check `.dev-config` settings
- Ensure `fswatch` installed on Mac: `brew install fswatch`
- Check rsync excludes in script (should exclude `node_modules`, `.git`)

## Tech Stack by Project

**Flow**: .NET 8 + React 18 + PostgreSQL 16
**Tradewhispr**: FastAPI (Python 3.11) + Vue 3 + PostgreSQL 15 + Redis 7 + Celery

## File Organization Guidelines

### When Adding Scripts

- Place in `scripts/` directory
- Make executable: `chmod +x scripts/new-script.sh`
- Update `scripts/README.md` with usage documentation
- Source `.dev-config` for consistent configuration

### When Adding Ansible Playbooks

- Place in `ansible/playbooks/`
- Use descriptive names: `<order>-<purpose>.yml`
- Update `Makefile` with corresponding target
- Add variables to `ansible/inventory/group_vars/all.yml`

### When Adding Projects

- Use `./scripts/onboard-project.sh` (recommended)
- OR manually create in `projects/<name>/` with:
  - `docker-compose.yml` (with Traefik labels)
  - `.env.example` (template)
  - Update `ansible/inventory/group_vars/all.yml`

## Performance Expectations

**Sync Speed**:
- Small changes (1-10 files): < 1 second
- Medium changes (50-100 files): 2-3 seconds

**Rebuild Time**:
- Node.js: 10-30 seconds
- Python: 5-15 seconds
- .NET: 20-45 seconds

**Hot-reload**: Frontend changes via dev server are instant

## Security Notes

- SSH key-based authentication only (password auth disabled)
- UFW firewall enabled on Asus
- Fail2ban configured for brute-force protection
- Traefik dashboard accessible only on local network (`:8080`)
- `.env` files NEVER committed to git

## VSCode Integration

Pre-configured tasks available:
- `Cmd+Shift+D`: Start dev mode
- `Cmd+Shift+L`: View logs
- `Cmd+Shift+S`: Show status

Run via Command Palette: `Tasks: Run Task`
