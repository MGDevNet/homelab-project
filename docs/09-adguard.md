# AdGuard Home Installation

## Overview

AdGuard Home runs as an LXC container (CT 101) on pve1. It serves as the DNS server for the entire network, blocking ads and tracking at the DNS level for every device automatically.

**IP:** 192.168.11.20  
**Web UI:** http://192.168.11.20  
**DNS port:** 53

---

## Installation

```bash
# Enter the AdGuard container
pct exec 101 -- bash

# Update system
apt update && apt upgrade -y
apt install -y curl

# Install AdGuard Home
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# Verify service is running
systemctl status AdGuardHome
```

---

## Initial Setup Wizard

Open `http://192.168.11.20:3000` and configure:

```
Admin Web Interface:
  Listen interface: All interfaces
  Port: 80

DNS Server:
  Listen interface: All interfaces
  Port: 53
```

Click **Next**, set admin credentials, click **Next** again, then **Open Dashboard**.

---

## DNS Settings

Go to **Settings → DNS Settings**:

```
Upstream DNS servers:
  8.8.8.8
  8.8.4.4
  https://dns.google/dns-query

Fallback DNS servers:
  8.8.8.8
  8.8.4.4

Bootstrap DNS servers:
  8.8.8.8
  8.8.4.4
```

**Important:** Do NOT use 1.1.1.1 on port 53 — it may be blocked upstream. Use DoH (https://dns.cloudflare.com/dns-query) instead if you want Cloudflare.

DNS Cache settings:
```
Enable cache: YES
Cache size: 4096
Override minimum TTL: 300
Override maximum TTL: 3600
Optimistic caching: YES
```

Click **Apply**.

---

## Blocklists

Go to **Filters → DNS Blocklists**:

Enable the default **AdGuard DNS filter** (already present).

Add these custom lists via **Add blocklist → Add a custom list**:

```
Name: Steven Black Hosts
URL: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

Name: EasyList
URL: https://easylist.to/easylist/easylist.txt

Name: Malware Domain List
URL: https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh.txt

Name: OISD Full
URL: https://big.oisd.nl
```

Click **Check for updates** after adding all lists.

---

## Critical — Avoid DNS Loop

**The AdGuard container must NOT use itself or the router as DNS.**

The container's `/etc/resolv.conf` must point to a hardcoded external DNS:

```bash
# Inside CT 101
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

Set permanently via Proxmox:
```bash
# Run on pve1
pct set 101 --nameserver 8.8.8.8
```

**Why:** If AdGuard uses the router as DNS, and the router uses AdGuard, you get:
```
Router → AdGuard → Router → AdGuard → infinite loop
```

---

## Configure Router to Use AdGuard

On the Cisco 1921:

```
conf t

! Router itself uses AdGuard
ip name-server 192.168.11.20

! DHCP clients get AdGuard as DNS
ip dhcp pool LAN
  dns-server 192.168.11.20

end
write memory
```

Verify DNS works:
```
R1920#ping google.com
```

---

## Verification

Test from any Proxmox node:
```bash
nslookup google.com 192.168.11.20
dig @192.168.11.20 google.com
```

Expected response time: ~1ms (cache hit) or ~10-15ms (upstream query).

Check the AdGuard dashboard — **Query Log** should show DNS queries from all your network devices.

---

## DNS for All VMs and Containers

Set AdGuard as DNS for all containers:

```bash
# Run on pve1
for ct in 101 102 103 104 105 106; do
  pct set $ct --nameserver 192.168.11.20
done

# Run on pve2
for ct in 201 202 203; do
  pct set $ct --nameserver 192.168.11.20
done

# Run on pve3
for ct in 301 302 303 304; do
  pct set $ct --nameserver 192.168.11.20
done
```

Update Proxmox nodes themselves:
```
pve1 → DNS → DNS server 1: 192.168.11.20
pve2 → DNS → DNS server 1: 192.168.11.20
pve3 → DNS → DNS server 1: 192.168.11.20
```

---

## Config File Location

AdGuard stores its config at:
```
/opt/AdGuardHome/AdGuardHome.yaml
```

This file persists across reboots. If settings appear lost after restart, check this file — the config is likely still there even if the web UI looks empty.
