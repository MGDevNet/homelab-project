# VM Template and Deployment Guide

## Overview

Instead of installing Ubuntu manually on every VM (which takes 20+ minutes each and has installer bugs), we use a **Ubuntu 24.04 cloud image template** that deploys in seconds via cloning.

**Key requirement:** The template must use **Ceph (vmdata) storage**, not local-lvm. This allows cloning to any node in the cluster.

---

## Prerequisites

### 1 — Download Ubuntu Cloud Image

```bash
# Run on pve1
cd /mnt/pve/truenas-iso/template/iso/
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 2 — Create Cloud-Init Snippet on ALL Nodes

```bash
# Run on pve1, pve2, AND pve3
mkdir -p /var/lib/vz/snippets
pvesm set local --content vztmpl,iso,backup,snippets

cat > /var/lib/vz/snippets/userdata.yaml << 'EOF'
#cloud-config
users:
  - name: admin
    groups: [sudo, users]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
chpasswd:
  users:
    - name: admin
      password: PUTPASSWD_HERE
      type: text
    - name: root
      password: PUTPASSWD_HERE
      type: text
  expire: false
ssh_pwauth: true
packages:
  - qemu-guest-agent
  - curl
  - wget
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
  - chmod 440 /etc/sudoers.d/admin
  - echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-pwauth.conf
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-pwauth.conf
  - systemctl restart ssh
EOF
```

Copy snippet to other nodes:
```bash
# Run on pve1
scp /var/lib/vz/snippets/userdata.yaml root@192.168.11.3:/var/lib/vz/snippets/
scp /var/lib/vz/snippets/userdata.yaml root@192.168.11.4:/var/lib/vz/snippets/
```

---

## Create Template (Run on pve1)

```bash
# Create base VM
qm create 9000 \
  --name ubuntu24-template \
  --cores 2 --memory 2048 --balloon 0 \
  --machine q35 --bios ovmf \
  --efidisk0 vmdata:1,efitype=4m \
  --scsihw virtio-scsi-single \
  --net0 model=virtio,bridge=vmbr0 \
  --ostype l26 --serial0 socket --vga std \
  --agent enabled=1

# Import cloud image
qm importdisk 9000 \
  /mnt/pve/truenas-iso/template/iso/noble-server-cloudimg-amd64.img \
  vmdata

# Find imported disk name
DISK=$(rbd ls vmdata | grep "vm-9000-disk" | grep -v cloudinit | head -1)
echo "Disk: $DISK"

# Attach disk
qm set 9000 --scsi0 vmdata:$DISK,cache=writeback,discard=on
qm set 9000 --boot order=scsi0

# Add cloud-init drive
qm set 9000 --ide2 vmdata:cloudinit

# Find EFI disk and fix reference
EFI=$(rbd ls vmdata | grep "base-9000" | head -1)
if [ -n "$EFI" ]; then
  qm set 9000 --efidisk0 vmdata:$EFI,efitype=4m,size=1M
fi

# Apply cloud-init config
qm set 9000 --cicustom "user=local:snippets/userdata.yaml"
qm set 9000 --ciuser admin
qm set 9000 --cipassword PUTPASSWD_HERE
qm set 9000 --nameserver 192.168.11.20
qm set 9000 --searchdomain home.lab

# Convert to template
qm template 9000
```

---

## Clone VMs (Run on pve1)

All clone commands run on pve1. The `--target` flag places each VM on the correct node.

```bash
# VM 200 — Nginx Proxy Manager (pve2)
qm clone 9000 200 --name nginx-proxy-manager --full --target pve2
qm set 200 --ipconfig0 ip=192.168.11.50/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1
qm resize 200 scsi0 16G

# VM 210 — Vaultwarden (pve2)
qm clone 9000 210 --name vaultwarden --full --target pve2
qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1
qm resize 210 scsi0 16G

# VM 211 — Nextcloud (pve2)
qm clone 9000 211 --name nextcloud --full --target pve2
qm set 211 --ipconfig0 ip=192.168.11.52/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 211 scsi0 32G

# VM 212 — Grafana + Prometheus (pve2)
qm clone 9000 212 --name grafana-prometheus --full --target pve2
qm set 212 --ipconfig0 ip=192.168.11.53/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 212 scsi0 32G

# VM 213 — Elasticsearch (pve2)
qm clone 9000 213 --name elasticsearch --full --target pve2
qm set 213 --ipconfig0 ip=192.168.11.54/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 213 scsi0 64G

# VM 300 — UniFi Controller (pve3)
qm clone 9000 300 --name unifi-controller --full --target pve3
qm set 300 --ipconfig0 ip=192.168.11.55/24,gw=192.168.11.1 --cores 1 --memory 1536 --onboot 1
qm resize 300 scsi0 16G

# VM 110 — Jellyfin (pve1)
qm clone 9000 110 --name jellyfin --full --target pve1
qm set 110 --ipconfig0 ip=192.168.11.56/24,gw=192.168.11.1 --cores 3 --memory 4096 --onboot 1
qm resize 110 scsi0 32G

# VM 111 — Immich (pve1)
qm clone 9000 111 --name immich --full --target pve1
qm set 111 --ipconfig0 ip=192.168.11.57/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 111 scsi0 32G

# VM 112 — Frigate NVR (pve1)
qm clone 9000 112 --name frigate --full --target pve1
qm set 112 --ipconfig0 ip=192.168.11.58/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 112 scsi0 32G

# VM 113 — Zabbix (pve1)
qm clone 9000 113 --name zabbix --full --target pve1
qm set 113 --ipconfig0 ip=192.168.11.59/24,gw=192.168.11.1 --cores 2 --memory 4096 --onboot 1
qm resize 113 scsi0 32G

