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
if virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo "[WARN] Existing VM found — destroying..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --nvram || true
fi

# Remove old working disk if present
rm -f "$BUILD_DIR/ubuntu-cloud-copy.img"

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

echo "[INFO] Creating working copy of cloud image..."
cp ubuntu-cloud.img ubuntu-cloud-copy.img

echo "[INFO] Creating VM..."

virt-install \
  --name "$VM_NAME" \
  --ram 2048 \
  --vcpus 2 \
  --boot hd \
  --disk path="$BUILD_DIR/ubuntu-cloud-copy.img",format=qcow2 \
  --disk path="$BUILD_DIR/seed.iso",device=cdrom \
  --os-variant ubuntu22.04 \
  --network user \
  --noautoconsole \
  --import

echo "[OK] VM created."
