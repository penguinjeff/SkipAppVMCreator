#!/bin/bash
# skipapp.sh
set -euo pipefail

VM_NAME="skipappvm"
SSH_KEY="$HOME/.ssh/rsa-skipapp"

echo "Starting SkipApp VM..."

# --- Pre-flight checks -------------------------------------------------------

# Check SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: SSH key missing: $SSH_KEY"
    echo "Run: create_skipapp_vm/02_generate_ssh_key.sh"
    exit 1
fi

# Check VM exists
if ! virsh --connect qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM '$VM_NAME' does not exist."
    echo "You must build it first:"
    echo "  ./create_skipapp_vm/create_skipapp_vm.sh"
    exit 1
fi

# --- Start VM if needed ------------------------------------------------------

if virsh --connect qemu:///system domstate "$VM_NAME" | grep -q running; then
    echo "VM already running."
else
    virsh --connect qemu:///system start "$VM_NAME" >/dev/null
fi

# --- Wait for IP via QEMU guest agent ----------------------------------------

echo "Waiting for VM to acquire an IP address via QEMU guest agent..."
VM_IP=""
ATTEMPTS=0
MAX_ATTEMPTS=60   # 2 minutes

while [[ -z "$VM_IP" && $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    VM_IP=$(virsh --connect qemu:///system domifaddr "$VM_NAME" --source agent 2>/dev/null \
        | awk '/ipv4/ {print $4}' | cut -d/ -f1)

    if [[ -z "$VM_IP" ]]; then
        ((ATTEMPTS++))
        sleep 2
    fi
done

if [[ -z "$VM_IP" ]]; then
    echo "ERROR: VM did not report an IP address."
    echo "Guest agent may not be installed or VM was not built correctly."
    echo "Rebuild with:"
    echo "  ./create_skipapp_vm/create_skipapp_vm.sh"
    exit 1
fi

echo "VM is up at $VM_IP"

# --- Wait for SSH ------------------------------------------------------------

echo "Waiting for SSH to become available..."
for i in {1..30}; do
    if ssh -i "$SSH_KEY" -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$USER@$VM_IP" "echo ok" 2>/dev/null; then
        break
    fi
    sleep 1
done

# --- Update SkipApp ----------------------------------------------------------

echo "Updating SkipApp inside VM..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$VM_IP" \
    "sudo /usr/local/bin/update-skipapp"

echo "SkipApp updated. Launching SkipApp..."

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$VM_IP" \
    "DISPLAY=:0 /opt/SkipApp.AppImage"

echo "SkipApp closed. Shutting down VM..."

virsh --connect qemu:///system shutdown "$VM_NAME" || true

echo "VM shutdown complete."
