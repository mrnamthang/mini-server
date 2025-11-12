# Development Helper Scripts

These scripts streamline the development workflow between your Mac and the Asus mini server.

## 🚀 Quick Setup

### Step 1: Configure Scripts

Run the setup script to configure your server details:

```bash
cd scripts
chmod +x setup-scripts.sh
./setup-scripts.sh
```

This will prompt for:
- Asus server hostname/IP
- Your username on the server

### Step 2: Test Connection

The setup script will automatically test SSH connection. If it fails:

```bash
# Copy your SSH key to the server
ssh-copy-id your-username@asus-server-ip
```

## 📜 Available Scripts

### 1. `sync-to-asus.sh` - Manual Sync

Sync your local project to the Asus server.

```bash
# Sync Flow project
./sync-to-asus.sh flow

# Sync Tradewhispr project
./sync-to-asus.sh tradewhispr
```

**What it does:**
- Syncs all files from `~/projects/{project}` to server
- Excludes unnecessary files (node_modules, .git, etc.)
- Uses rsync for fast incremental updates

### 2. `watch-and-sync.sh` - Auto Sync

Watch for changes and automatically sync to Asus.

```bash
# Watch Flow project
./watch-and-sync.sh flow

# Watch Tradewhispr project
./watch-and-sync.sh tradewhispr
```

**What it does:**
- Monitors your project directory for changes
- Automatically syncs changes to Asus (2-second delay for batching)
- Runs in foreground - run in separate terminal or tmux pane

**Requirements:**
- `fswatch` must be installed: `brew install fswatch`

**Recommended usage:**
```bash
# Run in background terminal or tmux pane
tmux new -s sync
./watch-and-sync.sh flow
# Detach: Ctrl+b, then d
```

### 3. `rebuild-on-asus.sh` - Rebuild Service

Rebuild and restart a Docker service on Asus.

```bash
# Flow examples
./rebuild-on-asus.sh flow flow-api
./rebuild-on-asus.sh flow flow-web

# Tradewhispr examples
./rebuild-on-asus.sh tradewhispr tradewhispr-backend
./rebuild-on-asus.sh tradewhispr tradewhispr-frontend
./rebuild-on-asus.sh tradewhispr tradewhispr-celery-worker
```

**What it does:**
- Builds Docker image on Asus
- Restarts the service
- Shows service status

**When to use:**
- Backend code changes (API logic, database models, etc.)
- Dependency changes (package.json, requirements.txt, .csproj)
- Dockerfile changes
- Environment variable changes

**Not needed for:**
- Frontend hot-reload changes (automatic)
- Configuration file changes (just restart with docker-compose)

### 4. `logs.sh` - View Logs

View logs from services running on Asus.

```bash
# All Flow services
./logs.sh flow

# Specific Flow service
./logs.sh flow flow-api
./logs.sh flow flow-web
./logs.sh flow flow-db

# All Tradewhispr services
./logs.sh tradewhispr

# Specific Tradewhispr service
./logs.sh tradewhispr tradewhispr-backend
./logs.sh tradewhispr tradewhispr-frontend
./logs.sh tradewhispr tradewhispr-celery-worker
./logs.sh tradewhispr tradewhispr-redis
```

**What it does:**
- Shows last 100 lines of logs
- Follows logs in real-time (like `tail -f`)
- Press Ctrl+C to stop

## 🎯 Typical Workflows

### Workflow 1: Full Stack Development

**Terminal 1: Auto-sync**
```bash
cd ~/projects/mini-server/scripts
./watch-and-sync.sh flow
```

**Terminal 2: View logs**
```bash
cd ~/projects/mini-server/scripts
./logs.sh flow flow-api
```

**Terminal 3: Development**
```bash
cd ~/projects/flow
code .  # Edit code in VS Code
```

