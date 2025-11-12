# Ubuntu Fresh Installation Guide

This guide will help you wipe your Asus laptop and perform a fresh Ubuntu 22.04 installation with optimal settings for a mini-server.

## Phase 1: Preparation

### What You'll Need

- USB drive (8GB minimum)
- Ubuntu 22.04 LTS Desktop ISO ([download here](https://ubuntu.com/download/desktop))
- Backup of any important data from the Asus laptop
- Ethernet cable (recommended for initial setup)

### Step 1: Create Bootable USB

#### On macOS:

```bash
# Download Ubuntu 22.04 ISO
# Insert USB drive

# Find the USB drive
diskutil list

# Unmount the drive (replace N with your disk number)
diskutil unmountDisk /dev/diskN

# Write ISO to USB (this will take 5-10 minutes)
sudo dd if=~/Downloads/ubuntu-22.04.x-desktop-amd64.iso of=/dev/rdiskN bs=1m

# Eject the USB
diskutil eject /dev/diskN
```

#### Alternative: Use Etcher

1. Download [balenaEtcher](https://www.balena.io/etcher/)
2. Select Ubuntu ISO
3. Select USB drive
4. Click "Flash!"

### Step 2: Backup Current System (if needed)

If you have important data on the Asus:

```bash
# Backup home directory
rsync -av --progress /home/username/ /path/to/backup/

# Backup specific configuration
tar -czf configs_backup.tar.gz \
  ~/.ssh \
  ~/.bashrc \
  ~/.profile \
  /etc/hostname \
  /etc/hosts
```

## Phase 2: Installation

### Step 1: Boot from USB

1. Insert USB drive into Asus laptop
2. Restart the laptop
3. Press **F2** or **Del** repeatedly during boot to enter BIOS
   - (Key varies by Asus model - try F2, Del, or F10)
4. In BIOS:
   - Disable Secure Boot (if enabled)
   - Set USB as first boot device
   - Save and exit (F10)

### Step 2: Install Ubuntu 22.04

1. **Select "Install Ubuntu"** from the boot menu
2. **Language**: Choose your language
3. **Keyboard Layout**: Select your keyboard layout
4. **Updates and Software**:
   - ✅ Normal installation
   - ✅ Download updates while installing
   - ✅ Install third-party software (for hardware support)
5. **Installation Type**:
   - **Recommended**: "Erase disk and install Ubuntu"
   - **Advanced**: Manual partitioning (see below)
6. **Timezone**: Select your timezone
7. **User Setup**:
   - Your name: (your name)
   - Computer name: `asus-mini-server`
   - Username: (your username)
   - Password: (strong password)
   - ✅ Require password to log in
8. **Install** and wait (10-20 minutes)
9. **Restart** when prompted and remove USB drive

### Advanced: Manual Partitioning (Optional)

For better control, create these partitions:

```
/dev/sda1  - 512MB  - EFI System Partition
/dev/sda2  - 50GB   - ext4 - Mount: /
/dev/sda3  - 16GB   - swap - (same size as RAM)
/dev/sda4  - Rest   - ext4 - Mount: /home
```

Or for Docker on separate partition:

```
/dev/sda1  - 512MB   - EFI System Partition
/dev/sda2  - 50GB    - ext4 - Mount: /
/dev/sda3  - 16GB    - swap
/dev/sda4  - 100GB   - ext4 - Mount: /var/lib/docker
/dev/sda5  - Rest    - ext4 - Mount: /home
```

## Phase 3: Post-Installation Setup

### Step 1: Initial System Update

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y openssh-server git curl wget vim
```

### Step 2: Configure SSH Access

```bash
# Enable SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Get IP address
ip addr show

# From your Mac, copy SSH key:
ssh-copy-id username@asus-ip-address

# Test SSH connection
ssh username@asus-ip-address
```

### Step 3: Disable GUI (Optional - Save Resources)

Since this is a server, you can disable the desktop environment:

```bash
# Set to boot to console
sudo systemctl set-default multi-user.target

# Disable display manager
sudo systemctl disable gdm3

# Reboot
sudo reboot

# To re-enable GUI later:
sudo systemctl set-default graphical.target
sudo systemctl enable gdm3
```

### Step 4: Configure Static IP (Recommended)

#### Using Netplan (Ubuntu 22.04):

```bash
# Backup current config
sudo cp /etc/netplan/01-network-manager-all.yaml /etc/netplan/01-network-manager-all.yaml.bak

# Edit netplan config
sudo nano /etc/netplan/01-netcfg.yaml
```

Add this configuration:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:  # Replace with your interface name (use `ip link` to find it)
      dhcp4: no
      addresses:
        - 192.168.1.100/24  # Your desired static IP
      gateway4: 192.168.1.1   # Your router IP
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply configuration:

```bash
# Test configuration
sudo netplan try

# If it works, apply permanently
sudo netplan apply
```

### Step 5: Optimize for Server Use

```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups  # Printer service
sudo systemctl disable avahi-daemon  # Bonjour

# Install server utilities
sudo apt install -y \
  htop \
  ncdu \
  tmux \
  net-tools \
  ufw

# Configure swappiness (reduce swap usage)
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Phase 4: Run Ansible Automation

Now that Ubuntu is installed, use Ansible to complete the setup:

### From Your Mac:

```bash
# Clone the mini-server repo
cd ~/projects
git clone <your-mini-server-repo> mini-server
cd mini-server

# Update inventory with Asus server IP
nano ansible/inventory/hosts.yml

# Run complete setup
make setup

# Deploy projects
make deploy-all
```

## Troubleshooting

### Can't boot from USB

- Try different USB port
- Recreate bootable USB with different tool
- Check BIOS boot order
- Disable Secure Boot in BIOS

### Wi-Fi not working

```bash
# Install additional drivers
sudo ubuntu-drivers autoinstall
sudo reboot
```

### Cannot SSH into server

```bash
# Check SSH service status
sudo systemctl status ssh

# Check firewall
sudo ufw status
sudo ufw allow 22/tcp
sudo ufw enable

# Check IP address
ip addr show
```

### System running slow

```bash
# Check resource usage
htop

# Check disk usage
df -h
du -sh /*

# Clean up
sudo apt autoremove
sudo apt clean
```

## Performance Tuning

### For Docker/Container Workloads:

```bash
# Increase file descriptors
echo "fs.file-max = 2097152" | sudo tee -a /etc/sysctl.conf

# Increase inotify watches
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

### For Better Network Performance:

```bash
# Increase network buffers
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

## Useful Post-Install Commands

```bash
# Check system information
uname -a
lsb_release -a

# Check hardware
lscpu
free -h
df -h

# Check network
ip addr show
nmcli device status

# Check services
systemctl list-units --type=service --state=running

# Check logs
journalctl -xe
```

## Next Steps

After fresh installation and Ansible setup:

1. ✅ Ubuntu 22.04 installed
2. ✅ SSH access configured
3. ✅ Static IP set (optional)
4. ✅ GUI disabled (optional)
5. ✅ Run `make setup` from Mac
6. ✅ Deploy projects with `make deploy-all`
7. ✅ Configure `/etc/hosts` on Mac
8. ✅ Access services via browser

## Backup Strategy

Once everything is set up:

```bash
# Create system snapshot script
cat > /home/username/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=/opt/backups
mkdir -p $BACKUP_DIR

# Backup databases
docker exec flow-db pg_dump -U flowuser flowdb > $BACKUP_DIR/flow_$(date +%Y%m%d).sql
docker exec tradewhispr-db pg_dump -U tradewhispruser tradewhisprdb > $BACKUP_DIR/tradewhispr_$(date +%Y%m%d).sql

# Backup Docker volumes
docker run --rm -v flow-db-data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/flow-volumes_$(date +%Y%m%d).tar.gz /data

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /home/username/backup.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/username/backup.sh") | crontab -
```

## Resources

- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Documentation](https://docs.docker.com/)

---

**Note**: This guide assumes you're starting fresh. If you need to preserve data, make sure to backup before proceeding with the installation!
