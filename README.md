# Homelab — 3-Node Proxmox Cluster with Ceph HA, TrueNAS Storage, and Full Media Stack

A production-grade homelab built from scratch using enterprise-grade tools to learn cloud, networking, and DevOps. Inspired by what I do at work as an IT specialist managing infrastructure at scale.

## What's Running

```
┌────────────────────────────────────────────────────────────────┐
│ Cisco 1921 Router                                              │
│ Inter-VLAN routing, DHCP, NAT to internet                      │
└────┬───────────────────────────────────────────────────────────┘
     │
┌────┴─────────────────────────────────────────────────────────────┐
│ Cisco 2960L Core Switch (24 ports, gigabit)                     │
│ Port-channel uplink to access switch                             │
└────┬─────────────────────────────────────────────────────────────┘
     │
┌────┴─────────────────────────────────────────────────────────────┐
│ Cisco 2960CX Access Switch                                      │
│ Trunk uplink, access ports for end devices, AP on Gi0/1         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────┬──────────────┬──────────────┐
│ pve1         │ pve2         │ pve3         │
│ M720q        │ M720q        │ EliteDesk    │
│ i5-9500T 6c  │ i5-9500T 6c  │ i5-7500 4c   │
│ 32GB RAM     │ 24GB RAM     │ 16GB RAM     │
│ 500GB SSD    │ 500GB SSD    │ 500GB SSD    │
│ 512GB NVMe   │ 512GB NVMe   │ 512GB NVMe   │
└──────────────┴──────────────┴──────────────┘
        Proxmox VE 8.x cluster + Ceph HA storage

┌────────────────────────────────────────────────┐
│ TrueNAS SCALE                                  │
│ HP EliteDesk 800 G1 SFF, i5-4570, 32GB RAM    │
│ Backup pool: 500GB + 1TB SATA mirror          │
│ Data pool:   3-way 512GB NVMe mirror          │
│ L2ARC:       1TB Kingston NV3 SSD             │
│ NFS: media, downloads, photos, documents, pbs  │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ Ubiquiti U7 Pro XG (WiFi 7 AP)                 │
│ Connected to 2960CX Gi0/1 access port VLAN 20 │
└────────────────────────────────────────────────┘
```

## Network Design

| VLAN | Name | Subnet | Gateway | Purpose |
|---|---|---|---|---|
| 11 | Management | 192.168.11.0/24 | .1 | Proxmox UI, SSH, all services |
| 20 | LAN | 192.168.20.0/24 | .1 | Client devices, WiFi |
| 30 | Ceph | 192.168.30.0/24 | none | Ceph replication only |
| 40 | Storage | 192.168.40.0/24 | none | TrueNAS NFS/SMB |

## Service Map

### Phase 1 — Infrastructure (Complete)

| Service | URL | Purpose |
|---|---|---|
| AdGuard Home | https://adguard.home.lab | DNS + ad blocking for all devices |
| Nginx Proxy Manager | http://192.168.11.50:81 | Reverse proxy + SSL |
| Vaultwarden | https://vault.home.lab | Password manager (Bitwarden compatible) |
| UniFi Controller | https://unifi.home.lab | WiFi management |
| Proxmox Backup Server | https://pbs.home.lab | VM/container backups |

### Phase 2 — Media Stack (Complete)

| Service | URL | Purpose |
|---|---|---|
| Jellyfin | https://jellyfin.home.lab | Stream movies/TV to any device |
| Jellyseerr | http://jellyseerr.home.lab | Browse and request like Netflix |
| Sonarr | http://sonarr.home.lab | Auto-download TV shows |
| Radarr | http://radarr.home.lab | Auto-download movies |
| Prowlarr | http://prowlarr.home.lab | Indexer manager |
| qBittorrent | http://qbit.home.lab | Torrent client |

### Phase 3 — Coming Next

- Immich — self-hosted Google Photos
- Frigate — AI security cameras
- Nextcloud — self-hosted Google Drive
- Paperless-ngx — document management
- Grafana + Prometheus — monitoring
- Wazuh + ELK — security SIEM
- Home Assistant — smart home

## VM and Container Distribution

```
pve1 (32GB RAM, i5-9500T)
├── CT 101 — AdGuard Home          192.168.11.20
├── CT 102 — Radarr + Sonarr        192.168.11.21
├── CT 103 — Prowlarr + qBit + Jellyseerr  192.168.11.22
├── VM 110 — Jellyfin               192.168.11.56  (8GB RAM)
└── (Future) Immich, Frigate, Zabbix, Wazuh

pve2 (24GB RAM, i5-9500T)
├── VM 200 — Nginx Proxy Manager    192.168.11.50
├── VM 210 — Vaultwarden             192.168.11.51
└── (Future) Nextcloud, Grafana, Paperless

pve3 (16GB RAM, i5-7500)
├── VM 100 — Proxmox Backup Server   192.168.11.10
├── VM 300 — UniFi Controller        192.168.11.55
└── (Future) Gitea, Portainer, Kavita
```

## Storage Architecture

