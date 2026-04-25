#!/bin/bash
# VM Template Creation and Cloning
# Run ALL commands on pve1 (template must live on shared Ceph storage)
#
# Prerequisites:
# 1. Download Ubuntu cloud image:
#    cd /mnt/pve/truenas-iso/template/iso/
#    wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
#
# 2. Create cloud-init snippet on ALL nodes:
#    mkdir -p /var/lib/vz/snippets
#    pvesm set local --content vztmpl,iso,backup,snippets
#    cp userdata.yaml /var/lib/vz/snippets/userdata.yaml
#    # Then copy to pve2 and pve3:
#    scp /var/lib/vz/snippets/userdata.yaml root@192.168.11.3:/var/lib/vz/snippets/
#    scp /var/lib/vz/snippets/userdata.yaml root@192.168.11.4:/var/lib/vz/snippets/

set -e

CLOUD_IMAGE="/mnt/pve/truenas-iso/template/iso/noble-server-cloudimg-amd64.img"
STORAGE="vmdata"  # Must be Ceph (vmdata) — not local-lvm — for cross-node cloning
TEMPLATE_ID="9000"
DNS="192.168.11.20"
DOMAIN="home.lab"
PASSWORD="PUTPASSWD_HERE"

# =============================================================
# STEP 1 — CREATE BASE TEMPLATE (Run on pve1 only)
# =============================================================
create_template() {
  echo "Creating Ubuntu 24.04 cloud-init template (VM $TEMPLATE_ID)..."

  # Check cloud image exists
  if [ ! -f "$CLOUD_IMAGE" ]; then
    echo "ERROR: Cloud image not found at $CLOUD_IMAGE"
    echo "Download it first:"
    echo "  wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O $CLOUD_IMAGE"
    exit 1
  fi

  # Create VM
  qm create $TEMPLATE_ID \
    --name ubuntu24-template \
    --cores 2 \
    --memory 2048 \
    --balloon 0 \
    --machine q35 \
    --bios ovmf \
    --efidisk0 $STORAGE:1,efitype=4m \
    --scsihw virtio-scsi-single \
    --net0 model=virtio,bridge=vmbr0 \
    --ostype l26 \
    --serial0 socket \
    --vga std \
    --agent enabled=1

  # Import cloud image disk
  echo "Importing cloud image disk..."
  qm importdisk $TEMPLATE_ID $CLOUD_IMAGE $STORAGE

  # Find the imported disk name
  DISK_NAME=$(rbd ls $STORAGE | grep "vm-${TEMPLATE_ID}-disk" | grep -v cloudinit | head -1)
  echo "Imported disk: $DISK_NAME"

  # Attach disk
  qm set $TEMPLATE_ID --scsi0 $STORAGE:$DISK_NAME,cache=writeback,discard=on
  qm set $TEMPLATE_ID --boot order=scsi0

  # Add cloud-init drive
  qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit

  # Configure cloud-init
  qm set $TEMPLATE_ID --cicustom "user=local:snippets/userdata.yaml"
  qm set $TEMPLATE_ID --ciuser admin
  qm set $TEMPLATE_ID --cipassword $PASSWORD
  qm set $TEMPLATE_ID --nameserver $DNS
  qm set $TEMPLATE_ID --searchdomain $DOMAIN

  # Find and fix EFI disk reference
  EFI_DISK=$(rbd ls $STORAGE | grep "vm-${TEMPLATE_ID}" | grep -v "disk-" | grep -v cloudinit | head -1)
  if [ -n "$EFI_DISK" ]; then
    qm set $TEMPLATE_ID --efidisk0 $STORAGE:$EFI_DISK,efitype=4m,size=1M
  fi

  # Convert to template
  qm template $TEMPLATE_ID

  echo "✓ Template VM $TEMPLATE_ID created successfully"
}