Changes auto-sync → View logs → Test in browser (http://flow.local)

### Workflow 2: Backend Development Only

```bash
# 1. Edit backend code
cd ~/projects/flow/src/Flow.Api
code Controllers/ProjectsController.cs

# 2. Sync changes
cd ~/projects/mini-server/scripts
./sync-to-asus.sh flow

# 3. Rebuild API
./rebuild-on-asus.sh flow flow-api

# 4. View logs
./logs.sh flow flow-api

# 5. Test
curl http://api.flow.local/api/projects
```

### Workflow 3: Frontend Development Only

```bash
# Option A: Frontend on Asus with hot-reload
# 1. Start auto-sync
./watch-and-sync.sh flow &

# 2. Edit code
cd ~/projects/flow/src/flow-web
code .

# 3. View in browser
open http://flow.local

# Changes auto-sync and hot-reload on Asus


# Option B: Frontend on Mac, backend on Asus
# 1. Run frontend locally
cd ~/projects/flow/src/flow-web
npm install
npm run dev

# 2. Configure to use Asus backend
echo "VITE_API_URL=http://api.flow.local" > .env.local

# 3. Access
open http://localhost:5173
```

### Workflow 4: Database Changes

```bash
# 1. Edit migration/model
cd ~/projects/flow/src/Flow.Domain
code Entities/Project.cs

# 2. Sync
cd ~/projects/mini-server/scripts
./sync-to-asus.sh flow

# 3. Create migration
ssh asus-server "docker exec flow-api dotnet ef migrations add AddNewField"

# 4. Apply migration
ssh asus-server "docker exec flow-api dotnet ef database update"

# 5. Rebuild API (if needed)
./rebuild-on-asus.sh flow flow-api
```

## 🔧 Configuration

### Customizing Sync Exclusions

Edit `sync-to-asus.sh` and modify the `rsync` command:

```bash
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude 'your-custom-exclusion' \  # Add here
  ...
```

### Changing Project Location

If your projects are not in `~/projects/`, update the scripts:

```bash
# In sync-to-asus.sh
LOCAL_DIR="$HOME/your-custom-path/$PROJECT"

# In watch-and-sync.sh
LOCAL_DIR="$HOME/your-custom-path/$PROJECT"
```

### Custom Server Configuration

Update these variables in each script:

```bash
ASUS_HOST="your-server-hostname-or-ip"
ASUS_USER="your-username"
```

Or use `setup-scripts.sh` to update all scripts at once.

## 🐛 Troubleshooting

### "Command not found: fswatch"

Install fswatch:
```bash
brew install fswatch
```

### "Permission denied" when running scripts

Make scripts executable:
```bash
chmod +x *.sh
```

### SSH connection fails

1. Test SSH manually:
```bash
ssh your-username@asus-server-ip
```

2. If fails, copy SSH key:
```bash
ssh-copy-id your-username@asus-server-ip
```

3. Verify SSH config (`~/.ssh/config`):
```
Host asus-server
    HostName 192.168.1.100
    User your-username
    IdentityFile ~/.ssh/id_rsa
```

### Sync is slow

1. Check network connection:
```bash
ping asus-server-ip
```

2. Use SSH compression (already enabled in scripts)

3. Reduce sync frequency in `watch-and-sync.sh`:
```bash
# Change -l 2 to -l 5 for 5-second delay
fswatch -r -l 5 ...
```

### Changes not reflecting

1. Verify sync completed:
```bash
./sync-to-asus.sh flow
```

2. Check if service is running:
```bash
ssh asus-server "docker ps | grep flow"
```

3. Rebuild service:
```bash
./rebuild-on-asus.sh flow flow-api
```

4. Clear browser cache (Cmd+Shift+R)

### "No such file or directory" error

Ensure projects are cloned to expected locations:

```bash
# Expected structure
~/projects/
├── mini-server/        # This repo
│   └── scripts/        # These scripts
├── flow/               # Flow project
└── tradewhispr/        # Tradewhispr project
```

## 💡 Tips

1. **Use tmux** for persistent terminals:
```bash
tmux new -s dev
# Split panes: Ctrl+b, then "
# Switch panes: Ctrl+b, then arrow keys
# Detach: Ctrl+b, then d
# Reattach: tmux attach -t dev
```

2. **Create shell aliases** in `~/.zshrc`:
```bash
alias sync-flow='~/projects/mini-server/scripts/sync-to-asus.sh flow'
alias watch-flow='~/projects/mini-server/scripts/watch-and-sync.sh flow'
alias rebuild-flow-api='~/projects/mini-server/scripts/rebuild-on-asus.sh flow flow-api'
alias logs-flow='~/projects/mini-server/scripts/logs.sh flow'
```

3. **VS Code tasks** - Create `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Sync to Asus",
      "type": "shell",
      "command": "${workspaceFolder}/../mini-server/scripts/sync-to-asus.sh flow",
      "group": {
        "kind": "build",
        "isDefault": true
      }
    }
  ]
}
```

Then press Cmd+Shift+B to sync!

4. **Monitor mode** - Watch logs and sync in one terminal:
```bash
# Terminal 1
./watch-and-sync.sh flow

# Terminal 2
./logs.sh flow flow-api
```

## 📚 Related Documentation

- [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md) - Complete development workflow guide
- [README.md](../README.md) - Main infrastructure documentation
- [QUICKSTART.md](../QUICKSTART.md) - Quick setup guide

## 🆘 Getting Help

If you encounter issues:

1. Check the [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md) troubleshooting section
2. Test SSH connection manually
3. Verify services are running: `make status`
4. Check Traefik dashboard: http://traefik.local
5. View service logs: `./logs.sh <project> <service>`

---

Happy coding! 🚀
