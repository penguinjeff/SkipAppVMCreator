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

echo "[INFO] Creating VM XML (not defining yet)..."

virt-install \
  --name "$VM_NAME" \
  --ram 2048 \
  --vcpus 2 \
  --machine pc \
  --boot hd \
  --disk path="$BUILD_DIR/ubuntu-cloud-copy.img",format=raw \
  --disk path="$BUILD_DIR/seed.iso",device=cdrom,bus=sata \
  --os-variant ubuntu22.04 \
  --network network=default \
  --graphics none \
  --import \
  --print-xml > "$BUILD_DIR/$VM_NAME.xml"

echo "[INFO] Adding SSH port forwarding to VM XML..."

awk '
  /<interface type=.user./ { in_iface=1 }
  in_iface && /<\/interface>/ {
    print "      <protocol type=\"tcp\">"
    print "        <host port=\"2222\"/>"
    print "        <guest port=\"22\"/>"
    print "      </protocol>"
    in_iface=0
  }
  { print }
' "$BUILD_DIR/$VM_NAME.xml" > "$BUILD_DIR/$VM_NAME.xml.tmp"

mv "$BUILD_DIR/$VM_NAME.xml.tmp" "$BUILD_DIR/$VM_NAME.xml"

echo "[INFO] Defining VM with patched XML..."
virsh define "$BUILD_DIR/$VM_NAME.xml"

echo "[OK] VM created with SSH port forwarding enabled."
