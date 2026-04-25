# Proxmox Cluster Formation

## Prerequisites

- Proxmox VE 9.1.1 installed on all three nodes
- All nodes reachable on VLAN 11 (management)
- VLAN 30 (Ceph) network configured and pingable between nodes
- No existing cluster on any node

## Installation

Install Proxmox VE on each node using the official ISO. During installation set:

| Node | IP | Gateway | Hostname |
|---|---|---|---|
| pve1 | 192.168.11.2/24 | 192.168.11.1 | pve1 |
| pve2 | 192.168.11.3/24 | 192.168.11.1 | pve2 |
| pve3 | 192.168.11.4/24 | 192.168.11.1 | pve3 |

---

## Step 1 — Disable Enterprise Repos (All Nodes)

Run on **each node** before anything else:

```bash
# Disable enterprise subscription repo
echo "# disabled - no subscription" > /etc/apt/sources.list.d/pve-enterprise.list

# Disable enterprise Ceph repo
echo "# disabled - no subscription" > /etc/apt/sources.list.d/ceph.list

# Add Proxmox free repo
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

# Add Ceph Squid free repo
echo "deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription" \
  > /etc/apt/sources.list.d/ceph-no-subscription.list

# Update
apt update && apt upgrade -y
```

---

## Step 2 — Create Cluster on pve1 Only

```bash
# Run ONLY on pve1
# --link0 points Corosync at VLAN 30 (Ceph network)
# This keeps cluster heartbeat traffic isolated from management
pvecm create homelab-cluster --link0 192.168.30.101
```

Verify:
```bash
pvecm status
```

Expected output:
```
Name:             homelab-cluster
Transport:        knet
Nodes:            1
Quorate:          Yes
```

---

## Step 3 — Join pve2

```bash
# Run ONLY on pve2
pvecm add 192.168.30.101 --link0 192.168.30.102
```

Enter pve1's root password when prompted. Verify from pve1:

```bash
pvecm status
# Should show: Nodes: 2, Quorate: Yes
```

---

## Step 4 — Join pve3

```bash
# Run ONLY on pve3
pvecm add 192.168.30.101 --link0 192.168.30.103
```

---

## Step 5 — Final Verification

Run from any node:

```bash
pvecm status
```

Expected healthy output:
```
Cluster information
-------------------
Name:             homelab-cluster
Config Version:   3
Transport:        knet
Secure auth:      on

Quorum information
------------------
Nodes:            3
Quorate:          Yes
Expected votes:   3
Total votes:      3

Membership information
----------------------
    Nodeid      Votes Name
0x00000001          1 192.168.30.101 (local)
0x00000002          1 192.168.30.102
0x00000003          1 192.168.30.103
```

---

## Important Notes

- **Always use VLAN 30 IPs for --link0** — keeps Corosync traffic on the dedicated Ceph network, not management
- **Three nodes = quorum of 2** — the cluster stays healthy if one node goes down
- **Never run pvecm create on pve2 or pve3** — only the first node creates the cluster, others join it
- **Do not reboot all nodes simultaneously** — always keep at least 2 nodes running to maintain quorum
