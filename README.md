# Mini Server Infrastructure

This repository contains the Infrastructure as Code (IaC) for setting up an Asus laptop as a mini server to host side projects and offload heavy workloads from a MacBook Air M1.

## 🎯 Purpose

- **Primary Goal**: Host side projects (Flow, Tradewhispr) on a dedicated server
- **Secondary Goal**: Offload CPU/RAM-intensive tasks (Docker builds, compilation) from Mac
- **Mac Role**: Text editing and frontend hot-reload only
- **Asus Role**: Docker builds, databases, Python/.NET runtime, production services

## 🏗️ Architecture

```
MacBook Air M1 (Control Machine)
    │
    ├─> Ansible Playbooks
    │   └─> SSH to Asus Server
    │
Asus Mini Server (Ubuntu 22.04)
    │
    ├─> Traefik (Reverse Proxy & Load Balancer)
    │   ├─> flow.local → Flow Application
    │   ├─> tradewhispr.local → Tradewhispr Application
    │   └─> Dashboard: traefik.local
    │
    ├─> Flow Stack
    │   ├─> .NET 8 API (ASP.NET Core)
    │   ├─> React 18 + TypeScript Frontend
    │   └─> PostgreSQL 16
    │
    ├─> Tradewhispr Stack
    │   ├─> FastAPI (Python 3.11)
    │   ├─> Vue 3 + TypeScript Frontend
    │   ├─> PostgreSQL 15
    │   ├─> Redis 7
    │   └─> Celery Workers
    │
    └─> Docker Build Service
```

## 📋 Prerequisites

### On Your Mac (Control Machine)

1. **Ansible installed**:
   ```bash
   brew install ansible
   ```

2. **SSH access to Asus server**:
   - Ensure you can `ssh user@asus-server-ip`
   - Add your SSH key: `ssh-copy-id user@asus-server-ip`

### On Asus Server (Target Machine)

- Ubuntu 22.04 (Desktop with i3 - GUI disabled)
- SSH server enabled
- User with sudo privileges
- Internet connection

## 🚀 Quick Start

### Step 1: Configure Inventory

Edit `ansible/inventory/hosts.yml` with your Asus server details:

```yaml
all:
  children:
    mini_servers:
      hosts:
        asus-server:
          ansible_host: 192.168.1.XXX  # Your Asus IP
          ansible_user: your-username
          ansible_python_interpreter: /usr/bin/python3
```

### Step 2: Configure Variables

Edit `ansible/group_vars/all.yml` with your preferences:

```yaml
# Domain configuration
base_domain: "local"
traefik_dashboard_domain: "traefik.local"

# Project domains
flow_domain: "flow.local"
tradewhispr_domain: "tradewhispr.local"

# Email for Let's Encrypt (for future public hosting)
letsencrypt_email: "your-email@example.com"
```

### Step 3: Run Bootstrap

This sets up the server from scratch:

```bash
# Full automated setup (bootstrap + docker + traefik)
make setup

# Or run step by step:
make bootstrap    # Initial server configuration
make docker       # Install Docker
make traefik      # Setup reverse proxy
```

### Step 4: Deploy Projects

```bash
# Deploy Flow
make deploy-flow

# Deploy Tradewhispr
make deploy-tradewhispr

# Deploy all projects
make deploy-all
```

### Step 5: Configure Your Mac

Add these entries to your Mac's `/etc/hosts`:

```bash
sudo nano /etc/hosts

# Add these lines (replace with your Asus IP):
192.168.1.XXX flow.local
192.168.1.XXX tradewhispr.local
192.168.1.XXX traefik.local
```

### Step 6: Access Your Services

- **Flow**: http://flow.local
- **Tradewhispr**: http://tradewhispr.local
- **Traefik Dashboard**: http://traefik.local

## 📁 Project Structure

```
mini-server/
├── ansible/                        # Ansible infrastructure code
│   ├── inventory/
│   │   └── hosts.yml              # Server inventory
│   ├── playbooks/
│   │   ├── 01-bootstrap.yml       # Initial server setup
│   │   ├── 02-docker.yml          # Docker installation
│   │   ├── 03-traefik.yml         # Reverse proxy setup
│   │   └── deploy-project.yml     # Project deployment
│   ├── roles/                     # Reusable Ansible roles
│   │   ├── common/                # Common server configuration
│   │   ├── docker/                # Docker setup
│   │   ├── traefik/               # Traefik configuration
│   │   └── project-deploy/        # Project deployment logic
│   ├── group_vars/
│   │   └── all.yml                # Global variables
│   └── ansible.cfg                # Ansible configuration
├── projects/                       # Project-specific configurations
│   ├── flow/
│   │   ├── docker-compose.yml     # Flow stack with Traefik labels
│   │   └── .env.example           # Environment variables template
│   └── tradewhispr/
│       ├── docker-compose.yml     # Tradewhispr stack with Traefik labels
│       └── .env.example           # Environment variables template
├── traefik/                        # Traefik reverse proxy
│   ├── docker-compose.yml         # Traefik container
│   ├── traefik.yml                # Static configuration
│   └── dynamic/                   # Dynamic configuration
├── provisioning/                   # Future: Fresh OS installation
│   └── ubuntu-fresh-install.md    # Guide for wiping and reinstalling
├── Makefile                        # Convenient commands
└── README.md                       # This file
```

