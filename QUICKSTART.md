# Quick Start Guide

Get your mini-server up and running in minutes!

## Prerequisites

✅ Asus laptop with Ubuntu 22.04 installed
✅ SSH access to the Asus server
✅ Ansible installed on your Mac (`brew install ansible`)
✅ Same local network for Mac and Asus

## 5-Minute Setup

### Step 1: Configure Server Details (2 minutes)

```bash
# Edit inventory file
nano ansible/inventory/hosts.yml
```

Update these two lines:
```yaml
ansible_host: 192.168.1.100    # Your Asus server IP
ansible_user: your-username    # Your Asus username
```

### Step 2: Run Automated Setup (10-15 minutes)

```bash
# Complete infrastructure setup
make setup
```

This will:
- ✅ Configure server security (SSH hardening, firewall, fail2ban)
- ✅ Install Docker and Docker Compose
- ✅ Setup Traefik reverse proxy
- ✅ Create necessary directories

### Step 3: Update Your Mac's Hosts File (1 minute)

```bash
# Generate hosts entries
make hosts-file

# Copy the output and add to /etc/hosts
sudo nano /etc/hosts
```

### Step 4: Deploy Your Projects

#### Deploy Flow:

```bash
# SSH into Asus and clone Flow
ssh asus-server
cd /opt/projects/flow
git clone <your-flow-repo-url> src
exit

# Deploy from Mac
make deploy-flow
```

#### Deploy Tradewhispr:

```bash
# SSH into Asus and clone Tradewhispr
ssh asus-server
cd /opt/projects/tradewhispr
git clone <your-tradewhispr-repo-url> src
exit

# Deploy from Mac
make deploy-tradewhispr
```

### Step 5: Configure Environment Variables

```bash
# SSH into server
ssh asus-server

# Configure Flow
cd /opt/projects/flow
nano .env
# Update passwords and secrets

# Configure Tradewhispr
cd /opt/projects/tradewhispr
nano .env
# Update passwords and secrets

# Restart services
cd /opt/projects/flow && docker-compose restart
cd /opt/projects/tradewhispr && docker-compose restart
```

### Step 6: Access Your Services! 🎉

Open your browser on Mac:

- **Flow**: http://flow.local
- **Flow API**: http://api.flow.local
- **Tradewhispr**: http://tradewhispr.local
- **Tradewhispr API**: http://api.tradewhispr.local/docs
- **Traefik Dashboard**: http://traefik.local

## Common Commands

```bash
# Check status
make status

# View logs
make logs-flow
make logs-tradewhispr

# Restart services
make restart-flow
make restart-tradewhispr

# SSH into server
make ssh

# Update system
make update-system

# Backup databases
make backup-all
```

## Troubleshooting

### Can't access services?

```bash
# 1. Check if Traefik is running
make status

# 2. Check Traefik logs
make logs-traefik

# 3. Verify /etc/hosts on Mac
cat /etc/hosts | grep local

# 4. Test connectivity
make ping
```

### Services won't start?

```bash
# SSH into server
make ssh

# Check Docker
docker ps -a

# Check specific project
cd /opt/projects/flow
docker-compose logs

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

### Database issues?

```bash
# SSH into server
ssh asus-server

# Check database
docker exec -it flow-db psql -U flowuser -d flowdb

# Run migrations (Flow)
docker exec -it flow-api dotnet ef database update

# Run migrations (Tradewhispr)
docker exec -it tradewhispr-backend alembic upgrade head
```

## Next Steps

- [ ] Set up Tailscale for remote access
- [ ] Configure SSL/TLS with Let's Encrypt
- [ ] Set up automated backups
- [ ] Add monitoring with Portainer
- [ ] Configure CI/CD for automatic deployments

## Getting Help

- Read the full [README.md](README.md)
- Check project-specific READMEs:
  - [Flow Deployment Guide](projects/flow/README.md)
  - [Tradewhispr Deployment Guide](projects/tradewhispr/README.md)
- View provisioning guide: [Ubuntu Fresh Install](provisioning/ubuntu-fresh-install.md)

## All Makefile Commands

```bash
make help  # Show all available commands
```

Key commands:
- `make setup` - Complete infrastructure setup
- `make deploy-flow` - Deploy Flow project
- `make deploy-tradewhispr` - Deploy Tradewhispr project
- `make status` - Check service status
- `make logs-<project>` - View logs
- `make restart-<project>` - Restart services
- `make ssh` - SSH into server
- `make hosts-file` - Generate /etc/hosts entries

---

**That's it!** Your mini-server should now be running and accessible from your Mac. 🚀

For building Docker images from your Mac and running them on the Asus server, see the Docker offloading guide (coming soon).
