# Lessons Learned and Troubleshooting

This document captures real problems encountered during this homelab build and their solutions. Read this before starting to avoid hours of debugging.

---

## Hardware Lessons

### PCIe NVMe Adapters — Q87 Chipset

**Problem:** Most quad NVMe PCIe adapters require bifurcation support in BIOS. The HP EliteDesk 800 G1 uses the Q87 chipset which has NO bifurcation support.

**Symptom:** Only one NVMe drive shows up instead of four.

**Solution:** Buy an adapter with a PLX PEX8747 or ASM2824 PCIe switch chip. These handle lane splitting internally without needing BIOS support.

**How to identify working adapters:**
- Must say "no bifurcation required" or "works without BIOS bifurcation"
- Must mention PLX, PEX8747, or ASM2824 chipset
- Any adapter mentioning X299, X399, or "server motherboard required" will NOT work

**Search terms:** "PLX 8747 quad M.2 NVMe PCIe x16" or "PEX8747 M.2 adapter"

---

## Proxmox Network Lessons

### VLAN-Aware Bridge vs Subinterfaces

**Problem:** Using `nic0.40` style subinterfaces alongside a VLAN-aware bridge on `vmbr0` caused conflicts. VMs couldn't start with the error "no physical interface on bridge."

**Root cause:** When `vmbr0` has `bridge-vlan-aware yes`, it manages all VLANs through the bridge. Adding `nic0.40` as a separate subinterface of the physical NIC creates a conflict — the kernel tries to handle VLAN 40 two different ways simultaneously.

**Solution:** Use `vmbr0.40` instead of `nic0.40`. The bridge subinterface syntax works correctly with VLAN-aware bridges.

```bash
# WRONG
auto nic0.40
iface nic0.40 inet static
    address 192.168.40.101/24
    vlan-raw-device nic0

# CORRECT
auto vmbr0.40
iface vmbr0.40 inet static
    address 192.168.40.101/24
    vlan-raw-device vmbr0
```

### VM VLAN Tag on Native VLAN

**Problem:** Setting VLAN tag 11 on a VM network interface when VLAN 11 is the native (untagged) VLAN on the switch trunk caused a double-tagging conflict. VMs failed to start.

**Solution:** Leave the VLAN tag field empty for VMs on VLAN 11. Native VLAN traffic is already untagged at the switch, so no tag is needed in Proxmox.

---

## Ceph Lessons

### Disk Wipe Before OSD Creation

**Problem:** NVMe drives that previously had Windows installed still had partition tables. `pveceph osd create` fails on drives with existing partitions.

**Solution:** Always wipe drives before creating OSDs:
```bash
wipefs -a /dev/nvme0n1
sgdisk --zap-all /dev/nvme0n1
```

### Placement Group Count Warning

**Problem:** Default PG count of 128 is too high for 3 OSDs with 1 pool. Ceph shows `HEALTH_WARN: 1 pools have too many placement groups`.

**Solution:**
```bash
ceph osd pool set vmdata pg_num 32
ceph osd pool set vmdata pgp_num 32
```

Formula: `(OSDs × 100) / replicas = (3 × 100) / 3 = 100`, rounded down to nearest power of 2 = 64 (or 32 for conservative homelab).

---

## TrueNAS Lessons

### Create Pools Through UI, Not CLI

**Problem:** Pools created via `zpool create` CLI do not register with TrueNAS middleware. They show in datasets but not in Storage → Pools. NFS shares cannot be created for paths in CLI-created pools because TrueNAS doesn't recognize them as valid pool mount points.

**Solution:** Always create pools through **Storage → Create Pool** in the TrueNAS web UI. If you accidentally create via CLI, destroy it and recreate through UI:
```bash
zpool destroy backup
```
Then create through the web UI.

### Mixed Disk Sizes in Mirror

**Problem:** TrueNAS web UI refuses to create a mirror with drives of different sizes.

**Solution:** Either use drives of the same size, or force-create via CLI:
```bash
zpool create -f backup mirror sda sdc
```
ZFS mirrors at the smaller drive's size. Extra space on the larger drive is unused but the drive still provides full redundancy.