# =============================================================
# STEP 2 — CLONE ALL VMs (Run on pve1 only)
# =============================================================
clone_all_vms() {
  echo "Cloning all VMs from template $TEMPLATE_ID..."

  # ---- pve1 VMs ----

  # VM 110 — Jellyfin
  qm clone $TEMPLATE_ID 110 --name jellyfin --full --target pve1 && \
  qm set 110 --ipconfig0 ip=192.168.11.56/24,gw=192.168.11.1 --cores 3 --memory 4096 --onboot 1 && \
  qm resize 110 scsi0 32G && \
  echo "✓ VM 110 Jellyfin cloned"

  # VM 111 — Immich
  qm clone $TEMPLATE_ID 111 --name immich --full --target pve1 && \
  qm set 111 --ipconfig0 ip=192.168.11.57/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1 && \
  qm resize 111 scsi0 32G && \
  echo "✓ VM 111 Immich cloned"

  # VM 112 — Frigate NVR
  qm clone $TEMPLATE_ID 112 --name frigate --full --target pve1 && \
  qm set 112 --ipconfig0 ip=192.168.11.58/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1 && \
  qm resize 112 scsi0 32G && \
  echo "✓ VM 112 Frigate cloned"

  # VM 113 — Zabbix
  qm clone $TEMPLATE_ID 113 --name zabbix --full --target pve1 && \
  qm set 113 --ipconfig0 ip=192.168.11.59/24,gw=192.168.11.1 --cores 2 --memory 4096 --onboot 1 && \
  qm resize 113 scsi0 32G && \
  echo "✓ VM 113 Zabbix cloned"

  # VM 114 — Wazuh SIEM
  qm clone $TEMPLATE_ID 114 --name wazuh --full --target pve1 && \
  qm set 114 --ipconfig0 ip=192.168.11.60/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1 && \
  qm resize 114 scsi0 64G && \
  echo "✓ VM 114 Wazuh cloned"

  # ---- pve2 VMs ----

  # VM 200 — Nginx Proxy Manager (HA)
  qm clone $TEMPLATE_ID 200 --name nginx-proxy-manager --full --target pve2 && \
  qm set 200 --ipconfig0 ip=192.168.11.50/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1 && \
  qm resize 200 scsi0 16G && \
  echo "✓ VM 200 Nginx Proxy Manager cloned"

  # VM 210 — Vaultwarden (HA)
  qm clone $TEMPLATE_ID 210 --name vaultwarden --full --target pve2 && \
  qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1 && \
  qm resize 210 scsi0 16G && \
  echo "✓ VM 210 Vaultwarden cloned"

  # VM 211 — Nextcloud
  qm clone $TEMPLATE_ID 211 --name nextcloud --full --target pve2 && \
  qm set 211 --ipconfig0 ip=192.168.11.52/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1 && \
  qm resize 211 scsi0 32G && \
  echo "✓ VM 211 Nextcloud cloned"

  # VM 212 — Grafana + Prometheus
  qm clone $TEMPLATE_ID 212 --name grafana-prometheus --full --target pve2 && \
  qm set 212 --ipconfig0 ip=192.168.11.53/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1 && \
  qm resize 212 scsi0 32G && \
  echo "✓ VM 212 Grafana+Prometheus cloned"

  # VM 213 — Elasticsearch
  qm clone $TEMPLATE_ID 213 --name elasticsearch --full --target pve2 && \
  qm set 213 --ipconfig0 ip=192.168.11.54/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1 && \
  qm resize 213 scsi0 64G && \
  echo "✓ VM 213 Elasticsearch cloned"

  # ---- pve3 VMs ----

  # VM 300 — UniFi Controller (HA)
  qm clone $TEMPLATE_ID 300 --name unifi-controller --full --target pve3 && \
  qm set 300 --ipconfig0 ip=192.168.11.55/24,gw=192.168.11.1 --cores 1 --memory 1536 --onboot 1 && \
  qm resize 300 scsi0 16G && \
  echo "✓ VM 300 UniFi Controller cloned"

  echo ""
  echo "✓ All VMs cloned successfully"
  echo ""
  echo "Start pve1 VMs:  for vm in 110 111 112 113 114; do qm start \$vm; done"
  echo "Start pve2 VMs:  ssh root@192.168.11.3 'for vm in 200 210 211 212 213; do qm start \$vm; done'"
  echo "Start pve3 VMs:  ssh root@192.168.11.4 'qm start 300'"
}

# =============================================================
# POST-INSTALL — Fix any VM that didn't get cloud-init right
# Run INSIDE the VM as root via console
# =============================================================
fix_vm_login() {
  echo "Run these commands INSIDE the VM via Proxmox console if login fails:"
  cat << 'INNEREOF'
# Create admin user and set passwords
userdel -r admin 2>/dev/null || true
useradd -m -s /bin/bash -g users -G sudo admin
echo "admin:PUTPASSWD_HERE" | chpasswd
echo "root:PUTPASSWD_HERE" | chpasswd

# Enable SSH password authentication
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-pwauth.conf
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-pwauth.conf
systemctl restart ssh

# Enable passwordless sudo
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/admin

# Verify
ip addr show
ping -c 2 192.168.11.1
INNEREOF
}

# =============================================================
# USAGE
# =============================================================
case "$1" in
  template)
    create_template
    ;;
  clone)
    clone_all_vms
    ;;
  fix)
    fix_vm_login
    ;;
  all)
    create_template
    clone_all_vms
    ;;
  *)
    echo "Usage: $0 {template|clone|fix|all}"
    echo ""
    echo "  template  — Create the base Ubuntu 24.04 cloud-init template (VM 9000)"
    echo "  clone     — Clone template to all VMs across all nodes"
    echo "  fix       — Show commands to fix VM login issues via console"
    echo "  all       — Create template then clone all VMs"
    ;;
esac
