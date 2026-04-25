# Ceph Cluster Setup

## Overview

Three NVMe OSDs (one per node) provide ~500 GB of HA shared storage with 3× replication. VMs stored on Ceph automatically failover to surviving nodes if a node goes down.

**Storage layout per node:**
- `500 GB Kingston SSD` → Proxmox OS + LXC containers (local-lvm)
- `512 GB NVMe` → Ceph OSD (vmdata pool)

---

## Step 1 — Install Ceph on All Three Nodes

```bash
# Run on pve1, pve2, pve3
apt update && apt install -y ceph

# Verify installation
ceph --version
# Expected: ceph version 19.x.x (squid)
```

---

## Step 2 — Initialize Ceph on pve1 Only

```bash
# Run ONLY on pve1
# --network points Ceph at VLAN 30 for all replication traffic
pveceph init --network 192.168.30.0/24
```

Verify the config:
```bash
cat /etc/ceph/ceph.conf
```

Expected output:
```
[global]
auth_client_required = cephx
auth_cluster_required = cephx
auth_service_required = cephx
cluster_network = 192.168.30.0/24
public_network = 192.168.30.0/24
osd_pool_default_min_size = 2
osd_pool_default_size = 3
```

Key settings:
- `osd_pool_default_size = 3` — data replicated to all 3 nodes
- `osd_pool_default_min_size = 2` — cluster stays operational if 1 node fails

---

## Step 3 — Create Monitors (All Nodes)

```bash
# Run on pve1
pveceph mon create

# Run on pve2
pveceph mon create

# Run on pve3
pveceph mon create
```

Verify all three monitors:
```bash
ceph mon stat
```

Expected:
```
3 mons at {pve1,pve2,pve3}, quorum 0,1,2 pve1,pve2,pve3
```

---

## Step 4 — Create Managers (All Nodes)

```bash
# Run on pve1
pveceph mgr create

# Run on pve2
pveceph mgr create

# Run on pve3
pveceph mgr create
```

Verify:
```bash
ceph mgr stat
# Expected: active_name: pve1, num_standby: 2
```

---

## Step 5 — Prepare NVMe Disks

Check disk names on each node:
```bash
lsblk
```

The NVMe disk will show as `nvme0n1`. If it has existing partitions (e.g. from a previous Windows install), wipe them:

```bash
# Run on each node — replace nvme0n1 with actual disk name
wipefs -a /dev/nvme0n1
sgdisk --zap-all /dev/nvme0n1

# Verify clean
lsblk /dev/nvme0n1
# Should show no partitions
```

---

## Step 6 — Create OSDs (All Nodes)

```bash
# Run on pve1
pveceph osd create /dev/nvme0n1

# Run on pve2
pveceph osd create /dev/nvme0n1

# Run on pve3
pveceph osd create /dev/nvme0n1
```

Verify all three OSDs:
```bash
ceph osd stat
# Expected: 3 osds: 3 up, 3 in
```

---

## Step 7 — Create Pool

```bash
# Run on pve1 only
# Fix PG count first (32 is correct for 3 OSDs, 1 pool)
pveceph pool create vmdata --add_storages

# Fix placement group warning
ceph osd pool set vmdata pg_num 32
ceph osd pool set vmdata pgp_num 32
```

`--add_storages` automatically registers the pool as Proxmox storage on all nodes.

---

## Step 8 — Final Verification

```bash
ceph status
```

Expected healthy output:
```
cluster:
  health: HEALTH_OK

services:
  mon: 3 daemons, quorum pve1,pve2,pve3
  mgr: pve1(active), standbys: pve2, pve3
  osd: 3 osds: 3 up, 3 in

data:
  pools: 1 pools, 32 pgs
  usage: ~82 MiB used, 1.4 TiB avail
  pgs: 32 active+clean
```

---

## Important Notes

- **NVMe for Ceph OSDs** — dramatically better than HDD for failover speed. With NVMe, VM failover completes in seconds. With HDD it takes 30-60 seconds.
- **VLAN 30 is Ceph-only** — never route this VLAN through the 1921 router. It must stay local to the Proxmox nodes.
- **3× replication** — every write goes to all 3 OSDs. The cluster can survive 1 node failure with no data loss.
- **Dedicated Ceph network** — using VLAN 30 (not management VLAN 11) keeps replication traffic from competing with VM and management traffic.
