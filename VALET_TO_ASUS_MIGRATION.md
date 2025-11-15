# Migrating from Laravel Valet to Asus Server

Complete guide for migrating your Laravel Valet projects to the Asus mini-server.

## Prerequisites

- ✅ Git installed on Asus (already done via bootstrap)
- ✅ Docker + Traefik running on Asus
- ✅ SSH access from Mac to Asus

---

## Step 1: Git Configuration on Asus

**On Asus server** (one-time setup):

```bash
ssh asus-server

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Optional: Set up SSH keys for GitHub/GitLab
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub
# Add this public key to GitHub/GitLab

exit
```

**Or via script** from your Mac:

```bash
# Create a setup script
./scripts/setup-git-on-asus.sh "Your Name" "your@email.com"
```

---

## Step 2: Migrate Your Laravel Project

### Example: stays.handover.co.nz

Your current setup:
```
~/projects/stays.handover.co.nz  (Valet managed)
├── app/
├── database/
├── public/
├── composer.json
└── ...
```

### Migration Steps

#### A. Push to Git (if not already)

```bash
cd ~/projects/stays.handover.co.nz

# Initialize git if needed
git init
git add .
git commit -m "Initial commit before migration"

# Push to GitHub/GitLab
git remote add origin git@github.com:yourname/stays-handover.git
git push -u origin main
```

#### B. Clone to Asus

```bash
ssh asus-server

# Create project directory
sudo mkdir -p /opt/projects/stays-handover/src
sudo chown thang:thang /opt/projects/stays-handover

# Clone your project
cd /opt/projects/stays-handover
git clone git@github.com:yourname/stays-handover.git src

exit
```

#### C. Create Docker Configuration

**On your Mac**, use the onboarding script:

```bash
# The script auto-detects Laravel/PHP!
./scripts/onboard-project.sh

# Answer prompts:
# Project name: stays-handover
# Git repo: git@github.com:yourname/stays-handover.git
# Domain: stays.handover.local (or stays.local)
```

This generates:
- `projects/stays-handover/docker-compose.yml` (Laravel stack)
- `projects/stays-handover/.env.example`
- `projects/stays-handover/README.md`

#### D. Copy Configuration to Asus

```bash
# Copy docker-compose.yml
scp projects/stays-handover/docker-compose.yml thang@192.168.1.10:/opt/projects/stays-handover/

# Copy .env template
scp projects/stays-handover/.env.example thang@192.168.1.10:/opt/projects/stays-handover/.env

# Configure environment on Asus
ssh asus-server
cd /opt/projects/stays-handover
nano .env

# Update:
# - APP_URL=https://stays.handover.local
# - DB_* settings
# - REDIS settings
# Save and exit

exit
```

#### E. Start Services

```bash
ssh asus-server
cd /opt/projects/stays-handover
docker-compose up -d

# Run migrations
docker-compose exec app php artisan migrate --seed

# Check logs
docker-compose logs -f
exit
```

#### F. Add to /etc/hosts on Mac

```bash
sudo sh -c 'echo "192.168.1.10 stays.handover.local" >> /etc/hosts'
```

#### G. Enable HTTPS (Like Valet Secure)

```bash
# One-time SSL setup
./scripts/secure-local.sh

# Then access via HTTPS
open https://stays.handover.local
```

---

## Step 3: Development Workflow

### Option A: VS Code Remote-SSH (Recommended)

```bash
# In VS Code
# 1. Cmd+Shift+P → "Remote-SSH: Connect to Host" → asus-server
# 2. Open folder: /opt/projects/stays-handover/src
# 3. Code directly on Asus!
```

### Option B: Sync from Mac (if you prefer)

```bash
# Start dev mode
./scripts/dev.sh stays-handover

# Edit files on Mac at ~/projects/stays.handover.co.nz
# Changes auto-sync to Asus
# Artisan commands run on Asus
```

---

## Valet vs Asus Comparison

| Feature | Laravel Valet | Asus Mini-Server |
|---------|--------------|------------------|
| **Setup** | `valet park` | `./scripts/onboard-project.sh` |
| **SSL** | `valet secure` | `./scripts/secure-local.sh` |
| **Logs** | `valet log` | `docker-compose logs -f` |
| **Restart** | `valet restart` | `docker-compose restart` |
| **Database** | Homebrew MySQL | Docker MySQL/PostgreSQL |
| **Redis** | Homebrew Redis | Docker Redis |
| **PHP Version** | `valet use php@8.2` | Update Dockerfile |
| **Multiple Projects** | All auto-routed | Traefik auto-routes |
| **Performance** | Mac resources | Asus resources (better!) |

---

## Common Laravel Commands on Asus

### Artisan Commands

```bash
ssh asus-server
cd /opt/projects/stays-handover

# Artisan
docker-compose exec app php artisan migrate
docker-compose exec app php artisan tinker
docker-compose exec app php artisan queue:work

# Composer
docker-compose exec app composer install
docker-compose exec app composer update

# NPM (for assets)
docker-compose exec app npm install
docker-compose exec app npm run dev
docker-compose exec app npm run build

# Clear caches
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
docker-compose exec app php artisan route:clear
docker-compose exec app php artisan view:clear
```

