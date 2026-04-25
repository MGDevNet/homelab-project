#!/bin/bash
# LXC Container Creation — Master Script
# Run each section on the appropriate node
# All templates must be downloaded to truenas-iso first:
#   pveam download truenas-iso debian-13-standard_13.1-2_amd64.tar.zst
#   pveam download truenas-iso ubuntu-24.04-standard_24.04-2_amd64.tar.zst

TEMPLATE="truenas-iso:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
STORAGE="local-lvm"
GW="192.168.11.1"
DNS="192.168.11.20"
DOMAIN="home.lab"

echo "This script creates all LXC containers."
echo "Run the appropriate section on each node."
echo ""

# =============================================================
# PVE1 CONTAINERS — Run on pve1
# =============================================================
create_pve1_containers() {
  echo "Creating containers on pve1..."

  # CT 101 — AdGuard Home (DNS ad blocker)
  pct create 101 $TEMPLATE \
    --hostname adguard \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.20/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "AdGuard Home DNS ad blocker — HA critical" && echo "✓ CT 101 AdGuard created"

  # CT 102 — Radarr + Sonarr (media managers)
  pct create 102 $TEMPLATE \
    --hostname radarr-sonarr \
    --cores 1 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.21/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Radarr and Sonarr media managers" && echo "✓ CT 102 Radarr+Sonarr created"

  # CT 103 — Prowlarr + qBittorrent (indexer + downloader)
  pct create 103 $TEMPLATE \
    --hostname prowlarr-qbit \
    --cores 1 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.22/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Prowlarr indexer and qBittorrent downloader" && echo "✓ CT 103 Prowlarr+qBit created"

  # CT 104 — Jellyseerr (media request portal)
  pct create 104 $TEMPLATE \
    --hostname jellyseerr \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.23/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Jellyfin request portal" && echo "✓ CT 104 Jellyseerr created"

  # CT 105 — Logstash (ELK pipeline)
  pct create 105 $TEMPLATE \
    --hostname logstash \
    --cores 1 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.24/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Logstash ELK pipeline" && echo "✓ CT 105 Logstash created"

  # CT 106 — Kibana (ELK visualization)
  pct create 106 $TEMPLATE \
    --hostname kibana \
    --cores 1 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.25/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Kibana ELK visualization" && echo "✓ CT 106 Kibana created"

  echo ""
  echo "✓ All pve1 containers created"
  echo "Start with: for i in 101 102 103 104 105 106; do pct start \$i; echo \"Started CT \$i\"; done"
}

# =============================================================
# PVE2 CONTAINERS — Run on pve2
# =============================================================
create_pve2_containers() {
  echo "Creating containers on pve2..."

  # CT 201 — Paperless-ngx (document manager)
  pct create 201 $TEMPLATE \
    --hostname paperless \
    --cores 1 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.30/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Paperless-ngx document manager" && echo "✓ CT 201 Paperless created"

  # CT 202 — Stirling PDF (PDF tools)
  pct create 202 $TEMPLATE \
    --hostname stirling-pdf \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.31/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Stirling PDF tools" && echo "✓ CT 202 Stirling PDF created"

  # CT 203 — Uptime Kuma (uptime monitoring)
  pct create 203 $TEMPLATE \
    --hostname uptime-kuma \
    --cores 1 \
    --memory 256 \
    --swap 256 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.32/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Uptime Kuma service monitoring" && echo "✓ CT 203 Uptime Kuma created"

  echo ""
  echo "✓ All pve2 containers created"
  echo "Start with: for i in 201 202 203; do pct start \$i; echo \"Started CT \$i\"; done"
}

# =============================================================
# PVE3 CONTAINERS — Run on pve3
# =============================================================
create_pve3_containers() {
  echo "Creating containers on pve3..."

  # CT 301 — Kavita (ebook and manga reader)
  pct create 301 $TEMPLATE \
    --hostname kavita \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.40/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Kavita ebook and manga reader" && echo "✓ CT 301 Kavita created"

  # CT 302 — Gitea (self-hosted Git)
  pct create 302 $TEMPLATE \
    --hostname gitea \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:10 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.41/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Gitea self-hosted Git server" && echo "✓ CT 302 Gitea created"

  # CT 303 — Semaphore (Ansible UI)
  pct create 303 $TEMPLATE \
    --hostname semaphore \
    --cores 1 \
    --memory 512 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.42/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Semaphore Ansible automation UI" && echo "✓ CT 303 Semaphore created"

  # CT 304 — Portainer (Docker UI)
  pct create 304 $TEMPLATE \
    --hostname portainer \
    --cores 1 \
    --memory 256 \
    --swap 256 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.11.43/24,gw=$GW \
    --nameserver $DNS \
    --searchdomain $DOMAIN \
    --unprivileged 1 \
    --onboot 1 \
    --description "Portainer Docker container UI" && echo "✓ CT 304 Portainer created"

  echo ""
  echo "✓ All pve3 containers created"
  echo "Start with: for i in 301 302 303 304; do pct start \$i; echo \"Started CT \$i\"; done"
}

# =============================================================
# USAGE
# =============================================================
echo "Usage:"
echo "  Source this file and call the function for your node:"
echo "  source create_containers.sh && create_pve1_containers"
echo "  source create_containers.sh && create_pve2_containers"
echo "  source create_containers.sh && create_pve3_containers"
echo ""
echo "  Or run a specific node directly:"
echo "  bash create_containers.sh pve1"
echo "  bash create_containers.sh pve2"
echo "  bash create_containers.sh pve3"

# Allow direct execution with node argument
if [[ "$1" == "pve1" ]]; then create_pve1_containers; fi
if [[ "$1" == "pve2" ]]; then create_pve2_containers; fi
if [[ "$1" == "pve3" ]]; then create_pve3_containers; fi
