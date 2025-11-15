# VS Code Remote-SSH Development on Asus

**TL;DR:** This is probably the best approach for your workflow.

## Why Remote-SSH?

Instead of syncing files Mac→Asus, use VS Code Remote-SSH to code **directly on Asus** while using your Mac's VS Code UI.

**Benefits:**
- ✅ Use VS Code on Mac (your favorite editor)
- ✅ Files live on Asus (no sync needed)
- ✅ Terminal runs on Asus (instant docker commands)
- ✅ Extensions run on Asus (linting, IntelliSense work with Asus environment)
- ✅ Zero sync delay
- ✅ Simpler workflow

## Setup (5 minutes)

### 1. Install VS Code Extension

On your Mac:
```bash
# Install Remote-SSH extension
code --install-extension ms-vscode-remote.remote-ssh
```

Or: VS Code → Extensions → Search "Remote - SSH" → Install

### 2. Configure SSH Connection

Add to `~/.ssh/config` on Mac:

```
Host asus-server
    HostName 192.168.1.10
    User thang
    ForwardAgent yes
    ServerAliveInterval 60
```

### 3. Connect to Asus

In VS Code:
1. Press `Cmd+Shift+P`
2. Type "Remote-SSH: Connect to Host"
3. Select "asus-server"
4. New VS Code window opens connected to Asus!

### 4. Open Project

In the remote VS Code window:
```
File → Open Folder → /opt/projects/tradewhispr
```

## Daily Workflow

### Morning:
```bash
# In VS Code: Cmd+Shift+P → "Remote-SSH: Connect to Host" → asus-server
# Open folder: /opt/projects/tradewhispr
```

### Development:
- Edit files in VS Code (they're actually on Asus)
- Use VS Code's integrated terminal (runs on Asus)
- Docker commands run instantly (no network delay)

```bash
# In VS Code terminal (already on Asus):
cd /opt/projects/tradewhispr
docker-compose up -d
docker-compose logs -f
```

### Browser:
- Open http://tradewhispr.local
- Changes are instant (no sync!)

## Comparison with Sync Workflow

| Feature | Remote-SSH | Mac→Asus Sync |
|---------|-----------|---------------|
| Editor | VS Code on Mac | VS Code on Mac |
| Files location | Asus | Mac (synced to Asus) |
| Sync delay | None | 2 seconds |
| Terminal | Asus (instant) | Mac (SSH needed) |
| Git operations | Asus | Mac |
| Extensions | Run on Asus | Run on Mac |
| Network dependency | Yes (for editing) | Yes (for sync) |
| Setup complexity | Simple | More complex |

## Pro Tips

### 1. Install Extensions on Remote

Some extensions need to be installed on the Asus server:
- Python
- ESLint
- Prettier
- Docker

VS Code will prompt you automatically.

### 2. Use VS Code Terminal

The integrated terminal runs directly on Asus:
```bash
# No need for ssh commands - you're already there!
docker-compose up -d
docker-compose logs -f
npm run dev
python manage.py runserver
```

### 3. Port Forwarding

VS Code automatically forwards ports! If your app runs on port 3000 on Asus, VS Code will forward it to `localhost:3000` on Mac.

### 4. Multiple Projects

Open multiple VS Code windows, each connected to different projects:
```
Window 1: asus-server → /opt/projects/flow
Window 2: asus-server → /opt/projects/tradewhispr
Window 3: asus-server → /opt/projects/client-a
```

### 5. Git on Asus

Your git config needs to be on Asus:
```bash
ssh asus-server
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

## When to Use Each Approach

### Use Remote-SSH If:
- ✅ You want simplicity
- ✅ You're comfortable with VS Code
- ✅ You have stable network to Asus
- ✅ You want instant feedback (no sync delay)

### Use Mac→Asus Sync If:
- ✅ You want files on Mac (for backup/offline work)
- ✅ You use multiple editors
- ✅ You prefer Mac's filesystem for git operations
- ✅ Network is unstable (can work offline, sync later)

### Use SSH + Vim/Emacs If:
- ✅ You're a terminal wizard
- ✅ You prefer terminal editors
- ✅ You want ultimate simplicity

## Recommended: Try Remote-SSH First

For most developers, Remote-SSH is the sweet spot:
- Simple setup
- Fast workflow
- Best of both worlds

The sync workflow is great for specific use cases, but for your needs (coding on Mac, running on Asus), Remote-SSH is probably cleaner.

## Switching from Sync to Remote-SSH

If you want to switch:

1. **Stop using dev.sh**
2. **SSH your projects to Asus** (if not already there)
3. **Connect with VS Code Remote-SSH**
4. **Code directly on Asus**

Projects already on Asus from sync workflow? Perfect! Just open them with Remote-SSH.

## Both Workflows Work!

The sync workflow (`dev.sh`) is still useful for:
- Working offline on Mac
- Wanting local copies of everything
- Using multiple editors (VS Code + Cursor + Sublime)

Remote-SSH is simpler for most cases. Try it and see what you prefer!
