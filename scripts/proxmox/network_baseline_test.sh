#!/bin/bash
# Network and Storage Performance Baseline Test
# Run after full cluster setup to establish baseline metrics
# Expected results on gigabit network:
#   Node-to-node: ~937 Mbps
#   NFS write:    ~92 MB/s
#   NFS read:     ~116 MB/s (with L2ARC cache active)

echo "Installing iperf3 if not present..."
apt install -y iperf3 nmap 2>/dev/null

echo ""
echo "================================================="
echo "HOMELAB NETWORK PERFORMANCE BASELINE TEST"
echo "================================================="
echo ""

# =============================================================
# NODE-TO-NODE TESTS
# Run server on target node first, then run this script
# =============================================================
echo "Instructions:"
echo "  1. On pve2, run: iperf3 -s -B 192.168.11.3"
echo "  2. On pve1, run this script"
echo ""

read -p "Press Enter when iperf3 server is running on pve2..."

echo ""
echo "--- VLAN 11 (Management) pve1 → pve2 ---"
iperf3 -c 192.168.11.3 -t 10 -P 4 2>/dev/null | grep -E "SUM|sender|receiver" | tail -2

echo ""
echo "--- VLAN 30 (Ceph) pve1 → pve2 ---"
echo "Start iperf3 server on pve2 VLAN 30: iperf3 -s -B 192.168.30.102"
read -p "Press Enter when ready..."
iperf3 -c 192.168.30.102 -t 10 -P 4 2>/dev/null | grep -E "SUM|sender|receiver" | tail -2

echo ""
echo "--- VLAN 40 (Storage) pve1 → TrueNAS ---"
echo "Start iperf3 server on TrueNAS: iperf3 -s -B 192.168.40.200"
read -p "Press Enter when ready..."
iperf3 -c 192.168.40.200 -t 10 -P 4 2>/dev/null | grep -E "SUM|sender|receiver" | tail -2

echo ""
echo "================================================="
echo "NFS PERFORMANCE TEST"
echo "================================================="
echo ""

NFS_PATH="/mnt/pve/truenas-iso"

if mountpoint -q $NFS_PATH; then
  echo "--- NFS Write Speed (to TrueNAS) ---"
  dd if=/dev/zero of=$NFS_PATH/testfile bs=1M count=1000 oflag=direct 2>&1 | tail -1

  echo ""
  echo "--- NFS Read Speed (from TrueNAS, L2ARC cache) ---"
  dd if=$NFS_PATH/testfile of=/dev/null bs=1M 2>&1 | tail -1

  # Cleanup
  rm -f $NFS_PATH/testfile
  echo ""
  echo "Test file cleaned up"
else
  echo "WARNING: $NFS_PATH not mounted — skipping NFS test"
fi

echo ""
echo "================================================="
echo "CEPH PERFORMANCE TEST"
echo "================================================="
echo ""

if command -v rbd &> /dev/null; then
  echo "--- Ceph RBD Write Speed ---"
  rbd bench --io-type write --io-size 4096 --io-threads 16 --io-total 512M vmdata/bench-test 2>/dev/null | tail -3
  rbd rm vmdata/bench-test 2>/dev/null
  echo "Bench image cleaned up"
else
  echo "WARNING: rbd not available — skipping Ceph test"
fi

echo ""
echo "================================================="
echo "DNS PERFORMANCE TEST"
echo "================================================="
echo ""
echo "--- AdGuard DNS response time ---"
for i in 1 2 3 4 5; do
  dig @192.168.11.20 google.com | grep "Query time"
done

echo ""
echo "================================================="
echo "BASELINE TEST COMPLETE"
echo "================================================="
echo ""
echo "Save these results and compare after adding workloads."
echo "Any significant degradation indicates a bottleneck."
