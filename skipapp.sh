#!/bin/bash
# skipapp.sh — Start SkipApp VM, attach USB, update SkipApp, launch GUI, shut down VM

set -euo pipefail

VM_NAME="skipappvm"
SSH_KEY="$HOME/.ssh/rsa-skipapp"
SSH_USER="$USER"

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

# Check if device is already attached
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

echo "[OK] USB device attached to VM."

# --- Wait for USB device inside VM ---
echo "[INFO] Waiting for USB device to appear inside VM..."

ATTEMPTS=0
MAX_ATTEMPTS=60

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do

    # Step 1: run lsusb inside VM
    EXEC_OUT=$(virsh --connect qemu:///system qemu-agent-command "$VM_NAME" \
        '{"execute":"guest-exec","arguments":{"path":"/usr/bin/lsusb","capture-output":true}}' \
        2>/dev/null || true)

    PID=$(echo "$EXEC_OUT" | grep -o '"pid":[0-9]*' | cut -d: -f2)

    # Step 2: fetch output
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

# --- Update SkipApp inside VM ---
echo "Updating SkipApp inside VM..."

ssh -p 2222 -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@localhost" <<'EOF'
set -euo pipefail

cd /home/ubuntu

echo "[INFO] Downloading latest SkipApp..."
wget -q https://flirc.tv/downloads/SkipApp.AppImage -O SkipApp.AppImage
chmod +x SkipApp.AppImage

echo "[INFO] SkipApp updated."
EOF

echo "[OK] SkipApp updated."

# --- Launch SkipApp GUI inside VM ---
echo "Launching SkipApp GUI..."

ssh -p 2222 -o StrictHostKeyChecking=no -i "$SSH_KEY" -X "$SSH_USER@localhost" \
    "/home/ubuntu/SkipApp.AppImage >/dev/null 2>&1 &"

echo "[OK] SkipApp launched."

# --- Shut down VM after exit ---
echo "Shutting down VM..."

virsh --connect qemu:///system shutdown "$VM_NAME" || true

for i in {1..20}; do
    state=$(virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null || true)
    if [[ "$state" != "running" ]]; then
        echo "[OK] VM shut down."
        exit 0
    fi
    sleep 1
done

echo "[WARN] VM did not shut down — forcing power off..."
virsh --connect qemu:///system destroy "$VM_NAME" || true

echo "[OK] SkipApp session complete."
