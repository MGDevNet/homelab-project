# UniFi Network Controller Installation

## What Is It

The UniFi Network Controller manages all your Ubiquiti UniFi access points,
switches and cameras from a single web interface. It controls your WiFi
networks, VLANs, client visibility, traffic stats and firmware updates.

## Why You Need It

Without the controller your UniFi APs go into standalone mode — you lose
centralized management, your configured VLANs, guest networks and all
statistics. The controller must always be running for your WiFi to work properly.

## Enterprise Equivalent

Cisco DNA Center or Aruba Central — centralized wireless LAN controller.

## VM Details

- **VM:** 300
- **IP:** 192.168.11.55
- **Node:** pve3 (HA on Ceph)
- **RAM:** 1.5 GB
- **SSH:** `ssh admin@192.168.11.55`

---

## Installation

SSH into VM 300:
```bash
ssh admin@192.168.11.55
```

Update and install dependencies:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg2 ca-certificates
```

Add UniFi repository:
```bash
curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/unifi.gpg

echo "deb [signed-by=/usr/share/keyrings/unifi.gpg] \
  https://www.ui.com/downloads/unifi/debian stable ubiquiti" | \
  sudo tee /etc/apt/sources.list.d/unifi.list
```

Install UniFi:
```bash
sudo apt update
sudo apt install -y unifi
```

Enable and start:
```bash
sudo systemctl enable unifi
sudo systemctl start unifi
sudo systemctl status unifi
```

---

## Initial Setup

Open the UniFi web UI:
```
https://192.168.11.55:8443
```

Accept the self-signed certificate warning and follow the setup wizard:

1. Create UniFi account or use local account
2. Set controller name: `homelab-unifi`
3. Set country and timezone
4. Skip cloud key setup

---

## Adopt Access Points

After setup your APs should appear under **Devices** as pending adoption.
Click each one and select **Adopt**.

If APs don't appear:
```bash
# SSH into the AP directly and inform it of the controller
ssh ubnt@<AP-IP>
set-inform http://192.168.11.55:8080/inform
```

---

## Configure WiFi Networks

Go to **Settings → WiFi → Add New**:

```
Network 1 — Main WiFi
  Name (SSID): YourWiFiName
  Password: YourPassword
  VLAN: 20 (LAN)

Network 2 — IoT
  Name (SSID): YourIoT-Network
  Password: IoTPassword
  VLAN: 50 (IoT — if you create one)
```

---

## Verification

```bash
# Check UniFi service
sudo systemctl status unifi

# Check ports
ss -tlnp | grep -E '8080|8443|8880|6789'
```

Expected ports:
```
8080  ← device inform port
8443  ← web UI (HTTPS)
8880  ← HTTP redirect
6789  ← speed test
```
