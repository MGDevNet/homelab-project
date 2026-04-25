# WiFi Optimization for U7 Pro XG (UniFi)

## Hardware

- **AP**: Ubiquiti U7 Pro XG (WiFi 7, tri-band 2.4/5/6 GHz)
- **Switch port**: Cisco 2960CX Gi0/1
- **Uplink**: Gigabit Ethernet (the U7 Pro XG can do 2.5G but the switch is gigabit)
- **VLAN**: 20 (LAN, 192.168.20.0/24)

## Switch Port Configuration

```
SW2960CX#conf t
SW2960CX(config)#interface GigabitEthernet0/1
SW2960CX(config-if)#description UniFi-AP-U7-Pro-XG
SW2960CX(config-if)#switchport mode access
SW2960CX(config-if)#switchport access vlan 20
SW2960CX(config-if)#spanning-tree portfast
SW2960CX(config-if)#no shutdown
SW2960CX(config-if)#end
SW2960CX#write memory
```

## Why Access Mode Instead of Trunk

We're using **access port VLAN 20** instead of trunk. Even though trunk would let the AP broadcast multiple SSIDs on different VLANs, our setup uses the Cisco 1921 router for inter-VLAN routing — so WiFi clients on VLAN 20 can still reach servers on VLAN 11 through the router.

This is simpler and there's no benefit to trunk for a single-SSID setup.

## Cable Diagnostics

Always verify the cable is good before troubleshooting WiFi performance. CRC errors mean the cable is dropping packets and WiFi will feel slow even though it shows full link speed.

```
SW2960CX#show interfaces gi0/1 status
SW2960CX#show interfaces gi0/1 | include errors|CRC

SW2960CX#test cable-diagnostics tdr interface gi0/1
SW2960CX#show cable-diagnostics tdr interface gi0/1
```

Expected output for a healthy cable:
```
Pair A     37 +/- 10 meters    Normal
Pair B     37 +/- 10 meters    Normal
Pair C     37 +/- 10 meters    Normal
Pair D     37 +/- 10 meters    Normal
```

If any pair shows "Open", "Short", or "Crosstalk" — replace the cable.

## UniFi AP Settings

Open `https://unifi.home.lab` → **Devices → U7 Pro XG → Settings**.

### Radio Configuration

```
2.4 GHz Radio:
  Channel Width: 20 MHz   (NEVER use 40 in 2.4 GHz)
  Channel: Auto
  Transmit Power: Medium

5 GHz Radio:
  Channel Width: 80 MHz
  Channel: Auto
  Transmit Power: High

6 GHz Radio (WiFi 7):
  Channel Width: 160 MHz or 320 MHz
  Channel: Auto
  Transmit Power: High
```

### WiFi Network Settings

**Settings → WiFi → Edit your SSID**:

```
Standard:
  Network: Default (VLAN 20)
  Security: WPA3 + WPA2 (mixed mode)
  Band: 2.4 GHz, 5 GHz, 6 GHz

Advanced:
  PMF: Optional
  Hide SSID: OFF
  Group Rekey: 3600 sec
  802.11 DTIM Period 2.4: 1
  802.11 DTIM Period 5/6: 3
  Multicast Enhancement: ON
  Fast Roaming: ON
  Beacon Rate: 6 Mbps
  Min Data Rate Control 2.4: 12 Mbps
  Min Data Rate Control 5: 24 Mbps
```

The minimum data rate setting is important — it kicks slow legacy clients off the network and lets faster clients use more airtime.

### Site-wide Settings

**Settings → System**:
```
Country Code: United States
Inform Host: 192.168.11.55
```

**Settings → WiFi → Global Settings**:
```
Band Steering: ON (Prefer 5 GHz)
BSS Transition: ON
RRM (802.11k): ON
WMM: ON
```

## Troubleshooting Slow WiFi

If WiFi feels slow even with good signal:

