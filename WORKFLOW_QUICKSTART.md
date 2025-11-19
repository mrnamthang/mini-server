# Mac ↔ Asus Workflow - Quick Start

> **TL;DR:** Code on Mac, everything else runs on Asus automatically.

## 🚀 One-Command Development

The fastest way to start working:

```bash
# Start development mode for any project
./scripts/dev.sh flow

# That's it! Now:
# - Edit code on Mac (any editor)
# - Files auto-sync to Asus
# - Backend changes trigger rebuild
# - Frontend hot-reloads
# - View in browser: http://flow.local
```

---

## 📋 Daily Workflow

### Morning: Start Your Day

```bash
# 1. Check everything is healthy
./scripts/status.sh
```

### 2. Make Changes & Deploy

1. **Edit code** in VS Code on your Mac.
2. **Commit and Push** your changes:
   ```bash
   git push origin main
   ```
3. **Deploy** to the server:
   ```bash
   make deploy-tradewhispr
   ```
4. **Verify** changes:
   - Frontend: http://tradewhispr.local
   - API: http://api.tradewhispr.local/docs trigger rebuild
- ✅ Frontend changes hot-reload
- ✅ Logs show automatically

### End of Day

```bash
# Press Ctrl+C to stop dev mode

# Commit your work
git add .
git commit -m "Your changes"
git push
```

---

## 🎯 Common Workflows

### Scenario 1: Frontend Development (React/Vue)

**Goal:** Edit UI with instant hot-reload

```bash
# Start dev mode
./scripts/dev.sh flow

# Edit frontend files on Mac
code ~/projects/flow/src/frontend/

# Changes auto-sync → hot-reload → see in browser
# No rebuild needed for frontend changes!
```

**How it works:**
- `.tsx`, `.jsx`, `.vue`, `.css` files = sync only (fast!)
- Backend files = sync + rebuild (automatic)

### Scenario 2: Backend Development (.NET/Python)

**Goal:** Edit API and test changes

```bash
# Start dev mode
./scripts/dev.sh flow

# Edit backend files on Mac
code ~/projects/flow/src/backend/

# Changes trigger:
#   1. Sync to Asus
#   2. Auto rebuild
#   3. Auto restart
#   4. Logs appear automatically
```

**Manually force rebuild:**

```bash
./scripts/rebuild-on-asus.sh flow flow-api
```

### Scenario 3: Database Work

**Goal:** Run migrations, query database

```bash
# Create SSH tunnel from Mac
ssh -L 5432:localhost:5432 asus-server

# Connect with local tools
psql -h localhost -p 5432 -U flowuser -d flowdb

# Or run migrations on Asus
ssh asus-server "cd /opt/projects/flow && docker exec flow-api dotnet ef database update"
```

### Scenario 4: View Logs

**Goal:** Debug what's happening

```bash
# Option 1: Auto-show logs in dev mode
./scripts/dev.sh flow
# Logs appear after rebuilds

# Option 2: View logs only (no sync)
./scripts/dev.sh flow logs-only

# Option 3: Old scripts still work
./scripts/logs.sh flow flow-api
```

### Scenario 5: Multiple Projects

**Goal:** Work on 2-3 projects simultaneously

```bash
# Terminal 1: Flow dev mode
./scripts/dev.sh flow

# Terminal 2: Tradewhispr dev mode
./scripts/dev.sh tradewhispr

# Terminal 3: Status dashboard
watch -n 5 ./scripts/status.sh

# Now edit either project - both auto-sync!
```

### Scenario 6: Sync Only (No Rebuild)

**Goal:** Just sync files, manual control over rebuilds

```bash
./scripts/dev.sh flow sync-only

# Files sync automatically
# But won't rebuild on backend changes
# Good for when you want to batch changes before rebuild
```

---

## ⌨️ VSCode Integration

### Keyboard Shortcuts

Open VSCode in the mini-server folder, then:

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+D` | Start dev mode |
| `Cmd+Shift+L` | View logs |
| `Cmd+Shift+S` | Show status |
| `Cmd+Shift+O` | Open in browser |
| `Cmd+Shift+R` | Restart project |

### Tasks Menu

Press `Cmd+Shift+P` → "Tasks: Run Task" → Choose:

- 🚀 Start Dev Mode (Auto)
- 🔄 Sync Only (No Rebuild)
- 📋 View Logs
- 🔨 Force Rebuild
- 📊 Project Status
- ▶️ Start Project
- ⏹️ Stop Project
- 🔄 Restart Project
- 🌐 Open in Browser
- 🎛️ Open Traefik Dashboard

---

## 🛠️ Script Reference

### Main Scripts

**`./scripts/dev.sh <project> [mode]`**
- Unified development workflow
- Modes: `auto` (default), `sync-only`, `logs-only`
- Auto-sync, smart rebuild, show logs

**`./scripts/status.sh`**
- Quick dashboard of everything
- Server health, running containers, resource usage

**`./scripts/projects.sh <action> [project]`**
- Manage projects on Asus
- Actions: `status`, `start`, `stop`, `restart`, `stop-all`

### Legacy Scripts (Still Work)

**`./scripts/sync-to-asus.sh <project>`**
- Manual one-time sync

**`./scripts/watch-and-sync.sh <project>`**
- Watch and sync only (no rebuild)

**`./scripts/rebuild-on-asus.sh <project> <service>`**
- Manual rebuild

**`./scripts/logs.sh <project> [service]`**
- View logs

---

## 🎨 Smart Features

### 1. Smart Rebuild Detection

The dev script knows what changed:

**No rebuild needed (fast sync only):**
- `.tsx`, `.jsx`, `.js`, `.ts`
- `.vue`, `.css`, `.scss`, `.html`

**Rebuild needed:**
- `.cs`, `.csproj` (.NET)
- `.py`, `requirements.txt` (Python)
- `Dockerfile`, `docker-compose.yml`
- `package.json`

### 2. Auto-Start Services

If services aren't running, dev mode starts them automatically.

### 3. Connectivity Check

Scripts check SSH connection before syncing - fail fast with helpful errors.

### 4. Batch Changes

Changes are batched with 2-second delay - editing multiple files triggers one sync, not many.

---

## 📊 Project Management

### Check Status

```bash
./scripts/projects.sh status

