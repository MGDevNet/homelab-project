# Nginx Proxy Manager Installation

## What Is It

Nginx Proxy Manager is a reverse proxy with a friendly web UI. It gives every
service in your homelab a clean domain name like `jellyfin.home.lab` instead
of an IP and port number. It also handles SSL certificates automatically via
Let's Encrypt so all your services get HTTPS.

## Why You Need It

Without NPM you access services like this:
```
http://192.168.11.56:8096  ← Jellyfin
http://192.168.11.59:8080  ← Zabbix
http://192.168.11.51:80    ← Vaultwarden
```

With NPM you access them like this:
```
https://jellyfin.home.lab   ← clean, memorable, SSL
https://zabbix.home.lab     ← clean, memorable, SSL
https://vault.home.lab      ← clean, memorable, SSL
```

## Enterprise Equivalent

F5 BIG-IP or HAProxy — reverse proxy and SSL termination in front of internal services.

## VM Details

- **VM:** 200
- **IP:** 192.168.11.50
- **Node:** pve2 (HA on Ceph)
- **RAM:** 512 MB
- **SSH:** `ssh admin@192.168.11.50`

---

## Installation

SSH into VM 200:
```bash
ssh admin@192.168.11.50
```

Update system:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg2
```

Install Docker:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker admin
newgrp docker
```

Create NPM directory and config:
```bash
mkdir -p ~/npm && cd ~/npm

cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
      - 81:81
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
```

Start NPM:
```bash
docker compose up -d
docker compose logs -f
```

---

## Initial Setup

Open the NPM web UI:
```
http://192.168.11.50:81
```

Default credentials:
```
Email:    admin@example.com
Password: changeme
```

Change them immediately when prompted.

---

## Adding Proxy Hosts

For each service add a proxy host:

**Example — Jellyfin:**
```
Domain Names:  jellyfin.home.lab
Scheme:        http
Forward Host:  192.168.11.56
Forward Port:  8096
```

Enable **Block Common Exploits** and **Websockets Support**.

---

## Adding Local DNS in AdGuard

For local domain names to resolve, add DNS rewrites in AdGuard:

Go to `http://192.168.11.20` → **Filters → DNS Rewrites → Add**:

```
jellyfin.home.lab  → 192.168.11.50
vault.home.lab     → 192.168.11.50
nextcloud.home.lab → 192.168.11.50
grafana.home.lab   → 192.168.11.50
unifi.home.lab     → 192.168.11.50
zabbix.home.lab    → 192.168.11.50
immich.home.lab    → 192.168.11.50
```

All pointing to the NPM IP (192.168.11.50) — NPM routes them to the right service.

---

## Verification

```bash
# Check NPM is running
docker ps

# Check ports
ss -tlnp | grep -E '80|81|443'
```

Test from another machine:
```
curl http://192.168.11.50:81
```
