# Media Stack — Complete Setup

The media stack provides a self-hosted Netflix-like experience that automatically finds, downloads and organizes movies and TV shows.

## Stack Components

| Service | IP | Purpose |
|---|---|---|
| Jellyfin | 192.168.11.56 | Streams media to your devices |
| Jellyseerr | 192.168.11.22:5055 | Request portal — browse and request like Netflix |
| Sonarr | 192.168.11.21:8989 | Automatically downloads TV shows |
| Radarr | 192.168.11.21:7878 | Automatically downloads movies |
| Prowlarr | 192.168.11.22:9696 | Finds torrent indexers |
| qBittorrent | 192.168.11.22:8080 | Downloads torrents |

## Data Flow

```
You browse Jellyseerr → request a movie or show
        ↓
Jellyseerr tells Sonarr/Radarr what to find
        ↓
Sonarr/Radarr ask Prowlarr to search indexers
        ↓
Prowlarr returns torrent links
        ↓
Sonarr/Radarr send torrent to qBittorrent
        ↓
qBittorrent downloads to /downloads/complete
        ↓
Sonarr/Radarr import file to /media/movies or /media/tv
        ↓
Jellyfin scans /media and shows new content
        ↓
You watch on phone, TV, browser, anywhere
```

## Storage Layout

All shared via NFS from TrueNAS:

```
TrueNAS data pool
├── /mnt/data/media       → Movies and TV shows (Jellyfin reads from here)
│   ├── movies/
│   └── tv/
├── /mnt/data/downloads   → qBittorrent downloads here
│   ├── complete/         → Finished downloads (Sonarr/Radarr import from here)
│   └── incomplete/       → Active downloads
└── /mnt/data/photos      → Immich photos
```

## Critical Setup — LXC Container Bind Mounts

The media stack runs in two LXC containers (CT 102 and CT 103). For Docker inside the LXC to see the NFS shares from TrueNAS, you must:

1. Mount the NFS shares on the **Proxmox host** (pve1)
2. Add **bind mount points** in the LXC container config

```bash
# On pve1 — mount NFS shares
mkdir -p /mnt/pve/truenas-media
mkdir -p /mnt/pve/truenas-downloads

mount -t nfs 192.168.40.200:/mnt/data/media /mnt/pve/truenas-media
mount -t nfs 192.168.40.200:/mnt/data/downloads /mnt/pve/truenas-downloads

# Make permanent
echo "192.168.40.200:/mnt/data/media /mnt/pve/truenas-media nfs rw,hard,intr 0 0" >> /etc/fstab
echo "192.168.40.200:/mnt/data/downloads /mnt/pve/truenas-downloads nfs rw,hard,intr 0 0" >> /etc/fstab
```

Add bind mounts to LXC containers:

```bash
# CT 102 (Radarr + Sonarr) — needs both media and downloads
pct stop 102
pct set 102 -mp0 /mnt/pve/truenas-media,mp=/mnt/media
pct set 102 -mp1 /mnt/pve/truenas-downloads,mp=/mnt/downloads
pct start 102

# CT 103 (Prowlarr + qBittorrent + Jellyseerr) — needs both
pct stop 103
pct set 103 -mp0 /mnt/pve/truenas-media,mp=/mnt/media
pct set 103 -mp1 /mnt/pve/truenas-downloads,mp=/mnt/downloads
pct start 103
```

Verify mounts inside containers:

```bash
pct exec 102 -- bash -c "ls /mnt/media /mnt/downloads"
pct exec 103 -- bash -c "ls /mnt/media /mnt/downloads"
```

Both should show `movies`, `tv`, `complete`, `incomplete`.

## Permissions

LinuxServer Docker images run as UID/GID 1000 by default. Fix NFS permissions:

```bash
# On pve1
chown -R 1000:1000 /mnt/pve/truenas-media
chown -R 1000:1000 /mnt/pve/truenas-downloads
chmod -R 777 /mnt/pve/truenas-media
chmod -R 777 /mnt/pve/truenas-downloads
```

## CT 102 — Radarr + Sonarr Deployment