### Database Access

```bash
# MySQL/PostgreSQL
docker-compose exec db mysql -u root -p
docker-compose exec db psql -U postgres

# Or from Mac via tunnel
ssh -L 3306:localhost:3306 asus-server
# Then connect to localhost:3306
```

### Viewing Logs

```bash
# All logs
docker-compose logs -f

# Specific service
docker-compose logs -f app
docker-compose logs -f nginx
docker-compose logs -f db

# Laravel logs
docker-compose exec app tail -f storage/logs/laravel.log
```

---

## Laravel Docker Stack

The auto-generated `docker-compose.yml` includes:

```yaml
services:
  # Nginx (web server)
  nginx:
    - Serves PHP via FastCGI
    - Traefik integration
    - HTTPS support

  # PHP-FPM (Laravel application)
  app:
    - PHP 8.2-fpm
    - Composer installed
    - All Laravel extensions
    - Auto-restarts on code changes (dev mode)

  # MySQL or PostgreSQL
  db:
    - Your choice during onboarding
    - Persistent data volumes
    - Auto-backup scripts

  # Redis (cache/queue)
  redis:
    - Cache driver
    - Queue driver
    - Session storage
```

---

## Git Workflow on Asus

### Daily Development

```bash
# 1. Connect via Remote-SSH or sync
# 2. Make changes
# 3. Commit from Asus

ssh asus-server
cd /opt/projects/stays-handover/src

git add .
git commit -m "Add feature X"
git push origin main

exit
```

### Pull Updates

```bash
ssh asus-server
cd /opt/projects/stays-handover/src

git pull origin main

# Restart services if needed
cd ..
docker-compose restart app

exit
```

---

## Multiple Laravel Projects

You can run multiple Laravel projects simultaneously:

```bash
# Project 1: stays.handover.co.nz
https://stays.handover.local

# Project 2: another-project
https://another.local

# All auto-routed via Traefik
# Each with own MySQL/Redis
# Isolated containers
```

Manage them:
```bash
./scripts/projects.sh status
./scripts/projects.sh start stays-handover
./scripts/projects.sh stop stays-handover
```

---

## Advantages Over Valet

### 1. **Better Resource Management**
- Valet uses Mac's resources (83% RAM!)
- Asus has dedicated 12GB for projects
- Mac stays fast for editing

### 2. **Production-Like Environment**
- Docker containers = production setup
- Same environment everywhere
- No "works on my machine" issues

### 3. **Multiple PHP Versions**
- Run PHP 7.4, 8.1, 8.2 simultaneously
- Each project can have different versions
- Just change Dockerfile

### 4. **Team Collaboration**
- Anyone can access `https://stays.handover.local` on network
- Share work with team members
- Same as Valet's `valet share` but persistent

### 5. **Database Isolation**
- Each project has own MySQL
- No port conflicts
- Easy backups per project

---

## Troubleshooting

### "Can't connect to stays.handover.local"

```bash
# Check /etc/hosts
cat /etc/hosts | grep stays

# Add if missing
sudo sh -c 'echo "192.168.1.10 stays.handover.local" >> /etc/hosts'
```

### "500 Internal Server Error"

```bash
# Check Laravel logs
ssh asus-server
cd /opt/projects/stays-handover
docker-compose logs app

# Check file permissions
docker-compose exec app chmod -R 775 storage bootstrap/cache
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache
```

### "SQLSTATE Connection Refused"

```bash
# Check database is running
ssh asus-server
cd /opt/projects/stays-handover
docker-compose ps

# Check .env database settings
cat .env | grep DB_
```

### Migration: Permission Denied

```bash
# Laravel needs write permissions
ssh asus-server
cd /opt/projects/stays-handover
docker-compose exec app chmod -R 775 storage
docker-compose exec app chown -R www-data:www-data storage
```

---

## Next Steps

1. ✅ Migrate your first project (stays.handover.co.nz)
2. ✅ Set up SSL with `./scripts/secure-local.sh`
3. ✅ Try VS Code Remote-SSH
4. ✅ Migrate remaining Valet projects
5. ✅ Consider `valet uninstall` on Mac (free up resources!)

---

## Quick Reference

```bash
# Migrate new Laravel project
./scripts/onboard-project.sh

# Enable SSL for all .local domains
./scripts/secure-local.sh

# Secure specific project
./scripts/secure.sh stays-handover

# Connect with VS Code
# Cmd+Shift+P → Remote-SSH: Connect to Host → asus-server

# Run artisan on Asus
ssh asus-server "cd /opt/projects/stays-handover && docker-compose exec app php artisan migrate"

# View logs
ssh asus-server "cd /opt/projects/stays-handover && docker-compose logs -f app"
```

Your Laravel development is now more powerful and efficient! 🚀