### 1. Check the AP uplink

```
SW2960CX#show interfaces gi0/1 status
```

Should show `a-1000` for gigabit. If it shows `a-100` — the cable is bad or only Cat3/4. Replace it.

### 2. Check for CRC errors

```
SW2960CX#clear counters gi0/1
# Wait 5 minutes
SW2960CX#show interfaces gi0/1 | include errors|CRC
```

If errors are climbing — bad cable or bad port. Try a different port or cable.

### 3. Check inter-VLAN routing CPU

If WiFi is on VLAN 20 and servers are on VLAN 11, all traffic goes through the Cisco 1921. Check if the router is the bottleneck:

```
R1920#show processes cpu sorted | exclude 0.00
R1920#show interfaces | include rate
```

Cisco 1921 is rated for ~75 Mbps of routing throughput. For more speed, consider using a more powerful router or enabling **CEF** (Cisco Express Forwarding):

```
R1920(config)#ip cef
R1920(config)#ip cef distributed
```

### 4. Check WiFi channel utilization

In UniFi → **Devices → U7 Pro XG → Insights**:

```
Channel Utilization should be < 50%
```

If it's higher — your channel is congested. Force a manual channel:

5 GHz: try channel 36, 100, 149, or 161
6 GHz: try channel 1, 33, 65, or 97

### 5. Test direct vs through router

From a WiFi device, test:
```
ping 192.168.20.1   # Router (same VLAN, fast)
ping 192.168.11.20  # AdGuard (different VLAN, goes through router)
```

If pinging the same VLAN is fast but cross-VLAN is slow — the router is your bottleneck.

## Real-World Performance Expectations

For the U7 Pro XG on a gigabit uplink:

| Client | Band | Realistic Speed |
|---|---|---|
| iPhone 15 Pro | 6 GHz WiFi 7 | 1.5+ Gbps to local |
| MacBook Pro M2 | 5 GHz WiFi 6 | 800-900 Mbps |
| Samsung S24 | 5 GHz WiFi 6 | 700-900 Mbps |
| Older iPhone (12, 13) | 5 GHz WiFi 6 | 400-600 Mbps |
| 2.4 GHz IoT device | 2.4 GHz | 50-100 Mbps |

Note: cross-VLAN traffic limited by Cisco 1921 (~75 Mbps).
For full WiFi speeds keep clients and servers on the same VLAN, or upgrade the router.

## Useful Cisco Commands

```
SW2960CX#show interfaces status                  # All ports at a glance
SW2960CX#show interfaces gi0/1 status            # One port detail
SW2960CX#show interfaces gi0/1 | include errors  # Error counters
SW2960CX#show mac address-table                  # Where devices are connected
SW2960CX#show vlan brief                         # VLAN config
SW2960CX#show interfaces trunk                   # Trunk ports
SW2960CX#show etherchannel summary               # Port channel state
SW2960CX#test cable-diagnostics tdr interface gi0/1
SW2960CX#show cable-diagnostics tdr interface gi0/1
```

## Lessons Learned

1. **A bad cable will absolutely tank WiFi performance** — even though the switch port shows it linked at gigabit, CRC errors mean packets get retransmitted and effective throughput drops to a fraction.

2. **TDR diagnostics is your friend** — Cisco's built-in cable test tells you exactly where the cable problem is in meters from the port.

3. **Inter-VLAN routing has a cost** — if all your clients are on one VLAN and servers on another, the router's CPU is in every conversation. Plan your VLANs based on traffic patterns, not just isolation.

4. **Don't use 40 MHz in 2.4 GHz** — there are only 3 non-overlapping channels in 2.4 GHz (1, 6, 11). Using 40 MHz means you're using 2 of them at once which guarantees interference.

5. **Min data rate control kicks slow clients off** — this is the single biggest WiFi optimization for crowded networks. It forces older devices to disconnect rather than slow everyone else down.
