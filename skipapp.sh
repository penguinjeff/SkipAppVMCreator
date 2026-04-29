#!/bin/bash
# skipapp.sh — Start SkipApp VM, attach USB, copy script, run SkipApp, shut down VM

set -euo pipefail

VM_NAME="skipappvm"
SSH_KEY="$HOME/.ssh/rsa-skipapp"
SSH_USER="$USER"
ROOT_DIR="$(git rev-parse --show-toplevel)"

echo "Starting SkipApp VM..."

# --- Start VM if not running ---
state=$(virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null || true)

if [[ "$state" == "running" ]]; then
    echo "VM already running."
else
    virsh --connect qemu:///system start "$VM_NAME"
    echo "VM started."
fi

# --- Wait for guest agent ---
echo "[INFO] Waiting for guest agent to become ready..."

ATTEMPTS=0
MAX_ATTEMPTS=60

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    if virsh --connect qemu:///system qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1; then
        echo "[OK] Guest agent is ready."
        break
    fi

    echo "[INFO] Guest agent not ready yet... ($ATTEMPTS/$MAX_ATTEMPTS)"
    ((ATTEMPTS++))
    sleep 2
done

if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "[ERROR] Guest agent did not become ready."
    exit 1
fi

# --- Get VM IP via guest agent ---
VM_IP=$(virsh domifaddr "$VM_NAME" | awk '/ipv4/ {print $4}' | cut -d/ -f1)

if [[ -z "$VM_IP" ]]; then
    echo "[ERROR] Could not determine VM IP."
    exit 1
fi

echo "[OK] VM IP is $VM_IP"

# --- Detect USB device on host ---
echo "[INFO] Detecting Skip 1s USB device on host..."

USB_INFO=$(lsusb | grep -i "Clay\|Skip" | head -n 1 || true)

if [[ -z "$USB_INFO" ]]; then
    echo "[ERROR] Skip 1s USB device not found. Plug it in and try again."
    exit 1
fi

VENDOR=$(echo "$USB_INFO" | awk '{print $6}' | cut -d: -f1)
PRODUCT=$(echo "$USB_INFO" | awk '{print $6}' | cut -d: -f2)

echo "[OK] Found USB device: vendor=$VENDOR product=$PRODUCT"

# --- Attach USB device to VM ---
echo "[INFO] Attaching USB device to VM (if not already attached)..."

XML=$(virsh --connect qemu:///system dumpxml "$VM_NAME")
if echo "$XML" | grep -qi "<vendor id='0x$VENDOR'/>"; then
    echo "[INFO] USB device already attached to VM. Skipping attach."
else
    virsh --connect qemu:///system attach-device "$VM_NAME" --live --config /dev/stdin <<EOF
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x$VENDOR'/>
    <product id='0x$PRODUCT'/>
  </source>
</hostdev>
EOF
    echo "[OK] USB device attached to VM."
fi

# --- Wait for USB device inside VM ---
echo "[INFO] Waiting for USB device to appear inside VM..."

ATTEMPTS=0
MAX_ATTEMPTS=60

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do

    EXEC_OUT=$(virsh --connect qemu:///system qemu-agent-command "$VM_NAME" \
        '{"execute":"guest-exec","arguments":{"path":"/usr/bin/lsusb","capture-output":true}}' \
        2>/dev/null || true)

    PID=$(echo "$EXEC_OUT" | grep -o '"pid":[0-9]*' | cut -d: -f2)

    STATUS=$(virsh --connect qemu:///system qemu-agent-command "$VM_NAME" \
        "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$PID}}" \
        2>/dev/null || true)

    STDOUT=$(echo "$STATUS" | grep -o '"out-data":"[^"]*"' | sed 's/"out-data":"//' | sed 's/"$//' | base64 --decode 2>/dev/null || true)

    if echo "$STDOUT" | grep -qi "$VENDOR:$PRODUCT"; then
        echo "[OK] USB device detected inside VM."
        break
    fi

    echo "[INFO] USB not detected yet... ($ATTEMPTS/$MAX_ATTEMPTS)"
    ((ATTEMPTS++))
    sleep 2
done

if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "[ERROR] USB device did not appear inside VM."
    exit 1
fi

# --- Copy SkipApp runner script into VM ---
echo "[INFO] Copying SkipApp runner script into VM..."

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "$SSH_KEY" \
    "$ROOT_DIR/update-and-run-skipapp.sh" \
    "$SSH_USER@$VM_IP:/home/$SSH_USER/update-and-run-skipapp.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "$SSH_KEY" \
    "$SSH_USER@$VM_IP" "chmod +x ~/update-and-run-skipapp.sh"

echo "[OK] Script copied."

# --- Run SkipApp inside VM ---
echo "[INFO] Running SkipApp inside VM..."

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "$SSH_KEY" \
    "$SSH_USER@$VM_IP" "~/update-and-run-skipapp.sh"

echo "[INFO] SkipApp finished. VM should shut down automatically."
