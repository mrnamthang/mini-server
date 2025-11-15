# Adding Projects to Your Mini-Server

This guide shows you how to easily add your 6 projects (4 client + 2 side projects) to the mini-server.

## 🎯 Overview

**Infrastructure setup (`make setup`) does NOT require any git repos!**

Projects are added **after** infrastructure is ready. You can add them:
- One at a time (recommended to test)
- All at once (if you're confident)

---

## 🚀 Two Methods to Add Projects

### Method 1: Automated with Script (Easiest)

```bash
# Run the project generator
./scripts/add-project.sh

# Follow prompts:
# - Project name: client-acme
# - Git repo: https://github.com/you/client-acme
# - Domain: acme.local
# - Tech stack: 1 (Node.js)
```

**What it does:**
- ✅ Creates `projects/client-acme/docker-compose.yml`
- ✅ Creates `.env.example` template
- ✅ Creates `README.md` with deployment instructions
- ✅ Gives you next steps

Then just follow the instructions it prints!

---

### Method 2: Manual (More Control)

**Step 1: Create project on Asus**
```bash
ssh thang@192.168.1.10

# Create directory
sudo mkdir -p /opt/projects/client-acme/src
sudo chown thang:thang /opt/projects/client-acme/src

# Clone your repo
cd /opt/projects/client-acme
git clone https://github.com/you/client-acme src

exit
```

**Step 2: Create docker-compose.yml**
```bash
# On Mac, copy a template
cp projects/flow/docker-compose.yml projects/client-acme/
# Edit it for your project's tech stack
```

**Step 3: Deploy**
```bash
# Copy files to Asus
scp projects/client-acme/docker-compose.yml thang@192.168.1.10:/opt/projects/client-acme/

# SSH and start
ssh thang@192.168.1.10
cd /opt/projects/client-acme
docker-compose up -d
```

**Step 4: Add to /etc/hosts**
```bash
# On Mac
sudo nano /etc/hosts
# Add: 192.168.1.10 acme.local
```

---

## 📋 Quick Reference: Your 6 Projects

Here's a suggested plan for adding all your projects:

### Flow (Side Project 1)
```bash
Project: flow
Domain: flow.local
Tech: .NET 8 + React
Status: Template already exists ✅
Action: make deploy-flow (when ready)
```

### Tradewhispr (Side Project 2)
```bash
Project: tradewhispr
Domain: tradewhispr.local
Tech: FastAPI + Vue 3
Status: Template already exists ✅
Action: make deploy-tradewhispr (when ready)
```

### Client Projects (Add as needed)
```bash
# Client A
./scripts/add-project.sh
Name: client-a
Domain: client-a.local

# Client B
./scripts/add-project.sh
Name: client-b
Domain: client-b.local

# Client C
./scripts/add-project.sh
Name: client-c
Domain: client-c.local

# Client D
./scripts/add-project.sh
Name: client-d
Domain: client-d.local
```

---

## 🎯 Recommended Workflow

### Phase 1: Test Infrastructure (Today)
```bash
# Just run infrastructure setup
make setup

# No projects needed yet!
```

### Phase 2: Add One Project (Tomorrow)
```bash
# Test with your most important project
./scripts/add-project.sh
# Or deploy Flow: make deploy-flow
```

### Phase 3: Add Rest Gradually (This Week)
```bash
# Add one project per day
# Monitor resources with: ./scripts/projects.sh status
```

---

## 📦 Project Structure

After adding projects, your structure will be:

```
mini-server/
├── projects/
│   ├── flow/                    # Side project 1
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── README.md
│   ├── tradewhispr/             # Side project 2
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── README.md
│   ├── client-a/                # Client project 1
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── README.md
│   ├── client-b/                # Client project 2
│   ├── client-c/                # Client project 3
│   └── client-d/                # Client project 4
└── scripts/
    ├── add-project.sh           # Project generator
    └── projects.sh              # Project manager
```

---

## 🛠️ Managing Multiple Projects

### Start/Stop Projects as Needed

```bash
# Check what's running
./scripts/projects.sh status

# Start a project
./scripts/projects.sh start client-a

# Stop when done
./scripts/projects.sh stop client-a

# Stop all (end of day)
./scripts/projects.sh stop-all
```

### Update projects.sh

After adding new projects, update the PROJECTS array:

```bash
nano scripts/projects.sh

# Find the PROJECTS array and add your projects:
PROJECTS=(
    "flow"
    "tradewhispr"
    "client-a"
    "client-b"
    "client-c"
    "client-d"
)
```

---

## 🔧 Common Scenarios

### Scenario 1: Node.js + React + PostgreSQL
```yaml
services:
  db: postgres:16-alpine
  api: node:20-alpine (your API)
  web: nginx:alpine (React build)
```

### Scenario 2: Python + Vue + PostgreSQL
```yaml
services:
  db: postgres:16-alpine
  api: python:3.11-slim (FastAPI/Django)
  web: nginx:alpine (Vue build)
```

### Scenario 3: .NET + React + SQL Server
```yaml
services:
  db: mcr.microsoft.com/mssql/server:2022-latest
  api: mcr.microsoft.com/dotnet/aspnet:8.0
  web: nginx:alpine (React build)
```

### Scenario 4: Fullstack (Next.js, Nuxt, etc.)
```yaml
services:
  db: postgres:16-alpine
  app: node:20-alpine (SSR app)
```

---

## 💡 Pro Tips

### 1. Use Project Templates

Copy docker-compose.yml from similar projects:
- Node.js project? Copy from another Node.js project
- Python project? Copy from Tradewhispr
- .NET project? Copy from Flow

### 2. Shared PostgreSQL (Advanced)

Instead of 6 separate PostgreSQL instances:

```yaml
# One PostgreSQL for all projects
services:
  shared-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_MULTIPLE_DATABASES: flow,tradewhispr,client_a,client_b
```

Saves ~800MB RAM!

### 3. Development Profiles

Tag projects by priority:

```yaml
services:
  api:
    profiles: ["production"]  # Always runs

  dev-tools:
    profiles: ["dev"]  # Only for development
```

### 4. Resource Limits

Prevent one project from hogging resources:

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

---

## ❓ FAQ

### Q: Do I need to add all projects now?

**A: No!** Add them gradually:
1. First: Run `make setup` (infrastructure only, no projects)
2. Then: Add projects one by one as needed
3. Test each before adding the next

### Q: Can I add projects without git repos?

**A: Yes!** Just manually copy your source code:

```bash
ssh thang@192.168.1.10
cd /opt/projects/my-project/src
# Copy files however you want (scp, rsync, etc.)
```

### Q: What if my project doesn't use Docker?

**A: Create a Dockerfile!** Examples:

```dockerfile
# Node.js
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "start"]

# Python
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

### Q: How do I update a deployed project?

```bash
# SSH into Asus
ssh thang@192.168.1.10

# Go to project
cd /opt/projects/my-project/src

# Pull latest code
git pull origin main

# Rebuild and restart
cd ..
docker-compose build
docker-compose up -d
```

Or use the rebuild script:
```bash
./scripts/rebuild-on-asus.sh my-project my-project-api
```

---

## 🎉 Summary

**To add projects:**

1. **Easiest**: `./scripts/add-project.sh` (guided wizard)
2. **Manual**: Copy template, customize, deploy
3. **Hybrid**: Use templates, adjust as needed

**When to add projects:**

- **Now**: No! Just run `make setup` first
- **After setup**: Add one project to test
- **This week**: Add remaining projects gradually

**Managing projects:**

- `./scripts/projects.sh status` - Check what's running
- `./scripts/projects.sh start <project>` - Start when needed
- `./scripts/projects.sh stop <project>` - Stop when done
- Run 2-3 projects at a time, not all 6!

---

Need help adding a specific project? Just ask! 🚀