```bash
pct exec 102 -- bash -c "apt update && apt install -y curl"
pct exec 102 -- bash -c "curl -fsSL https://get.docker.com | sh"

pct exec 102 -- bash -c "mkdir -p /opt/mediastack && cat > /opt/mediastack/docker-compose.yml << 'EOF'
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    ports:
      - 7878:7878
    volumes:
      - ./radarr/config:/config
      - /mnt/media:/media
      - /mnt/downloads:/downloads

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    ports:
      - 8989:8989
    volumes:
      - ./sonarr/config:/config
      - /mnt/media:/media
      - /mnt/downloads:/downloads
EOF"

pct exec 102 -- bash -c "cd /opt/mediastack && docker compose up -d"
```

## CT 103 — Prowlarr + qBittorrent + Jellyseerr Deployment

```bash
pct exec 103 -- bash -c "apt update && apt install -y curl"
pct exec 103 -- bash -c "curl -fsSL https://get.docker.com | sh"

pct exec 103 -- bash -c "mkdir -p /opt/mediastack && cat > /opt/mediastack/docker-compose.yml << 'EOF'
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    ports:
      - 9696:9696
    volumes:
      - ./prowlarr/config:/config

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - WEBUI_PORT=8080
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    volumes:
      - ./qbittorrent/config:/config
      - /mnt/downloads:/downloads

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    restart: unless-stopped
    environment:
      - TZ=America/New_York
    ports:
      - 5055:5055
    volumes:
      - ./jellyseerr/config:/app/config
EOF"

pct exec 103 -- bash -c "cd /opt/mediastack && docker compose up -d"
```

## Configuration Order

### 1. qBittorrent
- Get temporary password from logs: `docker logs qbittorrent | grep -i password`
- Login at `http://qbit.home.lab` with `admin` / temp password
- Settings → WebUI → set permanent password
- Settings → Downloads:
  ```
  Default Save Path: /downloads/complete
  Keep incomplete in: /downloads/incomplete
  ```

### 2. Prowlarr
- Open `http://prowlarr.home.lab`
- Indexers → Add Indexer → search and add:
  - YTS (movies)
  - EZTV (TV)
  - 1337x (general)
  - The Pirate Bay
  - Nyaa (anime)
- Settings → Apps → wait until after configuring Radarr and Sonarr below

### 3. Radarr
- Open `http://radarr.home.lab`
- Settings → Media Management → Root Folders → Add: `/media/movies`
- Settings → Download Clients → Add → qBittorrent:
  ```
  Host: 192.168.11.22
  Port: 8080
  Username/Password: from qBittorrent
  Category: movies
  ```
- Settings → General → API Key → copy this for Prowlarr

### 4. Sonarr
- Open `http://sonarr.home.lab`
- Settings → Media Management → Root Folders → Add: `/media/tv`
- Settings → Download Clients → Add → qBittorrent:
  ```
  Host: 192.168.11.22
  Port: 8080
  Username/Password: from qBittorrent
  Category: tv
  ```
- Settings → General → API Key → copy this for Prowlarr

### 5. Connect Prowlarr to Radarr/Sonarr
- Back to Prowlarr → Settings → Apps → Add:
  - Radarr URL: `http://192.168.11.21:7878`, paste API key
  - Sonarr URL: `http://192.168.11.21:8989`, paste API key

### 6. Jellyfin
- Open `https://jellyfin.home.lab`
- Dashboard → Libraries → Add:
  - Movies → `/media/movies`
  - TV Shows → `/media/tv`
- Set admin email under Users → admin → Edit (needed for Jellyseerr)

### 7. Jellyseerr
- Open `http://jellyseerr.home.lab`
- Setup wizard:
  - Server type: Jellyfin
  - URL: `http://192.168.11.56`, port 8096
  - Email + admin/PUTPASSWD_HERE credentials
- Settings → Services:
  - Add Radarr server with API key, root folder `/media/movies`
  - Add Sonarr server with API key, root folder `/media/tv`

## Important Lessons

1. **NFS mounts must be on the Proxmox host first**, then bind-mounted into LXC containers. LXC containers cannot mount NFS directly.

2. **Both LXC containers need media AND downloads mounts** because Sonarr/Radarr need to read from `/downloads` and write to `/media`.

3. **qBittorrent saves to `/downloads/complete`** — the same path Sonarr and Radarr import from. No Remote Path Mapping is needed when both are bind-mounted to the same NFS share.

4. **Jellyfin needs to be restarted** after the NFS mount is added so the Docker volume picks up the content.

5. **Permissions matter** — NFS shares must be world-writable (777) and owned by UID 1000 since LinuxServer Docker images use that UID.
