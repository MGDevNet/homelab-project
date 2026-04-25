#!/bin/bash
# Ceph Health Check and Maintenance Script
# Run on any Proxmox node

echo "================================================="
echo "CEPH CLUSTER HEALTH CHECK"
echo "================================================="
echo ""

echo "--- Overall Status ---"
ceph status
echo ""

echo "--- OSD Status ---"
ceph osd stat
echo ""

echo "--- Monitor Status ---"
ceph mon stat
echo ""

echo "--- Manager Status ---"
ceph mgr stat
echo ""

echo "--- Pool Status ---"
ceph df
echo ""

echo "--- Placement Group Status ---"
ceph pg stat
echo ""

echo "--- Disk Usage ---"
ceph osd df tree
echo ""

echo "--- Check for Warnings ---"
ceph health detail
echo ""

echo "================================================="
echo "PROXMOX HA STATUS"
echo "================================================="
echo ""
ha-manager status
echo ""

echo "================================================="
echo "CLUSTER NODE STATUS"
echo "================================================="
echo ""
pvecm status
echo ""
pvecm nodes
