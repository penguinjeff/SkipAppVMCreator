#!/bin/bash
set -euo pipefail

echo "[INFO] Checking dependencies..."

REQUIRED_CMDS=(virsh virt-install genisoimage cloud-init qemu-img)

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Missing required command: $cmd"
        exit 1
    fi
done

# Check libvirt connection
if ! virsh --connect qemu:///system list >/dev/null 2>&1; then
    echo "[ERROR] Cannot connect to libvirt. Is libvirtd running? Are you in the libvirt group?"
    exit 1
fi

echo "[OK] Dependencies verified."
