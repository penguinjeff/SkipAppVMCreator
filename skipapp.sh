#!/bin/bash
# skipapp.sh — Start SkipApp VM, wait for IP, update SkipApp, launch GUI, shut down VM

set -euo pipefail

VM_NAME="skipappvm"
SSH_KEY="$HOME/.ssh/skipapp_vm"
SSH_USER="ubuntu"

echo "Starting SkipApp VM..."

# --- Start VM if not running ---
state=$(virsh --connect qemu:///session domstate "$VM_NAME" 2>/dev/null || true)

if [[ "$state" == "running" ]]; then
    echo "VM already running."
else
    virsh --connect qemu:///session start "$VM_NAME"
    echo "VM started."
fi


# --- Wait for cloud-init to finish ---
echo "Waiting for cloud-init to finish inside VM..."

ATTEMPTS=0
MAX_ATTEMPTS=120

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    if ssh -p 2222 -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@localhost" \
        "test -f /var/lib/cloud/instance/boot-finished" 2>/dev/null; then
        echo "[OK] cloud-init finished."
        break
    fi

    echo "[INFO] cloud-init still running... ($ATTEMPTS/$MAX_ATTEMPTS)"
    ((ATTEMPTS++))
    sleep 2
done

if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "[WARN] cloud-init did not signal completion — continuing anyway."
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

virsh --connect qemu:///session shutdown "$VM_NAME" || true

for i in {1..20}; do
    state=$(virsh --connect qemu:///session domstate "$VM_NAME" 2>/dev/null || true)
    if [[ "$state" != "running" ]]; then
        echo "[OK] VM shut down."
        exit 0
    fi
    sleep 1
done

echo "[WARN] VM did not shut down — forcing power off..."
virsh --connect qemu:///session destroy "$VM_NAME" || true

echo "[OK] SkipApp session complete."
