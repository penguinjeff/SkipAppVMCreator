#!/bin/bash
# create_skipapp_vm/06_boot_once.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

VM_NAME="skipappvm"

echo "[INFO] Booting VM for cloud-init..."
virsh  start "$VM_NAME"

echo "[INFO] Waiting for VM to shut down after cloud-init..."
STATE=""
for i in {1..90}; do
    STATE=$(virsh  domstate "$VM_NAME" 2>/dev/null || echo "unknown")
    if [[ "$STATE" == "shut off" ]]; then
        echo "[OK] VM shut down after cloud-init."
        break
    fi
    sleep 2
done

if [[ "$STATE" != "shut off" ]]; then
    echo "[ERROR] VM did not shut down — cloud-init likely failed."
    exit 1
fi

echo "[INFO] Starting VM again..."
virsh  start "$VM_NAME"

echo "[INFO] Waiting for guest agent to respond..."
for i in {1..60}; do
    if virsh  qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1; then
        echo "[OK] Guest agent is running."
        exit 0
    fi
    sleep 1
done

echo "[ERROR] Guest agent did not start."
exit 1
