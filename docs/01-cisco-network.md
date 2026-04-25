# Cisco Network Configuration

## Topology

```
ISP
  ↓
Cisco 1921 Router (NAT + inter-VLAN routing)
  ↓ Gi0/1 → Gi0/7
Cisco 2960L (core switch)
  ↓ Po1 (EtherChannel — Gi0/9+Gi0/10 ↔ Gi0/11+Gi0/12)
Cisco 2960CX (access switch — Proxmox nodes here)
  ├── Gi0/6 → pve1
  ├── Gi0/7 → pve2
  ├── Gi0/8 → pve3
  └── Gi0/9 → TrueNAS
```

---

## 2960CX — Access Switch

```
! Create VLANs
vlan 11
 name Management
vlan 20
 name LAN
vlan 30
 name Ceph
vlan 40
 name Storage

! Proxmox Node 1 — pve1
interface GigabitEthernet0/6
 description ProxMox-Node1-pve1
 switchport mode trunk
 switchport trunk native vlan 11
 switchport trunk allowed vlan 11,20,30,40
 switchport nonegotiate
 spanning-tree portfast trunk
 no shutdown

! Proxmox Node 2 — pve2
interface GigabitEthernet0/7
 description ProxMox-Node2-pve2
 switchport mode trunk
 switchport trunk native vlan 11
 switchport trunk allowed vlan 11,20,30,40
 switchport nonegotiate
 spanning-tree portfast trunk
 no shutdown

! Proxmox Node 3 — pve3
interface GigabitEthernet0/8
 description ProxMox-Node3-pve3
 switchport mode trunk
 switchport trunk native vlan 11
 switchport trunk allowed vlan 11,20,30,40
 switchport nonegotiate
 spanning-tree portfast trunk
 no shutdown

! TrueNAS
interface GigabitEthernet0/9
 description TrueNAS
 switchport mode trunk
 switchport trunk native vlan 11
 switchport trunk allowed vlan 11,20,40
 switchport nonegotiate
 spanning-tree portfast trunk
 no shutdown

! EtherChannel uplink to 2960L (SFP ports)
interface Port-channel1
 switchport trunk allowed vlan 11,20,30,40

! Save
end
write memory
```

---

## 2960L — Core Switch

```
! Create same VLANs
vlan 11
 name Management
vlan 20
 name LAN
vlan 30
 name Ceph
vlan 40
 name Storage

! EtherChannel toward 2960CX
interface range GigabitEthernet0/9 - 10
 channel-group 1 mode active
 no shutdown

interface Port-channel1
 switchport trunk allowed vlan 11,20,30,40

! Uplink to 1921 router
interface GigabitEthernet0/7
 switchport mode trunk
 switchport trunk allowed vlan 11,20,40
 switchport trunk native vlan 20
 no shutdown

! Save
end
write memory
```

---

## Cisco 1921 Router — Inter-VLAN Routing

```
! Enable interface toward 2960L
interface GigabitEthernet0/1
 no shutdown

! VLAN 11 — Management
interface GigabitEthernet0/1.11
 description Management
 encapsulation dot1Q 11
 ip address 192.168.11.1 255.255.255.0

! VLAN 20 — LAN
interface GigabitEthernet0/1.20
 description LAN
 encapsulation dot1Q 20
 ip address 192.168.20.1 255.255.255.0

! VLAN 40 — Storage
interface GigabitEthernet0/1.40
 description Storage
 encapsulation dot1Q 40
 ip address 192.168.40.1 255.255.255.0

! NOTE: VLAN 30 (Ceph) deliberately excluded — stays local to Proxmox nodes only

! DNS — point to AdGuard Home after it's deployed
ip name-server 192.168.11.20

! DHCP pool — push AdGuard as DNS to all clients
ip dhcp excluded-address 192.168.11.0 192.168.11.50
ip dhcp pool LAN
 network 192.168.11.0 255.255.255.0
 default-router 192.168.11.1
 dns-server 192.168.11.20

! Save
end
write memory
```

---

## Verification Commands

```
! Verify EtherChannel is up
show etherchannel summary

! Verify trunk ports
show interfaces trunk

! Verify VLANs
show vlan brief

! Verify DHCP
show ip dhcp binding
show ip dhcp pool

! Test DNS through AdGuard
ping google.com
```

---

## Important Notes

- **VLAN 30 (Ceph) has no gateway on the 1921** — Ceph replication traffic must never leave the Proxmox cluster
- **Native VLAN 11 on all node ports** — Proxmox management traffic is untagged, so `vmbr0` works without any VLAN tag
- **EtherChannel between switches** — provides 2 Gbps uplink and link redundancy between 2960CX and 2960L
- **AdGuard as DNS** — configure the 1921 DHCP pool to push `192.168.11.20` as DNS only after AdGuard is deployed and tested