# VM 114 — Wazuh SIEM (pve1)
qm clone 9000 114 --name wazuh --full --target pve1
qm set 114 --ipconfig0 ip=192.168.11.60/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 114 scsi0 64G
```

---

## Start VMs

```bash
# Start pve1 VMs (run on pve1)
for vm in 110 111 112 113 114; do qm start $vm; echo "Started VM $vm"; done

# Start pve2 VMs (run on pve2)
for vm in 200 210 211 212 213; do qm start $vm; echo "Started VM $vm"; done

# Start pve3 VMs (run on pve3)
qm start 300
```

---

## Verify VM Login

Wait 60 seconds after starting, then SSH:

```bash
ssh admin@192.168.11.50  # NPM
# password: PUTPASSWD_HERE
```

---

## If Cloud-Init Login Fails

Access via Proxmox console (pveX → VM → Console) and run:

```bash
# Create user and set passwords
userdel -r admin 2>/dev/null || true
useradd -m -s /bin/bash -g users -G sudo admin
echo "admin:PUTPASSWD_HERE" | chpasswd
echo "root:PUTPASSWD_HERE" | chpasswd

# Enable SSH password auth
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-pwauth.conf
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-pwauth.conf
systemctl restart ssh

# Enable passwordless sudo
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/admin
```

---

## Common Mistakes to Avoid

| ❌ Wrong | ✓ Right |
|---|---|
| Using `--node` in `qm create` | Run script on the node directly — `--node` is not a valid option |
| Using local-lvm for template | Use vmdata (Ceph) — cross-node cloning requires shared storage |
| Ubuntu Server ISO installer | Use cloud image — the Ubuntu 24.04 installer has mirror bugs |
| Leaving VLAN tag on VLAN 11 NICs | Leave VLAN tag empty — VLAN 11 is native/untagged on trunk |
| Using Ubuntu 24.04.2 ISO | Use cloud image instead — the installer crashes on mirror test |
| Running `qm set` on pve1 for pve2/pve3 VMs right after clone | Run `qm set` on the target node — config takes time to sync |
| Touching EFI disk after cloning | Never delete/recreate efidisk0 after cloning — it breaks UEFI boot |
| Destroying VMs without `--destroy-unreferenced-disks 1` | Always use `qm destroy $vm --purge --destroy-unreferenced-disks 1` |

---

## Critical — qm set After Cross-Node Clone

When cloning to pve2 or pve3 from pve1, run `qm set` on the **target node**, not pve1:

```bash
# WRONG — running qm set on pve1 for a pve2 VM right after clone
# pve1 doesn't have the config yet — it fails silently
qm clone 9000 210 --name vaultwarden --full --target pve2
qm set 210 --ipconfig0 ip=192.168.11.51/24  # fails on pve1

# CORRECT — SSH to pve2 and run qm set there
qm clone 9000 210 --name vaultwarden --full --target pve2
ssh root@192.168.11.3 "qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1"
ssh root@192.168.11.3 "qm resize 210 scsi0 16G"
```

---

## Complete Working Clone Script (Run on pve1)

```bash
bash << 'EOF'
# pve1 VMs — set can run locally
qm clone 9000 110 --name jellyfin --full --target pve1
qm set 110 --ipconfig0 ip=192.168.11.56/24,gw=192.168.11.1 --cores 3 --memory 4096 --onboot 1
qm resize 110 scsi0 32G
echo "✓ 110 done"

qm clone 9000 111 --name immich --full --target pve1
qm set 111 --ipconfig0 ip=192.168.11.57/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 111 scsi0 32G
echo "✓ 111 done"

qm clone 9000 112 --name frigate --full --target pve1
qm set 112 --ipconfig0 ip=192.168.11.58/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 112 scsi0 32G
echo "✓ 112 done"

qm clone 9000 113 --name zabbix --full --target pve1
qm set 113 --ipconfig0 ip=192.168.11.59/24,gw=192.168.11.1 --cores 2 --memory 4096 --onboot 1
qm resize 113 scsi0 32G
echo "✓ 113 done"

qm clone 9000 114 --name wazuh --full --target pve1
qm set 114 --ipconfig0 ip=192.168.11.60/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 114 scsi0 64G
echo "✓ 114 done"

# pve2 VMs — clone from pve1, configure on pve2
qm clone 9000 210 --name vaultwarden --full --target pve2
qm clone 9000 211 --name nextcloud --full --target pve2
qm clone 9000 212 --name grafana-prometheus --full --target pve2
qm clone 9000 213 --name elasticsearch --full --target pve2

# pve3 VMs — clone from pve1, configure on pve3
qm clone 9000 300 --name unifi-controller --full --target pve3

echo "Clones done — now configure on target nodes"
EOF
```

Then SSH to pve2 and configure:
```bash
ssh root@192.168.11.3 << 'EOF'
qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1
qm resize 210 scsi0 16G
qm set 211 --ipconfig0 ip=192.168.11.52/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 211 scsi0 32G
qm set 212 --ipconfig0 ip=192.168.11.53/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 212 scsi0 32G
qm set 213 --ipconfig0 ip=192.168.11.54/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 213 scsi0 64G
echo "pve2 configured"
EOF
```

Then SSH to pve3:
```bash
ssh root@192.168.11.4 << 'EOF'
qm set 300 --ipconfig0 ip=192.168.11.55/24,gw=192.168.11.1 --cores 1 --memory 1536 --onboot 1
qm resize 300 scsi0 16G
echo "pve3 configured"
EOF
```
