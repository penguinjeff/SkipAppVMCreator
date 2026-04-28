#!/bin/bash
set -euo pipefail

VM_NAME="skipappvm"

echo "[INFO] Checking for existing VM..."

if virsh --connect qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo "[WARN] Existing VM found — destroying..."
    virsh --connect qemu:///system destroy "$VM_NAME" 2>/dev/null || true
    virsh --connect qemu:///system undefine "$VM_NAME"
fi

if [[ ! -f ubuntu-cloud.img ]]; then
    echo "[ERROR] ubuntu-cloud.img missing."
    exit 1
fi

if [[ ! -f seed.iso ]]; then
    echo "[ERROR] seed.iso missing."
    exit 1
fi

echo "[INFO] Creating VM..."

virt-install --connect qemu:///system \
  --name "$VM_NAME" \
  --ram 2048 \
  --vcpus 2 \
  --disk path=ubuntu-cloud.img,format=qcow2 \
  --disk path=seed.iso,device=cdrom \
  --os-variant ubuntu22.04 \
  --graphics none \
  --network network=default \
  --import \
  --noautoconsole

echo "[OK] VM created."