# Shows:
# - What's running
# - Resource usage
# - Access URLs
```

### Start/Stop Projects

```bash
# Start
./scripts/projects.sh start flow

# Stop
./scripts/projects.sh stop flow

# Restart
./scripts/projects.sh restart flow

# Stop everything (saves RAM)
./scripts/projects.sh stop-all
```

---

## ⚙️ Configuration

All scripts read from `.dev-config`:

```bash
# Edit if needed
nano .dev-config
```

**Key settings:**
- `ASUS_HOST` - Server IP (default: 192.168.1.10)
- `ASUS_USER` - SSH username (default: thang)
- `SYNC_DELAY` - Batch delay in seconds (default: 2)
- `AUTO_REBUILD` - Auto rebuild on backend changes (default: true)

---

## 🚨 Troubleshooting

### Changes Not Appearing

```bash
# 1. Check dev mode is running
ps aux | grep "dev.sh"

# 2. Force sync
./scripts/sync-to-asus.sh flow

# 3. Force rebuild
./scripts/rebuild-on-asus.sh flow flow-api

# 4. Check logs
./scripts/dev.sh flow logs-only
```

### Can't Connect to Asus

```bash
# 1. Check server is up
ping 192.168.1.10

# 2. Check SSH
ssh asus-server

# 3. Check SSH config
cat ~/.ssh/config | grep asus-server
```

### Services Not Starting

```bash
# Check status
./scripts/status.sh

# Check Traefik
ssh asus-server "docker logs traefik --tail=50"

# Restart Traefik
ssh asus-server "cd /opt/traefik && docker-compose restart"

# Check specific project
ssh asus-server "cd /opt/projects/flow && docker-compose ps"
ssh asus-server "cd /opt/projects/flow && docker-compose logs"
```

### Slow Syncs

```bash
# Check what's being synced
rsync -avzn --delete \
  --exclude 'node_modules' \
  ~/projects/flow/ asus-server:/opt/projects/flow/src/

# The -n flag is dry-run (shows what would sync)
```

**Common causes:**
- Large `node_modules` (should be excluded)
- Git history syncing (should be excluded)
- Binary files (dist/, build/)

---

## 💡 Pro Tips

### 1. Terminal Setup

Use tmux or iTerm2 splits:

```bash
# Split 1: Dev mode
./scripts/dev.sh flow

# Split 2: Status watch
watch -n 5 ./scripts/status.sh

# Split 3: Git commands
```

### 2. Auto-Save in Editor

Enable auto-save for faster feedback:

**VSCode:** Already enabled in `.vscode/settings.json`

**Other editors:**
- Cursor: Settings → Auto Save → afterDelay
- Sublime: Add `"save_on_focus_lost": true`

### 3. Browser Auto-Refresh

**For frontend changes:** Hot-reload handles this

**For backend changes:** Use a browser extension:
- Chrome: "Auto Refresh Plus"
- Firefox: "Auto Reload"

### 4. Local vs Remote Frontend

**For maximum speed:** Run frontend on Mac, backend on Asus

```bash
# On Mac
cd ~/projects/flow/src/frontend
npm run dev  # Runs on localhost:5173

# Edit .env.local
VITE_API_URL=http://api.flow.local

# Now frontend is instant, backend on Asus
```

### 5. SSH Connection Reuse

Add to `~/.ssh/config`:

```
Host asus-server
    HostName 192.168.1.10
    User thang
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```

This keeps SSH connections alive - much faster for multiple commands.

---

## 📈 Performance Expectations

**Sync speed:**
- Small changes (1-10 files): < 1 second
- Medium changes (50-100 files): 2-3 seconds
- Large changes (500+ files): 5-10 seconds

**Rebuild time:**
- Node.js: 10-30 seconds
- Python: 5-15 seconds
- .NET: 20-45 seconds

**Hot-reload:**
- Frontend changes: Instant (if using dev server)
- Backend changes: Rebuild time + restart (3-5 seconds)

---

## 🎓 Summary

**The workflow in 3 steps:**

1. **Start dev mode:** `./scripts/dev.sh flow`
2. **Edit on Mac:** Any editor you like
3. **View in browser:** `http://flow.local`

Everything else is automatic:
- ✅ Sync
- ✅ Rebuild
- ✅ Restart
- ✅ Logs

**Your Mac stays fast. Your Asus does the heavy lifting. You focus on code.**

---

## 🔗 Related Docs

- [Full Development Workflow](./DEVELOPMENT_WORKFLOW.md) - Deep dive
- [Project Management](./PROJECTS.md) - Adding projects
- [Quick Start](./QUICKSTART.md) - Initial setup
- [Main README](./README.md) - Infrastructure overview

---

**Questions?** Check the troubleshooting section or run `./scripts/status.sh` to diagnose issues.

**Happy coding! 🚀**
