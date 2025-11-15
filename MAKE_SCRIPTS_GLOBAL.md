# Making Scripts Global - Quick Guide

## Create Symlinks (Recommended)

```bash
# Navigate to your mini-server directory
cd ~/mini-server

# Create symlinks with clean names
sudo ln -s "$(pwd)/scripts/onboard-project.sh" /usr/local/bin/onboard
sudo ln -s "$(pwd)/scripts/dev.sh" /usr/local/bin/dev
sudo ln -s "$(pwd)/scripts/status.sh" /usr/local/bin/asus-status
sudo ln -s "$(pwd)/scripts/projects.sh" /usr/local/bin/asus-projects
sudo ln -s "$(pwd)/scripts/secure-local.sh" /usr/local/bin/asus-secure
sudo ln -s "$(pwd)/scripts/setup-git-on-asus.sh" /usr/local/bin/asus-setup-git
```

Now use from anywhere:
```bash
onboard git@github.com:you/project.git
dev tradewhispr
asus-status
asus-projects status
asus-secure
```

## Remove Symlinks

```bash
sudo rm /usr/local/bin/onboard
sudo rm /usr/local/bin/dev
sudo rm /usr/local/bin/asus-status
sudo rm /usr/local/bin/asus-projects
sudo rm /usr/local/bin/asus-secure
sudo rm /usr/local/bin/asus-setup-git
```

## Alternative: Shell Alias (No Sudo)

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
# Asus Mini-Server Aliases
alias onboard="~/mini-server/scripts/onboard-project.sh"
alias dev="~/mini-server/scripts/dev.sh"
alias asus-status="~/mini-server/scripts/status.sh"
alias asus-projects="~/mini-server/scripts/projects.sh"
alias asus-secure="~/mini-server/scripts/secure-local.sh"
```

Then reload:
```bash
source ~/.zshrc
```

Remove aliases: Just delete the lines from `~/.zshrc`

## Which to Use?

**Symlinks:**
- ✅ Works system-wide (all users)
- ✅ Works in scripts and interactive shell
- ⚠️ Requires sudo

**Aliases:**
- ✅ No sudo needed
- ✅ Easy to add/remove
- ⚠️ Only works in interactive shell (not in scripts)

**Recommendation: Use symlinks** for the most flexibility.