---

## DNS Loop Problem

**Problem:** After configuring AdGuard as the router's DNS server, the router could no longer resolve hostnames. AdGuard also couldn't resolve because it was using the router as its upstream.

**Loop:**
```
Router → AdGuard (192.168.11.20) → Router (192.168.11.1) → AdGuard → ...
```

**Solution:** AdGuard container must use hardcoded external DNS, never the router:
```bash
# Inside AdGuard container
echo "nameserver 8.8.8.8" > /etc/resolv.conf
pct set 101 --nameserver 8.8.8.8
```

In AdGuard → Settings → DNS Settings, Bootstrap DNS must also be hardcoded IPs (8.8.8.8, 8.8.4.4), not pointing to the router.

---

## VM Deployment Lessons

### Ubuntu Server ISO Installer Bug

**Problem:** Ubuntu 24.04.2 live server ISO installer crashes with `ServerDisconnectedError` on the mirror configuration screen. This is a known bug in the subiquity installer.

**Solution:** Do NOT use the Ubuntu Server ISO for VM installation. Use the Ubuntu cloud image instead:
```bash
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

This deploys instantly via cloning with no interactive installer.

### qm create --node Flag

**Problem:** The `--node` flag in `qm create` is not valid when running directly on a Proxmox node. It causes the command to fail silently — printing an error but then showing "success."

**Solution:** Remove `--node` from all `qm create` commands. When running on pve2, VMs are automatically created on pve2. Use `--target` only in `qm clone` to place clones on other nodes.

```bash
# WRONG — --node is not a valid qm create option
qm create 200 --name npm --node pve2 ...

# CORRECT — just run on the target node
qm create 200 --name npm ...
```

### Template Must Use Ceph Storage

**Problem:** VM template created on local-lvm cannot be cloned to another node. `qm clone 9000 200 --target pve2` fails with "can't clone VM to node pve2 (VM uses local storage)."

**Solution:** The template's disk must be on shared Ceph storage (vmdata), not local-lvm. Recreate the template with `--efidisk0 vmdata:1` and import the cloud image to `vmdata`.

### Cloud-Init userdata.yaml Syntax

**Problem:** The `chpasswd.list` multiline string format is deprecated in cloud-init 22.2+. Using it causes cloud-init to fail, leaving the VM with no user created and no SSH access.

**Broken syntax (deprecated):**
```yaml
chpasswd:
  list: |
    admin:password
```

**Working syntax:**
```yaml
chpasswd:
  users:
    - name: admin
      password: PUTPASSWD_HERE
      type: text
  expire: false
```

### Cloud-Init User Creation Error

**Problem:** Cloud-init fails with `useradd: group admin exists` because Ubuntu cloud images have a pre-existing `admin` group.

**Solution:** Specify `-g users` (not `-g admin`) in the useradd command, or fix manually via console:
```bash
userdel -r admin 2>/dev/null || true
useradd -m -s /bin/bash -g users -G sudo admin
echo "admin:PUTPASSWD_HERE" | chpasswd
```

---

## EtherChannel Already Configured

**Observation:** The Cisco 2960CX and 2960L already had EtherChannel (Port-channel1) configured and running on the SFP uplink ports before we started. No EtherChannel configuration was needed — it was working correctly from the start.

**Lesson:** Always run `show cdp neighbors` on all devices before planning network changes. CDP output shows exactly how devices are connected, which ports are used, and what's already working.

---

## Performance Notes

- **NVMe for Ceph** is essential for fast HA failover. HDD-based Ceph is functional but VM restart after failover takes 30-60 seconds. NVMe brings this down to seconds.
- **L2ARC cache** (Kingston NV3 1TB) actively boosted NFS reads above gigabit theoretical maximum (116 MB/s measured vs 125 MB/s theoretical). It starts working immediately after pool creation.
- **Mismatched RAM** (8+16 GB in pve2) runs in single-channel mode for 8 GB. For Jellyfin transcoding workloads, consider upgrading to 2×16 GB matched sticks.

---

## VM Clone to Other Nodes — qm set Timing Issue

**Problem:** After `qm clone 9000 210 --target pve2`, running `qm set 210` immediately on pve1 fails with "Configuration file does not exist". The config hasn't synced to pve1 yet.

**Solution:** Run `qm set` on the **target node**, not pve1:
```bash
# Clone on pve1
qm clone 9000 210 --name vaultwarden --full --target pve2

