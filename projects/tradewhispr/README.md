# Tradewhispr Project Deployment

This directory contains the deployment configuration for the Tradewhispr project on the mini-server.

## Architecture

```
Tradewhispr Stack
├── tradewhispr-frontend (Vue 3) → http://tradewhispr.local
├── tradewhispr-backend (FastAPI) → http://api.tradewhispr.local
├── tradewhispr-celery-worker (Background tasks)
├── tradewhispr-db (PostgreSQL 15)
└── tradewhispr-redis (Redis 7)
```

## Prerequisites

- Tradewhispr project source code cloned to this directory
- Docker and Docker Compose installed
- Traefik reverse proxy running

## Directory Structure

```
tradewhispr/
├── docker-compose.yml       # Deployment configuration
├── .env                     # Environment variables (create from .env.example)
├── .env.example             # Template for environment variables
├── src/                     # Tradewhispr source code (clone your repo here)
│   ├── backend/             # FastAPI backend
│   └── frontend/            # Vue 3 frontend
└── README.md                # This file
```

## Setup Instructions

### 1. Clone Tradewhispr Repository

```bash
# SSH into the Asus server
ssh asus-server

# Navigate to the project directory
cd /opt/projects/tradewhispr

# Clone your Tradewhispr repository
git clone <your-tradewhispr-repo-url> src

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
- `SECRET_KEY` - Set a strong random secret (minimum 32 characters)
- `TRADEWHISPR_DOMAIN` - Adjust if not using tradewhispr.local
- `TRADEWHISPR_API_DOMAIN` - Adjust if not using api.tradewhispr.local
- `CORS_ORIGINS` - Update with your frontend domain

### 3. Update /etc/hosts on Your Mac

Add these lines to `/etc/hosts` on your MacBook:

```bash
<asus-server-ip> tradewhispr.local
<asus-server-ip> api.tradewhispr.local
```

### 4. Deploy Tradewhispr

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
# Enter the backend container
docker exec -it tradewhispr-backend bash

# Run Alembic migrations
alembic upgrade head

# Exit the container
exit
```

## Accessing Tradewhispr

- **Frontend**: http://tradewhispr.local
- **API**: http://api.tradewhispr.local
- **API Docs**: http://api.tradewhispr.local/docs (FastAPI Swagger UI)
- **ReDoc**: http://api.tradewhispr.local/redoc

## Common Operations

### Update Tradewhispr

```bash
cd /opt/projects/tradewhispr/src
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
docker-compose logs -f tradewhispr-backend
docker-compose logs -f tradewhispr-frontend
docker-compose logs -f tradewhispr-celery-worker
docker-compose logs -f tradewhispr-db
docker-compose logs -f tradewhispr-redis
```

### Restart Services

```bash
# All services
docker-compose restart

# Specific service
docker-compose restart tradewhispr-backend
docker-compose restart tradewhispr-celery-worker
```

### Database Backup

```bash
# Backup
docker exec tradewhispr-db pg_dump -U tradewhispruser tradewhisprdb > tradewhispr_backup_$(date +%Y%m%d).sql

# Restore
docker exec -i tradewhispr-db psql -U tradewhispruser tradewhisprdb < tradewhispr_backup_20240101.sql
```

### Access Database

```bash
# Connect to PostgreSQL
docker exec -it tradewhispr-db psql -U tradewhispruser -d tradewhisprdb
```

### Monitor Celery Tasks

```bash
# View Celery worker logs
docker-compose logs -f tradewhispr-celery-worker

# Enter Celery container and inspect
docker exec -it tradewhispr-celery-worker bash
celery -A app.celery inspect active
celery -A app.celery inspect stats
```

### Access Redis

```bash
# Connect to Redis CLI
docker exec -it tradewhispr-redis redis-cli

# Check Redis keys
> KEYS *
> GET key-name
> MONITOR  # Watch all Redis commands in real-time
```

## Celery Background Tasks

