#!/bin/bash
set -euo pipefail

VM_NAME="skipappvm"

echo "[INFO] Booting VM for cloud-init..."
virsh --connect qemu:///system start "$VM_NAME"

echo "[INFO] Waiting for VM to shut down after cloud-init..."
for i in {1..60}; do
    STATE=$(virsh --connect qemu:///system domstate "$VM_NAME")
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
virsh --connect qemu:///system start "$VM_NAME"

echo "[INFO] Waiting for guest agent..."
for i in {1..30}; do
    if virsh --connect qemu:///system qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1; then
        echo "[OK] Guest agent is running."
        exit 0
    fi
    sleep 1
done

echo "[ERROR] Guest agent did not start."
exit 1
