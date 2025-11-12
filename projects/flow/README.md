# Flow Project Deployment

This directory contains the deployment configuration for the Flow project on the mini-server.

## Architecture

```
Flow Stack
├── flow-web (React 18 Frontend) → http://flow.local
├── flow-api (.NET 8 Backend) → http://api.flow.local
└── flow-db (PostgreSQL 16)
```

## Prerequisites

- Flow project source code cloned to this directory
- Docker and Docker Compose installed
- Traefik reverse proxy running

## Directory Structure

```
flow/
├── docker-compose.yml       # Deployment configuration
├── .env                     # Environment variables (create from .env.example)
├── .env.example             # Template for environment variables
├── src/                     # Flow source code (clone your repo here)
│   ├── Flow.Api/
│   ├── Flow.Application/
│   ├── Flow.Domain/
│   ├── Flow.Infrastructure/
│   ├── Flow.Contracts/
│   └── flow-web/
└── README.md                # This file
```

## Setup Instructions

### 1. Clone Flow Repository

```bash
# SSH into the Asus server
ssh asus-server

# Navigate to the project directory
cd /opt/projects/flow

# Clone your Flow repository
git clone <your-flow-repo-url> src

# Or if you're using a monorepo, adjust accordingly
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the environment file
nano .env
```

**Important variables to configure:**
- `POSTGRES_PASSWORD` - Set a strong database password
- `JWT_SECRET` - Set a strong random secret (minimum 32 characters)
- `FLOW_DOMAIN` - Adjust if not using flow.local
- `FLOW_API_DOMAIN` - Adjust if not using api.flow.local

### 3. Update /etc/hosts on Your Mac

Add these lines to `/etc/hosts` on your MacBook:

```bash
<asus-server-ip> flow.local
<asus-server-ip> api.flow.local
```

### 4. Deploy Flow

```bash
# Pull latest images and build
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### 5. Run Database Migrations

```bash
# Enter the API container
docker exec -it flow-api bash

# Run migrations
dotnet ef database update

# Or if you have a custom migration command
# dotnet run --project Flow.Api -- migrate
```

## Accessing Flow

- **Frontend**: http://flow.local
- **API**: http://api.flow.local
- **API Swagger** (if enabled): http://api.flow.local/swagger

## Common Operations

### Update Flow

```bash
cd /opt/projects/flow/src
git pull origin main
cd ..
docker-compose build
docker-compose up -d
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f flow-api
docker-compose logs -f flow-web
docker-compose logs -f flow-db
```

### Restart Services

```bash
# All services
docker-compose restart

# Specific service
docker-compose restart flow-api
```

### Database Backup

```bash
# Backup
docker exec flow-db pg_dump -U flowuser flowdb > flow_backup_$(date +%Y%m%d).sql

# Restore
docker exec -i flow-db psql -U flowuser flowdb < flow_backup_20240101.sql
```

### Access Database

```bash
# Connect to PostgreSQL
docker exec -it flow-db psql -U flowuser -d flowdb
```

## Troubleshooting

### Cannot access http://flow.local

1. Check if Traefik is running: `docker ps | grep traefik`
2. Check if Flow services are running: `docker-compose ps`
3. Check Traefik logs: `docker logs traefik`
4. Verify `/etc/hosts` on your Mac
5. Check Traefik dashboard: http://traefik.local

### API cannot connect to database

1. Check if database is healthy: `docker-compose ps flow-db`
2. Check database logs: `docker-compose logs flow-db`
3. Verify connection string in `.env`
4. Check if migrations have run

### Build failures

1. Ensure source code is in `src/` directory
2. Check Docker build logs: `docker-compose build --no-cache`
3. Verify Dockerfile paths in docker-compose.yml
4. Check if .NET 8 SDK is available in the container

## Traefik Labels Explained

The docker-compose.yml includes Traefik labels that:

- **Enable Traefik**: `traefik.enable=true`
- **Set routing rules**: Based on domain names
- **Configure load balancing**: Port mapping for services
- **Apply middleware**: Security headers, compression
- **SSL/TLS**: Ready for Let's Encrypt certificates

## Production Checklist

Before deploying to production:

- [ ] Change all default passwords in `.env`
- [ ] Set strong `JWT_SECRET` (32+ characters)
- [ ] Configure SMTP for emails
- [ ] Enable HTTPS in docker-compose.yml (uncomment HTTPS labels)
- [ ] Set up database backups (cron job)
- [ ] Configure Hangfire authentication
- [ ] Review and adjust CORS settings
- [ ] Set up monitoring/alerting
- [ ] Configure proper logging
- [ ] Test disaster recovery procedures

## Notes

- Database data is persisted in Docker volume `flow-db-data`
- Traefik automatically handles routing based on domain names
- Services restart automatically unless stopped manually
- Health checks ensure services are running properly