The Celery worker handles background tasks such as:
- Stock data fetching from vnstock
- Data processing and analysis
- Scheduled tasks (periodic data updates)
- Email notifications
- Report generation

### Monitor Celery

```bash
# Check active tasks
docker exec tradewhispr-celery-worker celery -A app.celery inspect active

# Check registered tasks
docker exec tradewhispr-celery-worker celery -A app.celery inspect registered

# Purge all tasks
docker exec tradewhispr-celery-worker celery -A app.celery purge
```

## Troubleshooting

### Cannot access http://tradewhispr.local

1. Check if Traefik is running: `docker ps | grep traefik`
2. Check if Tradewhispr services are running: `docker-compose ps`
3. Check Traefik logs: `docker logs traefik`
4. Verify `/etc/hosts` on your Mac
5. Check Traefik dashboard: http://traefik.local

### Backend cannot connect to database

1. Check if database is healthy: `docker-compose ps tradewhispr-db`
2. Check database logs: `docker-compose logs tradewhispr-db`
3. Verify DATABASE_URL in `.env`
4. Check if migrations have run: `docker exec -it tradewhispr-backend alembic current`

### Celery worker not processing tasks

1. Check Celery logs: `docker-compose logs tradewhispr-celery-worker`
2. Check Redis connection: `docker-compose logs tradewhispr-redis`
3. Verify CELERY_BROKER_URL in environment
4. Restart Celery worker: `docker-compose restart tradewhispr-celery-worker`

### Build failures

1. Ensure source code is in `src/` directory
2. Check Docker build logs: `docker-compose build --no-cache`
3. Verify Dockerfile paths in docker-compose.yml
4. Check Python/Node.js versions in Dockerfiles

### CORS errors in browser

1. Check CORS_ORIGINS in `.env`
2. Ensure it matches your frontend domain exactly
3. Restart backend: `docker-compose restart tradewhispr-backend`

## Services Explained

### Backend (FastAPI)
- Python 3.11 ASGI application
- SQLModel ORM with PostgreSQL
- JWT authentication
- Vietnamese stock market data integration (vnstock)
- RESTful API with automatic OpenAPI docs

### Frontend (Vue 3 + TypeScript)
- Vue 3 Composition API
- Pinia state management
- TailwindCSS styling
- Vite build tool
- Production build served by Nginx

### Celery Worker
- Asynchronous task processing
- Redis as message broker
- Periodic tasks for data updates
- Background job processing

### PostgreSQL 15
- Primary data store
- Persistent volume for data
- Connection pooling via SQLModel

### Redis 7
- Celery message broker
- Application caching layer
- Session storage
- AOF persistence enabled

## Traefik Labels Explained

The docker-compose.yml includes Traefik labels that:

- **Enable Traefik**: `traefik.enable=true`
- **Set routing rules**: Based on domain names
- **Configure load balancing**: Port mapping for services
- **Apply middleware**: Security headers, compression, CORS
- **SSL/TLS**: Ready for Let's Encrypt certificates

## Production Checklist

Before deploying to production:

- [ ] Change all default passwords in `.env`
- [ ] Set strong `SECRET_KEY` (32+ characters)
- [ ] Configure SMTP for emails
- [ ] Enable HTTPS in docker-compose.yml (uncomment HTTPS labels)
- [ ] Set up database backups (cron job)
- [ ] Configure proper CORS origins
- [ ] Set up monitoring/alerting
- [ ] Configure proper logging
- [ ] Test Celery tasks thoroughly
- [ ] Set up Redis persistence strategy
- [ ] Test disaster recovery procedures

## Notes

- Database data is persisted in Docker volume `tradewhispr-db-data`
- Redis data is persisted in Docker volume `tradewhispr-redis-data`
- Traefik automatically handles routing based on domain names
- Services restart automatically unless stopped manually
- Health checks ensure services are running properly
- Celery worker shares the same image as backend for consistency
