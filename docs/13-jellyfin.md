# Jellyfin Media Server Installation

## What Is It

Jellyfin is your personal Netflix. It streams movies, TV shows and music
to any device — phones, smart TVs, browsers, Roku, Apple TV, Fire Stick.
It transcodes video on the fly to match each device's capabilities.
Free, open source, no subscription required.

## Why You Need It

All your media in one place, accessible from anywhere on your network or
remotely via Nginx Proxy Manager. No Plex subscription, no data sent to
any company, no limits on simultaneous streams.

## Enterprise Equivalent

Similar in concept to enterprise Digital Asset Management (DAM) platforms
or internal media distribution systems.

## VM Details

- **VM:** 110
- **IP:** 192.168.11.56
- **Node:** pve1
- **RAM:** 4 GB / 3 cores
- **SSH:** `ssh admin@192.168.11.56`

## Media Storage

Media files live on TrueNAS SMB share — NOT on the VM disk:
- Movies/TV: `//192.168.11.200/media`
- The VM disk only stores Jellyfin config and metadata

---

## Installation

SSH into VM 110:
```bash
ssh admin@192.168.11.56
```

Update system and install dependencies:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg2
```

Add Jellyfin repository:
```bash
curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/jellyfin.gpg] \
  https://repo.jellyfin.org/ubuntu noble main" | \
  sudo tee /etc/apt/sources.list.d/jellyfin.list

sudo apt update
sudo apt install -y jellyfin
```

Enable and start:
```bash
sudo systemctl enable jellyfin
sudo systemctl start jellyfin
```

---

## Mount TrueNAS Media Share

Install CIFS client:
```bash
sudo apt install -y cifs-utils
```

Create mount point:
```bash
sudo mkdir -p /mnt/media
```

Add to `/etc/fstab` for permanent mount:
```bash
echo "//192.168.11.200/media /mnt/media cifs \
  guest,uid=jellyfin,gid=jellyfin,iocharset=utf8,vers=3.0 0 0" | \
  sudo tee -a /etc/fstab

sudo mount -a
ls /mnt/media
```

---

## Initial Setup

Open Jellyfin web UI:
```
http://192.168.11.56:8096
```

Follow the setup wizard:

1. Create admin account
2. Add media libraries:
   - **Movies** → `/mnt/media/movies`
   - **TV Shows** → `/mnt/media/tv`
   - **Music** → `/mnt/media/music` (if you have it)
3. Wait for library scan to complete

---

## Hardware Transcoding (Intel QuickSync)

The i5-9500T supports Intel QuickSync for hardware transcoding.
Enable it in Jellyfin:

```bash
# Check Intel GPU is visible
ls /dev/dri/
# Should show renderD128

# Add jellyfin user to render group
sudo usermod -aG render jellyfin
sudo usermod -aG video jellyfin
sudo systemctl restart jellyfin
```

In Jellyfin web UI:
```
Dashboard → Playback → Transcoding
  Hardware acceleration: Intel QuickSync Video (QSV)
  Enable hardware encoding: YES
```

---

## Nginx Proxy Manager Config

After NPM is set up, add proxy host:
```
Domain: jellyfin.home.lab
Forward Host: 192.168.11.56
Forward Port: 8096
Enable Websockets: YES
```

Add DNS rewrite in AdGuard:
```
jellyfin.home.lab → 192.168.11.50
```

---

## Verification

```bash
sudo systemctl status jellyfin
curl http://192.168.11.56:8096/health
```

Expected: `{"Status":"Healthy"}`
