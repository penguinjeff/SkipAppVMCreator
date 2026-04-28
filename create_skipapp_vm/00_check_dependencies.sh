#!/bin/bash
# create_skipapp_vm/00_check_dependencies.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[INFO] Checking dependencies..."

# Required commands for the VM pipeline
REQUIRED_CMDS=(
    virsh
    virt-install
    genisoimage
    cloud-localds
    qemu-img
    curl
    ssh-keygen
)

# --- Check required commands ---
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Missing required command: $cmd"
        echo "Install it with: sudo dnf install -y $cmd"
        exit 1
    fi
done

# --- Check libvirt system connection ---
# This is the ONLY reliable check on Fedora 43+
if ! virsh --connect qemu:///system list >/dev/null 2>&1; then
    echo "[ERROR] Cannot connect to libvirt (qemu:///system)."
    echo "Are you in the libvirt and kvm groups?"
    echo "Check with: groups $USER"
    exit 1
fi

echo "[OK] Dependencies verified."
