# TrueNAS Setup

## Hardware Notes

**HP EliteDesk 800 G1 SFF — PCIe Adapter Requirements:**

The Q87 chipset does NOT support PCIe bifurcation. You must use a PCIe adapter with a built-in switch chip.

| What works | What does NOT work |
|---|---|
| PLX PEX8747 chip | Any adapter requiring "PCIe bifurcation in BIOS" |
| ASM2824 chip | Asus Hyper M.2 X16 Gen 4 (requires bifurcation) |
| Cards stating "no bifurcation required" | Any card mentioning X299/X399/server motherboards |

**Search terms that find working adapters:**
- "PLX 8747 quad M.2 NVMe PCIe x16"
- "PEX8747 M.2 adapter no bifurcation"

---

## Network Configuration

The 2960CX switch port for TrueNAS:

```
interface GigabitEthernet0/9
 description TrueNAS
 switchport mode trunk
 switchport trunk native vlan 11
 switchport trunk allowed vlan 11,20,40
 switchport nonegotiate
 spanning-tree portfast trunk
 no shutdown
```

### TrueNAS Network Interfaces

Configure via **Network → Interfaces** in the TrueNAS web UI:

| Interface | VLAN | IP | Gateway | Purpose |
|---|---|---|---|---|
| Main NIC (native) | 11 | 192.168.11.200/24 | 192.168.11.1 | Management |
| VLAN subinterface | 40 | 192.168.40.200/24 | (none) | Storage/NFS |

**Important:** VLAN 40 has NO gateway — storage traffic never needs to leave the subnet.

---

## Storage Layout

### Drives

| Drive | Size | Pool | Purpose |
|---|---|---|---|
| SATA SSD | 250 GB | boot-pool | TrueNAS OS |
| SATA SSD | 500 GB | backup | Mirror member |
| SATA SSD | 1 TB | backup | Mirror member |
| Samsung PM991 NVMe | 512 GB | data | 3-way mirror |
| WD SN530 NVMe | 512 GB | data | 3-way mirror |
| SK Hynix NVMe | 512 GB | data | 3-way mirror |
| Kingston NV3 NVMe | 1 TB | data | L2ARC cache |

### Pool Design

```
boot-pool
└── TrueNAS OS (do not touch)

backup pool — Mirror (PBS backup target)
├── 500 GB SATA SSD
└── 1 TB SATA SSD
    (~476 GB usable)

data pool — 3-way Mirror (media + VM storage)
├── Samsung PM991 512 GB NVMe
├── WD SN530 512 GB NVMe
└── SK Hynix 512 GB NVMe
    (~476 GB usable)
    + Kingston NV3 1 TB → L2ARC cache
```

### Why This Layout

- **backup pool** — dedicated PBS repository. Mirror survives 1 drive failure.
- **data pool** — 3-way mirror survives 2 simultaneous drive failures. NVMe gives fast NFS performance to Proxmox.
- **L2ARC** — Kingston 1 TB caches frequently read data, boosting NFS reads above wire speed (measured: 116 MB/s on gigabit).

---

## Creating Pools

**Important:** Create pools through the TrueNAS web UI, not the CLI. Pools created via CLI do not register with TrueNAS middleware and cannot be managed through the UI.

**Storage → Create Pool:**

Pool 1 (backup):
```
Name: backup
Layout: Mirror
Disks: 500 GB SATA + 1 TB SATA
```

Pool 2 (data):
```
Name: data
Layout: Mirror
Disks: nvme0n1 + nvme1n1 + nvme3n1 (3-way mirror)
```

Add L2ARC cache:
```
Storage → Pools → data → Manage Devices → Add Vdev → Cache
Select: Kingston NV3 (nvme2n1)
```

---

## Datasets

Create these datasets via **Storage → Datasets**:

| Dataset | Pool | Purpose |
|---|---|---|
| backup/pbs | backup | PBS backup repository |
| data/media | data | Jellyfin movies and TV |
| data/photos | data | Immich photo library |
| data/documents | data | Paperless-ngx documents |
| data/proxmox | data | ISO images and templates |

---

## NFS Shares

**Shares → NFS → Add:**

```
Path: /mnt/backup/pbs
Description: Proxmox Backup Server
Networks: 192.168.40.0/24
Maproot User: root
Maproot Group: root
```

```
Path: /mnt/data/proxmox
Description: Proxmox ISO and templates
Networks: 192.168.40.0/24
Maproot User: root
Maproot Group: root
```

Enable NFS service when prompted.

---

## SMB Shares

**Shares → SMB → Add** for each:

```
Path: /mnt/data/media    Name: media
Path: /mnt/data/photos   Name: photos
Path: /mnt/data/documents Name: documents
```

Enable SMB service when prompted.

---

## Connecting NFS to Proxmox

Add TrueNAS NFS storage in Proxmox:

```
Datacenter → Storage → Add → NFS
  ID: truenas-iso
  Server: 192.168.40.200
  Export: /mnt/data/proxmox
  Content: ISO Images, Container Templates
  Nodes: all
```

```
Datacenter → Storage → Add → NFS  
  ID: pbs-truenas (configured via PBS)
  Server: 192.168.40.200
  Export: /mnt/backup/pbs
```

---

## Verification

Test NFS connectivity from any Proxmox node:

```bash
# Check NFS exports
showmount -e 192.168.40.200

# Test mount speed
dd if=/dev/zero of=/mnt/pve/truenas-iso/testfile bs=1M count=1000 oflag=direct
# Expected: ~92 MB/s write

dd if=/mnt/pve/truenas-iso/testfile of=/dev/null bs=1M
# Expected: ~116 MB/s read (L2ARC cache)

# Cleanup
rm /mnt/pve/truenas-iso/testfile
```