```
TrueNAS (192.168.11.125 / 192.168.40.200)
├── data pool (3-way NVMe mirror, 461GB usable)
│   ├── /mnt/data/media       → Jellyfin movies/TV
│   ├── /mnt/data/downloads   → qBittorrent downloads
│   ├── /mnt/data/photos      → Immich photos
│   ├── /mnt/data/documents   → Paperless documents
│   └── /mnt/data/proxmox     → ISOs and templates
└── backup pool (500GB+1TB mirror, 462GB usable)
    └── /mnt/backup/pbs       → Proxmox Backup Server datastore

Ceph (across pve1+pve2+pve3)
└── 3-replica VM/CT storage with HA failover
```

## Key Skills Demonstrated

This project demonstrates real-world skills used in cloud and infrastructure roles:

- **Networking**: VLAN segmentation, 802.1Q trunking, EtherChannel, router-on-a-stick, DHCP services, DNS infrastructure, cable troubleshooting (CRC errors, TDR diagnostics)
- **Virtualization**: Proxmox cluster, HA failover, live migration, LXC + KVM
- **Storage**: Ceph distributed storage, ZFS pools and datasets, NFS exports, multi-VLAN storage networks
- **Linux**: Cloud-init, systemd, NFS mounting, SSH key management, iptables
- **Containers**: Docker, Docker Compose, multi-container stacks, bind mounts, networking
- **Infrastructure as Code**: Reproducible scripts, configuration management
- **Reverse proxy and TLS**: Nginx Proxy Manager, self-signed wildcard certificates
- **DNS infrastructure**: Local domain resolution with AdGuard rewrites
- **Backup and DR**: Proxmox Backup Server with deduplication and incremental backups
- **Security**: Network segmentation, password manager hosting, firewall rules

## Quick Start for Each Section

See the `docs/` folder for detailed walkthroughs:

1. [Cisco Network Setup](docs/01-cisco-network.md)
2. [Proxmox Cluster](docs/02-proxmox-cluster.md)
3. [Proxmox Network Config](docs/03-proxmox-network.md)
4. [Ceph Setup](docs/04-ceph-setup.md)
5. [TrueNAS Setup](docs/05-truenas-setup.md)
6. [Proxmox Backup Server](docs/06-pbs-setup.md)
7. [LXC Containers](docs/07-lxc-containers.md)
8. [VM Deployment](docs/08-vm-deployment.md)
9. [AdGuard Home](docs/09-adguard.md)
10. [Nginx Proxy Manager](docs/10-npm.md)
11. [UniFi Controller](docs/11-unifi.md)
12. [Vaultwarden](docs/12-vaultwarden.md)
13. [Jellyfin](docs/13-jellyfin.md)
14. [Media Stack (Sonarr/Radarr/Prowlarr/qBit/Jellyseerr)](docs/14-media-stack.md)
15. [WiFi Optimization](docs/15-wifi-optimization.md)
16. [Lessons Learned](docs/lessons-learned.md)

## Lessons Learned (Top 8)

The biggest takeaways from building this homelab — see [lessons-learned.md](docs/lessons-learned.md) for full details:

1. **NFS in LXC containers** — unprivileged LXCs can't mount NFS directly. Mount on Proxmox host first then bind-mount into the container.

2. **ZFS child datasets hide files** — when child datasets are mounted under a parent path, any files written to the parent at that path become invisible until you unmount the child.

3. **Multi-interface NFS exports** — TrueNAS with multiple network interfaces needs explicit network ACLs for each VLAN. Both `192.168.40.0/24` AND `192.168.11.0/24` must be allowed.

4. **Cable quality matters** — CRC errors on a switch port indicate physical layer problems. A bad Cat5 cable will tank gigabit performance even though it appears to link up.

5. **Docker UID/GID** — LinuxServer Docker images all run as UID 1000. NFS shares need correct ownership (`chown 1000:1000`) for these containers to write.

6. **Cloud-init quirks** — Ubuntu cloud images sometimes don't accept passwords through cloud-init. Use `virt-customize` after VM creation as a fallback.

7. **VM RAM defaults are too small** — 512MB causes OOM crashes for NPM and Jellyfin. NPM needs 1GB, Jellyfin needs 8GB.

8. **HTTPS requires real TLS** — services like Vaultwarden won't work over HTTP because the browser SubtleCrypto API requires a secure context. Always use SSL even for local services.

## Hardware Total Cost

Approximately $1,200 over time, mostly used/refurbished:

- 2x ThinkCentre M720q (used, $200 each)
- 1x EliteDesk 800 G3 (used, $150)
- 1x EliteDesk 800 G1 SFF (used, $100)
- 3x 512GB NVMe SSDs (~$40 each)
- Cisco 1921, 2960L, 2960CX (used, ~$300 total)
- U7 Pro XG (~$200)
- Cables, racks, misc (~$100)

## License

MIT — feel free to use any of this for your own homelab.

---

Built by [Manuel Garcia Bouza](https://github.com/) — Cloud/Network Engineer, IT Specialist
