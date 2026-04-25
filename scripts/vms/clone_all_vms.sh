#!/bin/bash
# VM Clone Script — WORKING VERSION
# Run on pve1 only
# Key lesson: clone all VMs from pve1, then SSH to target nodes to configure

set -e

echo "Step 1 — Cloning all VMs from template 9000..."

# pve1 VMs
qm clone 9000 110 --name jellyfin --full --target pve1
qm clone 9000 111 --name immich --full --target pve1
qm clone 9000 112 --name frigate --full --target pve1
qm clone 9000 113 --name zabbix --full --target pve1
qm clone 9000 114 --name wazuh --full --target pve1

# pve2 VMs
qm clone 9000 210 --name vaultwarden --full --target pve2
qm clone 9000 211 --name nextcloud --full --target pve2
qm clone 9000 212 --name grafana-prometheus --full --target pve2
qm clone 9000 213 --name elasticsearch --full --target pve2

# pve3 VMs
qm clone 9000 300 --name unifi-controller --full --target pve3

echo "All clones complete"
echo ""
echo "Step 2 — Configuring pve1 VMs..."

# Configure pve1 VMs locally
qm set 110 --ipconfig0 ip=192.168.11.56/24,gw=192.168.11.1 --cores 3 --memory 4096 --onboot 1
qm resize 110 scsi0 32G
echo "✓ VM 110 Jellyfin configured"

qm set 111 --ipconfig0 ip=192.168.11.57/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 111 scsi0 32G
echo "✓ VM 111 Immich configured"

qm set 112 --ipconfig0 ip=192.168.11.58/24,gw=192.168.11.1 --cores 2 --memory 3072 --onboot 1
qm resize 112 scsi0 32G
echo "✓ VM 112 Frigate configured"

qm set 113 --ipconfig0 ip=192.168.11.59/24,gw=192.168.11.1 --cores 2 --memory 4096 --onboot 1
qm resize 113 scsi0 32G
echo "✓ VM 113 Zabbix configured"

qm set 114 --ipconfig0 ip=192.168.11.60/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 114 scsi0 64G
echo "✓ VM 114 Wazuh configured"

echo ""
echo "Step 3 — Configuring pve2 VMs via SSH..."

# IMPORTANT: must SSH to pve2 to configure pve2 VMs
# Running qm set on pve1 immediately after clone fails — config not synced yet
ssh root@192.168.11.3 << 'SSHEOF'
qm set 210 --ipconfig0 ip=192.168.11.51/24,gw=192.168.11.1 --cores 1 --memory 512 --onboot 1
qm resize 210 scsi0 16G
echo "✓ VM 210 Vaultwarden configured"

qm set 211 --ipconfig0 ip=192.168.11.52/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 211 scsi0 32G
echo "✓ VM 211 Nextcloud configured"

qm set 212 --ipconfig0 ip=192.168.11.53/24,gw=192.168.11.1 --cores 2 --memory 2048 --onboot 1
qm resize 212 scsi0 32G
echo "✓ VM 212 Grafana+Prometheus configured"

qm set 213 --ipconfig0 ip=192.168.11.54/24,gw=192.168.11.1 --cores 2 --memory 6144 --onboot 1
qm resize 213 scsi0 64G
echo "✓ VM 213 Elasticsearch configured"
SSHEOF

echo ""
echo "Step 4 — Configuring pve3 VMs via SSH..."

ssh root@192.168.11.4 << 'SSHEOF'
qm set 300 --ipconfig0 ip=192.168.11.55/24,gw=192.168.11.1 --cores 1 --memory 1536 --onboot 1
qm resize 300 scsi0 16G
echo "✓ VM 300 UniFi Controller configured"
SSHEOF

echo ""
echo "Step 5 — Starting all VMs..."

# Start pve1 VMs
for vm in 110 111 112 113 114; do
  qm start $vm
  echo "Started VM $vm"
done

# Start pve2 VMs
ssh root@192.168.11.3 "for vm in 210 211 212 213; do qm start \$vm; echo \"Started VM \$vm\"; done"

# Start pve3 VMs
ssh root@192.168.11.4 "qm start 300 && echo 'Started VM 300'"

echo ""
echo "All VMs started. Wait 90 seconds then verify:"
echo "for ip in 51 52 53 54 55 56 57 58 59 60; do"
echo "  ping -c 1 -W 2 192.168.11.\$ip > /dev/null 2>&1 && echo \"192.168.11.\$ip ✓\" || echo \"192.168.11.\$ip ✗\""
echo "done"