# Configure on pve2
ssh root@192.168.11.3 "qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1"
ssh root@192.168.11.3 "qm resize 210 scsi0 16G"
```

---

## Never Touch EFI Disk After Cloning

**Problem:** After cloning a VM, deleting and recreating the efidisk0 wipes the UEFI boot entries. The VM then shows "No bootable device found" even though the OS disk has Ubuntu on it.

**Symptom:** OVMF UEFI screen shows "failed to load Boot0002 UEFI QEMU HARDDISK — Not Found"

**Solution:** Never run qm set with --delete efidisk0 or --efidisk0 after cloning. The EFI disk is cloned correctly — leave it alone.

---

## Destroying VMs Completely

**Problem:** qm destroy sometimes leaves config files behind, causing "config file already exists" on the next clone attempt.

**Solution:** Always destroy with both flags:
```bash
qm destroy $vm --purge --destroy-unreferenced-disks 1
```

If config files still remain:
```bash
rm -f /etc/pve/nodes/pve1/qemu-server/${vm}.conf
```

---

## NFS Mount in LXC Containers

**Problem:** LXC containers (especially unprivileged ones) cannot mount NFS shares directly.

**Solution:** Mount NFS on the Proxmox host first, then bind-mount into the LXC container:

```bash
# On Proxmox host
mount -t nfs 192.168.40.200:/mnt/data/media /mnt/pve/truenas-media

# Add bind mount to LXC config
pct stop 102
pct set 102 -mp0 /mnt/pve/truenas-media,mp=/mnt/media
pct start 102
```

---

## Hidden Files Behind Mount Points

**Problem:** When ZFS child datasets are created (data/media, data/downloads), they hide any files written to the parent dataset at those paths. Files appear to vanish.

**Symptom:** `du -sh /mnt/data` shows 34GB used, but all child folders show as empty (~128KB each).

**Solution:** Unmount the child dataset to reveal the hidden files in the parent:

```bash
# In TrueNAS shell
sudo zfs umount data/media
ls /mnt/data/media/  # Now shows the hidden files

# Move files into the child dataset properly
# (or restructure so all data goes into child datasets)
```

**Prevention:** Either use only the root dataset (no children) or always write through NFS shares which use the child datasets directly.

---

## TrueNAS Multi-Interface NFS

**Problem:** TrueNAS with two network interfaces (VLAN 11 and VLAN 40) can serve different content depending on which IP a client uses to mount.

**Solution:** Make sure NFS exports allow both networks:
```
Networks: 192.168.40.0/24, 192.168.11.0/24
```

This way clients on either VLAN see the same files.

---

## qBittorrent NFS Permission Errors

**Problem:** qBittorrent runs as UID 1000 and can't write to NFS shares owned by root.

**Symptom:** Logs show `chown: changing ownership of '/downloads': Operation not permitted`.

**Solution:**
```bash
# On Proxmox host
chown -R 1000:1000 /mnt/pve/truenas-downloads
chmod -R 777 /mnt/pve/truenas-downloads
```

LinuxServer Docker images all use UID 1000 by default.

---

## Sonarr "Path does not exist" Error

**Problem:** Sonarr logs show `Import failed, path does not exist or is not accessible`, even though the file is visible via `ls`.

**Cause:** The Docker container loses access to the NFS mount when the LXC container restarts. The mount inside `/mnt/media` becomes a directory in the container's local filesystem instead of the NFS bind mount.

**Solution:**
1. Stop the LXC container
2. Make sure NFS is mounted on the Proxmox host
3. Verify bind mount in LXC config (`mp0:` and `mp1:` lines)
4. Start the LXC container — Docker containers will pick up the bind mount
