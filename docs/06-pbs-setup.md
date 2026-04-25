# Proxmox Backup Server Setup

## Overview

PBS runs as an HA VM on pve3 (stored on Ceph vmdata pool). It writes backups to TrueNAS via NFS over VLAN 40. All three Proxmox nodes back up their VMs and containers to PBS every night at 2 AM.

---

## Step 1 — Download PBS ISO

In Proxmox web UI:
```
pve1 → truenas-iso → ISO Images → Download from URL
URL: https://enterprise.proxmox.com/iso/proxmox-backup-server_4.1-1.iso
```

---

## Step 2 — Create PBS VM

Create on **pve3** with disk on **vmdata** (Ceph) for HA:

```
General:
  Node: pve3
  VM ID: 100
  Name: pbs
  Start at boot: YES

OS:
  Storage: truenas-iso
  ISO: proxmox-backup-server_4.1-1.iso
  Type: Linux / 6.x

System:
  Machine: q35
  BIOS: OVMF (UEFI)
  EFI Storage: vmdata
  SCSI Controller: VirtIO SCSI single

Disks:
  Storage: vmdata (Ceph — required for HA)
  Size: 32 GB
  Cache: Write back
  Discard: YES

CPU:
  Cores: 2
  Type: host

Memory:
  2048 MB
  Ballooning: NO

Network (net0):
  Bridge: vmbr0
  VLAN Tag: (empty — native VLAN 11)
  Model: VirtIO
```

After creating, add storage network interface:
```
Hardware → Add → Network Device
  Bridge: vmbr0
  VLAN Tag: 40
  Model: VirtIO
```

---

## Step 3 — Install PBS

Boot the VM and follow the installer:

```
Timezone: America/New_York
Hostname: pbs.home.lab
IP: 192.168.11.10/24
Gateway: 192.168.11.1
DNS: 192.168.11.20 (AdGuard)
```

---

## Step 4 — Post-Install Configuration

SSH into PBS:
```bash
ssh root@192.168.11.10
```

### Disable Enterprise Repo

```bash
echo "# disabled" > /etc/apt/sources.list.d/pbs-enterprise.list
echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" \
  > /etc/apt/sources.list.d/pbs-no-subscription.list
apt update && apt upgrade -y
```

### Configure VLAN 40 Interface

Check NIC names:
```bash
ip link show
# nic0 = management (VLAN 11, already configured)
# nic1 = storage (VLAN 40, needs configuration)
```

Edit network config:
```bash
nano /etc/network/interfaces
```

Add VLAN 40:
```
# Storage — VLAN 40 for TrueNAS NFS
auto nic1
iface nic1 inet static
        address 192.168.40.10/24
```

Apply:
```bash
ifreload -a
ping 192.168.40.200  # Verify TrueNAS is reachable
```

### Mount TrueNAS NFS

```bash
mkdir -p /mnt/pbs-backup

# Test mount
mount -t nfs 192.168.40.200:/mnt/backup/pbs /mnt/pbs-backup
df -h | grep pbs
# Expected: 192.168.40.200:/mnt/backup/pbs  462G  0  462G  0%  /mnt/pbs-backup

# Make permanent
echo "192.168.40.200:/mnt/backup/pbs /mnt/pbs-backup nfs rw,hard,intr,rsize=8192,wsize=8192,timeo=14 0 0" >> /etc/fstab
```

---

## Step 5 — Create Datastore

In PBS web UI at `https://192.168.11.10:8007`:

```
Administration → Datastore → Add Datastore
  Name: truenas-backup
  Path: /mnt/pbs-backup
  Comment: TrueNAS NFS backup storage
```

---

## Step 6 — Connect PBS to Proxmox Cluster

In Proxmox web UI at `https://192.168.11.2:8006`:

```
Datacenter → Storage → Add → Proxmox Backup Server
  ID: pbs-truenas
  Server: 192.168.11.10
  Username: root@pam
  Password: (PBS root password)
  Datastore: truenas-backup
  Fingerprint: (copy from error message or PBS → Administration → Certificates)
```

---

## Step 7 — Configure Backup Schedule

```
Datacenter → Backup → Add
  Storage: pbs-truenas
  Schedule: 02:00 (daily at 2 AM)
  Selection: All
  Mode: Snapshot
  Retention:
    Keep Last: 3
    Keep Daily: 7
    Keep Weekly: 4
    Keep Monthly: 2
```

---

## Step 8 — Enable HA for PBS VM

```
Datacenter → HA → Add
  Resource: vm:100
  Max Restart: 3
  Max Relocate: 3
  State: started
```

---

## Verification

Run a manual backup to test:
```
Datacenter → Backup → select job → Run Now
```

Check PBS web UI → Datastore → truenas-backup → Content — backups should appear.

---

## Important Notes

- **PBS VM on Ceph** — PBS itself is HA. If pve3 dies, PBS restarts on another node and keeps protecting backups.
- **VLAN 40 for NFS** — backup traffic goes over the dedicated storage VLAN, not management.
- **Fingerprint verification** — PBS uses self-signed SSL. Copy the exact fingerprint from the error message when first connecting.
