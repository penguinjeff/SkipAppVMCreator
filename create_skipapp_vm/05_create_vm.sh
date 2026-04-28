#!/bin/bash
# create_skipapp_vm/05_create_vm.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

VM_NAME="skipappvm"

echo "[INFO] Checking for existing VM..."

# If VM exists, destroy + undefine it cleanly
if virsh --connect qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo "[WARN] Existing VM found — destroying..."
    virsh --connect qemu:///system destroy "$VM_NAME" 2>/dev/null || true
    virsh --connect qemu:///system undefine "$VM_NAME" --nvram || true
fi

# Validate required files
if [[ ! -f ubuntu-cloud.img ]]; then
    echo "[ERROR] ubuntu-cloud.img missing in $BUILD_DIR."
    echo "Run 01_download_image.sh first."
    exit 1
fi

if [[ ! -f seed.iso ]]; then
    echo "[ERROR] seed.iso missing in $BUILD_DIR."
    echo "Run 04_build_seed_iso.sh first."
    exit 1
fi

echo "[INFO] Creating VM..."

virt-install --connect qemu:///system \
  --name "$VM_NAME" \
  --ram 2048 \
  --vcpus 2 \
  --disk path="$BUILD_DIR/ubuntu-cloud.img",format=qcow2 \
  --disk path="$BUILD_DIR/seed.iso",device=cdrom \
  --os-variant ubuntu22.04 \
  --graphics none \
  --network network=default \
  --import \
  --noautoconsole

echo "[OK] VM created."
