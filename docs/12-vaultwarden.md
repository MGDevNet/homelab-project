# Vaultwarden Installation

## What Is It

Vaultwarden is a self-hosted password manager that is fully compatible with
all Bitwarden apps and browser extensions. It stores all your passwords,
TOTP codes, secure notes and credit cards on your own hardware — nothing
goes to any cloud service.

## Why You Need It

Your passwords never leave your home network. No subscription, no cloud
dependency, no trust required in a third party. Works with the official
Bitwarden apps on iOS, Android, Windows, Mac and all browsers.

## Enterprise Equivalent

CyberArk or HashiCorp Vault — enterprise credential management.

## VM Details

- **VM:** 210
- **IP:** 192.168.11.51
- **Node:** pve2 (HA on Ceph)
- **RAM:** 512 MB
- **SSH:** `ssh admin@192.168.11.51`

---

## Installation

SSH into VM 210:
```bash
ssh admin@192.168.11.51
```

Update and install Docker:
```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker admin
newgrp docker
```

Create Vaultwarden directory:
```bash
mkdir -p ~/vaultwarden && cd ~/vaultwarden

cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - 80:80
    volumes:
      - ./data:/data
    environment:
      DOMAIN: https://vault.home.lab
      SIGNUPS_ALLOWED: "true"
      ADMIN_TOKEN: "changeme-generate-a-secure-token"
      WEBSOCKET_ENABLED: "true"
EOF
```

Generate a secure admin token:
```bash
# Generate random token
openssl rand -base64 48
# Replace "changeme-generate-a-secure-token" in docker-compose.yml with this
```

Start Vaultwarden:
```bash
docker compose up -d
docker compose logs -f
```

---

## Initial Setup

Open the web UI:
```
http://192.168.11.51
```

Create your account:
1. Click **Create Account**
2. Enter your email and a strong master password
3. Log in

---

## Configure Bitwarden Apps

In the Bitwarden app (iOS, Android, browser extension):

1. On the login screen tap **Self-hosted**
2. Server URL: `https://vault.home.lab` (after NPM is configured)
   Or: `http://192.168.11.51` (direct IP, no SSL)
3. Log in with your credentials

---

## Admin Panel

Access the admin panel:
```
http://192.168.11.51/admin
```

Enter your `ADMIN_TOKEN` from docker-compose.yml.

From here you can:
- Manage users
- Send invitations
- View statistics
- Configure SMTP for email notifications

---

## Verification

```bash
docker ps
curl http://192.168.11.51
```

---

## Important Notes

- **SIGNUPS_ALLOWED: "true"** — set to `"false"` after creating your account
  to prevent others from registering
- Back up the `~/vaultwarden/data/` directory regularly — it contains your
  entire password database
- PBS backs this up nightly since the VM is on Ceph
