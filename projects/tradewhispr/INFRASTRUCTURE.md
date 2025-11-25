# TradeWhispr Infrastructure Documentation

## Overview

TradeWhispr runs on an Asus server (Ubuntu 22.04) using Docker + Traefik reverse proxy. This document explains the infrastructure setup so Claude Code understands the deployment architecture when working inside this project directory.

## Architecture Pattern

**Mac (Development) → Asus Server (Execution)**

- **Edit code**: On Mac using any editor
- **Auto-sync**: Files sync to Asus via `rsync`
- **Execution**: All containers, databases, and services run on Asus
- **Access**: Via Traefik reverse proxy using `.local` domains

## Access URLs

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | `https://tradewhispr.local` | Vue 3 + Vite dev server |
| Backend API | `https://api.tradewhispr.local` | FastAPI with Swagger docs at `/docs` |
| API Docs | `https://api.tradewhispr.local/docs` | Interactive API documentation |

## Tech Stack

- **Frontend**: Vue 3 (Composition API) + TypeScript + Vite
- **Backend**: FastAPI (Python 3.11) + SQLAlchemy
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Worker**: Celery (async tasks)
- **Reverse Proxy**: Traefik v2.11
- **SSL**: mkcert (local trusted certificates)

## Docker Compose Services

```yaml
services:
  db              # PostgreSQL 15 (port 5433 externally)
  redis           # Redis 7 (port 6380 externally)
  backend         # FastAPI on port 8000 (via Traefik)
  celery_worker   # Background task processor
  frontend-dev    # Vite dev server on port 5173 (via Traefik)
```

## Traefik Configuration

### How Routing Works

1. **Traefik listens** on ports 80 (HTTP) and 443 (HTTPS)
2. **Docker labels** define routing rules
3. **Traefik routes** traffic based on `Host()` rules
4. **Containers** connect to `traefik-public` network
5. **SSL** handled by mkcert certificates

### Label Pattern

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
```

### Important Rules

1. **One service per container** - Don't define multiple services for the same container
2. **Explicit service linking** - Use `.service={name}` to link routers to services
3. **traefik-public network** - All exposed services must join this network
4. **traefik.docker.network** label - Required when container is on multiple networks

## Development Workflow

### From Mini-Server Repository

```bash
# Start development (auto-sync + rebuild + logs)
cd /Users/thang/projects/mini-server
./scripts/dev.sh tradewhispr

# View logs
./scripts/logs.sh tradewhispr [service]

# Restart services
./scripts/projects.sh restart tradewhispr

# Force rebuild after backend changes
./scripts/rebuild-on-asus.sh tradewhispr backend
```

### From This Directory

When working directly in `/Users/thang/projects/mini-server/projects/tradewhispr/`:

```bash
# Sync changes to Asus
rsync -avz --exclude 'node_modules' --exclude '.git' \
  ./ asus-server:/opt/projects/tradewhispr/

# Restart services on Asus
ssh asus-server "cd /opt/projects/tradewhispr && docker-compose --profile dev up -d"

# View logs
ssh asus-server "cd /opt/projects/tradewhispr && docker-compose logs -f [service]"

# Rebuild specific service
ssh asus-server "cd /opt/projects/tradewhispr && docker-compose build backend && docker-compose up -d backend"
```

## Environment Variables

Located in `.env` (not committed to git):

```bash
# Database
POSTGRES_USER=tradewhispr
POSTGRES_PASSWORD=<secret>
POSTGRES_DB=tradewhispr

# Backend
SECRET_KEY=<secret>
DEBUG=true

# API URL for frontend
VITE_API_BASE_URL=https://api.tradewhispr.local
```

## Network Architecture

```
[Mac]
  ↓ rsync
[Asus Server: 192.168.1.10]
  ↓
[Traefik :80/:443] ← TLS certificates
  ↓
  ├─→ tradewhispr.local → frontend-dev:5173
  └─→ api.tradewhispr.local → backend:8000
      ↓
      ├─→ PostgreSQL :5432 (internal)
      └─→ Redis :6379 (internal)
```

## SSL Certificates

### Setup (Already Done)

Certificates generated using mkcert:

```bash
# On Mac
brew install mkcert
mkcert -install

# Certificates stored
/opt/traefik/certs/local-cert.pem
/opt/traefik/certs/local-key.pem
```

### Regenerate Certificates

```bash
cd /Users/thang/projects/mini-server
./scripts/secure-local.sh
```

## Troubleshooting

### Services Not Accessible

```bash
# Check Traefik status
ssh asus-server "docker ps | grep traefik"

# Check TradeWhispr services
ssh asus-server "docker ps | grep tradewhispr"

# Check Traefik logs
ssh asus-server "docker logs traefik" 2>&1 | tail -50

# Check Traefik dashboard
http://192.168.1.10:8080/dashboard/
```

### 404 Errors

1. Verify containers are on `traefik-public` network:
   ```bash
   ssh asus-server "docker inspect tradewhispr-backend | jq '.[0].NetworkSettings.Networks'"
   ```

2. Check Traefik labels are correct:
   ```bash
   ssh asus-server "docker inspect tradewhispr-backend | jq '.[0].Config.Labels'"
   ```

3. Verify routers in Traefik:
   ```bash
   curl -s http://192.168.1.10:8080/api/http/routers | jq '.[] | select(.name | contains("tradewhispr"))'
   ```

### Database Connection Issues

```bash
# Connect to PostgreSQL from Asus
ssh asus-server "docker exec -it tradewhispr-db psql -U tradewhispr"

# Check database logs
ssh asus-server "docker logs tradewhispr-db"
```

### Frontend Not Loading

```bash
# Check Vite dev server logs
ssh asus-server "docker logs tradewhispr-frontend-dev"

# Verify API URL environment variable
ssh asus-server "docker exec tradewhispr-frontend-dev env | grep VITE"
```

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service definitions + Traefik labels |
| `.env` | Environment variables (not in git) |
| `backend/Dockerfile` | FastAPI container build |
| `frontend/Dockerfile` | Production Nginx container |
| `/opt/traefik/traefik.yml` | Traefik static config (on Asus) |
| `/opt/traefik/certs/` | SSL certificates (on Asus) |

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
5. **Check Traefik logs first** - Most routing issues are visible in Traefik logs at `/opt/traefik/logs/traefik.log`

## Parent Repository

This project is managed by the parent infrastructure repository:

```bash
/Users/thang/projects/mini-server/
```

For infrastructure changes, deployment, or Traefik configuration, refer to the parent repository's documentation.
