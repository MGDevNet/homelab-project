# LXC Container Deployment

## Overview

LXC containers are used for lightweight services that don't need their own kernel. They start in seconds, use minimal RAM (as low as 256 MB), and share the host kernel.

**All containers use:**
- Debian 13 (Trixie) template
- Unprivileged mode
- local-lvm storage
- DNS: 192.168.11.20 (AdGuard)

---

## Download Templates (Run on pve1)

```bash
# Update template list
pveam update

# Download Debian 13 — primary template for all LXCs
pveam download truenas-iso debian-13-standard_13.1-2_amd64.tar.zst

# Download Ubuntu 24.04 LTS — for heavier LXC services
pveam download truenas-iso ubuntu-24.04-standard_24.04-2_amd64.tar.zst

# Verify downloaded
ls /mnt/pve/truenas-iso/template/cache/
```

---

## Create All Containers

Run the script on each node:

```bash
# On pve1
bash scripts/containers/create_containers.sh pve1

# On pve2
bash scripts/containers/create_containers.sh pve2

# On pve3
bash scripts/containers/create_containers.sh pve3
```

---

## Start All Containers

```bash
# pve1
for i in 101 102 103 104 105 106; do pct start $i; echo "Started CT $i"; done

# pve2
for i in 201 202 203; do pct start $i; echo "Started CT $i"; done

# pve3
for i in 301 302 303 304; do pct start $i; echo "Started CT $i"; done
```

---

## Fix DNS on All Containers

After AdGuard is running, update all containers to use it:

```bash
# pve1
for ct in 101 102 103 104 105 106; do
  pct set $ct --nameserver 192.168.11.20
  echo "Updated CT $ct DNS"
done

# pve2
for ct in 201 202 203; do
  pct set $ct --nameserver 192.168.11.20
  echo "Updated CT $ct DNS"
done

# pve3
for ct in 301 302 303 304; do
  pct set $ct --nameserver 192.168.11.20
  echo "Updated CT $ct DNS"
done
```

Restart all containers to apply:

```bash
# pve1
for i in 101 102 103 104 105 106; do pct reboot $i; done

# pve2
for i in 201 202 203; do pct reboot $i; done

# pve3
for i in 301 302 303 304; do pct reboot $i; done
```

---

## Container Reference

| CT ID | Name | Node | IP | RAM | Purpose |
|---|---|---|---|---|---|
| 101 | adguard | pve1 | 192.168.11.20 | 512 MB | DNS ad blocker |
| 102 | radarr-sonarr | pve1 | 192.168.11.21 | 1 GB | Media managers |
| 103 | prowlarr-qbit | pve1 | 192.168.11.22 | 1 GB | Indexer + downloader |
| 104 | jellyseerr | pve1 | 192.168.11.23 | 512 MB | Media request portal |
| 105 | logstash | pve1 | 192.168.11.24 | 1 GB | ELK pipeline |
| 106 | kibana | pve1 | 192.168.11.25 | 1 GB | ELK visualization |
| 201 | paperless | pve2 | 192.168.11.30 | 1 GB | Document manager |
| 202 | stirling-pdf | pve2 | 192.168.11.31 | 512 MB | PDF tools |
| 203 | uptime-kuma | pve2 | 192.168.11.32 | 256 MB | Uptime monitoring |
| 301 | kavita | pve3 | 192.168.11.40 | 512 MB | Ebook reader |
| 302 | gitea | pve3 | 192.168.11.41 | 512 MB | Git server |
| 303 | semaphore | pve3 | 192.168.11.42 | 512 MB | Ansible UI |
| 304 | portainer | pve3 | 192.168.11.43 | 256 MB | Docker UI |

---

## Accessing Containers

SSH into any container:
```bash
# From the Proxmox node
pct exec 101 -- bash

# Or SSH directly (password: set during pct create)
ssh root@192.168.11.20
```

---

## Important Notes

- **Do NOT use `--node` in `pct create`** — it is not a valid option. Run the script on the target node and containers are created there automatically.
- **Unprivileged containers** are safer — container root maps to a non-root host user. Use privileged only if a service specifically requires it (e.g. Docker inside LXC).
- **DNS set to router initially** — update to AdGuard (192.168.11.20) after AdGuard is deployed and verified working.