## 🛠️ Makefile Commands

```bash
# Infrastructure Setup
make setup              # Full setup (bootstrap + docker + traefik)
make bootstrap          # Initial server configuration
make docker             # Install Docker and Docker Compose
make traefik            # Setup Traefik reverse proxy

# Project Deployment
make deploy-flow        # Deploy Flow project
make deploy-tradewhispr # Deploy Tradewhispr project
make deploy-all         # Deploy all projects

# Maintenance
make update-system      # Update server packages
make restart-traefik    # Restart Traefik
make restart-flow       # Restart Flow services
make restart-tradewhispr # Restart Tradewhispr services
make logs-flow          # View Flow logs
make logs-tradewhispr   # View Tradewhispr logs

# Utilities
make ping               # Test connectivity
make check              # Check Ansible configuration
make facts              # Gather server facts
```

## 🔧 Common Tasks

### Adding a New Project

1. Create project directory: `projects/new-project/`
2. Add `docker-compose.yml` with Traefik labels
3. Create Ansible task in `playbooks/deploy-project.yml`
4. Add Makefile target for deployment
5. Update `/etc/hosts` on your Mac

### Viewing Logs

```bash
# SSH into the server
ssh asus-server

# View Traefik logs
docker logs traefik -f

# View Flow logs
cd /opt/projects/flow && docker-compose logs -f

# View Tradewhispr logs
cd /opt/projects/tradewhispr && docker-compose logs -f
```

### Updating a Project

```bash
# From your Mac
make deploy-flow        # Pulls latest changes and restarts
```

## 🌐 Future: Public Internet Hosting

When you're ready to expose services to the internet:

1. **Setup Tailscale** (private access):
   ```bash
   make setup-tailscale
   ```

2. **Configure Let's Encrypt** (public access):
   - Update `ansible/group_vars/all.yml` with real domains
   - Traefik will automatically get SSL certificates
   - Update DNS to point to your public IP

3. **Firewall Configuration**:
   - The bootstrap playbook sets up UFW
   - Only necessary ports are exposed

## 🔒 Security Considerations

- SSH key-based authentication (password auth disabled by default)
- UFW firewall enabled (only necessary ports open)
- Fail2ban installed (brute-force protection)
- Docker containers run as non-root users
- Traefik handles SSL/TLS termination
- Sensitive data in environment variables (not committed to git)

## 📦 What Gets Installed

- **Docker Engine** (latest stable)
- **Docker Compose** (latest stable)
- **Traefik** (v3.x - reverse proxy)
- **.NET 8 SDK** (for Flow builds)
- **Python 3.11** (for Tradewhispr)
- **PostgreSQL Client Tools** (for database management)
- **Essential utilities** (htop, ncdu, curl, git, etc.)

## 🐛 Troubleshooting

### Can't SSH into Asus server

```bash
# Check connectivity
ping asus-server-ip

# Test SSH
ssh -v user@asus-server-ip

# Copy SSH key if needed
ssh-copy-id user@asus-server-ip
```

### Ansible playbook fails

```bash
# Check configuration
make check

# Test connectivity
make ping

# Run with verbose output
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/01-bootstrap.yml -vvv
```

### Can't access services from Mac

```bash
# Check /etc/hosts on Mac
cat /etc/hosts | grep local

# Check Traefik is running
ssh asus-server "docker ps | grep traefik"

# Check Traefik dashboard
open http://traefik.local
```

### Services not starting

```bash
# SSH into server
ssh asus-server

# Check Docker status
sudo systemctl status docker

# Check service logs
cd /opt/projects/flow && docker-compose logs

# Restart services
docker-compose down && docker-compose up -d
```

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Documentation](https://docs.docker.com/)
- [Tailscale Documentation](https://tailscale.com/kb/)

## 🔄 Next Phase: Fresh Installation

The `provisioning/` directory contains guides for:
- Creating a bootable Ubuntu USB
- Automated OS installation with preseed
- Full disk encryption setup
- Automated post-install configuration

This allows you to wipe the laptop and start fresh with a reproducible setup.

## 📝 Notes

- This setup assumes both Mac and Asus are on the same local network
- For remote access, Tailscale integration is recommended
- All sensitive configuration (passwords, API keys) should be in `.env` files (not committed)
- The Asus server will handle all heavy lifting (builds, databases, processing)
- Your Mac only needs to run code editors and lightweight development tools

## 🤝 Contributing

This is a personal infrastructure project, but feel free to adapt it for your own use!

## 📄 License

MIT License - Use freely for your own projects.
