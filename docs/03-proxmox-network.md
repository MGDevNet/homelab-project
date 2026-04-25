# Proxmox Network Configuration

## Overview

Each node has one physical NIC (`nic0`) carrying all VLANs as a trunk. The key insight is using a **VLAN-aware bridge** (`bridge-vlan-aware yes`) on `vmbr0` — this allows VMs to use any VLAN tag through a single bridge.

**Critical lessons learned:**
- Do NOT use `nic0.40` style subinterfaces alongside a VLAN-aware bridge — they conflict
- Use `vmbr0.X` style subinterfaces instead when the bridge is VLAN-aware
- The native VLAN (11) on the switch trunk means `vmbr0` works untagged for management

---

## pve1 — /etc/network/interfaces

```bash
auto lo
iface lo inet loopback

# Physical NIC — no IP, carries all VLANs as trunk
iface nic0 inet manual

# VLAN 11 — Management bridge (Proxmox web UI + SSH)
# Native VLAN on switch trunk — untagged traffic, no VLAN tag needed
auto vmbr0
iface vmbr0 inet static
        address 192.168.11.2/24
        gateway 192.168.11.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

# Secondary NIC — unused, kept for reference
iface nic1 inet manual

# VLAN 20 — VM LAN traffic bridge
# Attach VMs to vmbr20 for LAN network access
auto vmbr0.20
iface vmbr0.20 inet manual
        vlan-raw-device vmbr0

auto vmbr20
iface vmbr20 inet static
        address 192.168.20.101/24
        bridge-ports vmbr0.20
        bridge-stp off
        bridge-fd 0

# VLAN 30 — Ceph replication traffic only
# No bridge needed — direct IP, never leaves the cluster
auto vmbr0.30
iface vmbr0.30 inet static
        address 192.168.30.101/24
        vlan-raw-device vmbr0

# VLAN 40 — Storage network for TrueNAS NFS access
# No bridge needed — direct IP for NFS/SMB mounts
auto vmbr0.40
iface vmbr0.40 inet static
        address 192.168.40.101/24
        vlan-raw-device vmbr0

source /etc/network/interfaces.d/*
```

---

## pve2 — /etc/network/interfaces

```bash
auto lo
iface lo inet loopback

# Physical NIC — no IP, carries all VLANs as trunk
iface nic0 inet manual

# VLAN 11 — Management bridge (Proxmox web UI + SSH)
auto vmbr0
iface vmbr0 inet static
        address 192.168.11.3/24
        gateway 192.168.11.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

# Secondary NIC — unused, kept for reference
iface nic1 inet manual

# VLAN 20 — VM LAN traffic bridge
auto vmbr0.20
iface vmbr0.20 inet manual
        vlan-raw-device vmbr0

auto vmbr20
iface vmbr20 inet static
        address 192.168.20.102/24
        bridge-ports vmbr0.20
        bridge-stp off
        bridge-fd 0

# VLAN 30 — Ceph replication traffic only
auto vmbr0.30
iface vmbr0.30 inet static
        address 192.168.30.102/24
        vlan-raw-device vmbr0

# VLAN 40 — Storage network for TrueNAS NFS access
auto vmbr0.40
iface vmbr0.40 inet static
        address 192.168.40.102/24
        vlan-raw-device vmbr0

source /etc/network/interfaces.d/*
```

---

## pve3 — /etc/network/interfaces

```bash
auto lo
iface lo inet loopback

# Physical NIC — no IP, carries all VLANs as trunk
iface nic0 inet manual

# VLAN 11 — Management bridge (Proxmox web UI + SSH)
auto vmbr0
iface vmbr0 inet static
        address 192.168.11.4/24
        gateway 192.168.11.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

# NOTE: pve3 has no secondary NIC (HP EliteDesk 800 G3 DM)

# VLAN 20 — VM LAN traffic bridge
auto vmbr0.20
iface vmbr0.20 inet manual
        vlan-raw-device vmbr0

auto vmbr20
iface vmbr20 inet static
        address 192.168.20.103/24
        bridge-ports vmbr0.20
        bridge-stp off
        bridge-fd 0

# VLAN 30 — Ceph replication traffic only
auto vmbr0.30
iface vmbr0.30 inet static
        address 192.168.30.103/24
        vlan-raw-device vmbr0

# VLAN 40 — Storage network for TrueNAS NFS access
auto vmbr0.40
iface vmbr0.40 inet static
        address 192.168.40.103/24
        vlan-raw-device vmbr0

source /etc/network/interfaces.d/*
```

---

## Apply Configuration

Apply on each node **one at a time**. Verify connectivity before moving to the next:

```bash
# Apply network config
ifreload -a

# Verify VLAN 30 (Ceph) — run on pve1, ping other nodes
ping -c 3 192.168.30.102  # pve2
ping -c 3 192.168.30.103  # pve3

# Verify VLAN 40 (Storage) — ping TrueNAS
ping -c 3 192.168.40.200

# Verify management still works
ping -c 3 192.168.11.1
```

---

## Verify VLAN-Aware Bridge

```bash
bridge vlan show
# Should show nic0 with VLANs 1-4094 registered
```

---

## VM Network Configuration

When creating VMs:

| Network | Bridge | VLAN Tag |
|---|---|---|
| Management (VLAN 11) | vmbr0 | (empty — native) |
| LAN (VLAN 20) | vmbr0 | 20 |
| Storage (VLAN 40) | vmbr0 | 40 |

**Important:** VMs on VLAN 11 (management) use `vmbr0` with NO VLAN tag — VLAN 11 is the native untagged VLAN on the switch trunk.
