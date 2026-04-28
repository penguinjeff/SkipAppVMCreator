#!/bin/bash
# create_skipapp_vm/04_build_seed_iso.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"
ISO_PATH="$BUILD_DIR/seed.iso"
USER_DATA="$BUILD_DIR/user-data"
META_DATA="$BUILD_DIR/meta-data"

mkdir -p "$BUILD_DIR"

echo "[INFO] Building seed.iso..."

# --- Ensure VM is not running ---
if virsh  domstate skipappvm 2>/dev/null | grep -q running; then
    echo "[WARN] VM 'skipappvm' is running — attempting graceful shutdown..."
    virsh  shutdown skipappvm || true

    # Wait up to 20 seconds for clean shutdown
    for i in {1..20}; do
        state=$(virsh  domstate skipappvm 2>/dev/null || true)
        if [[ "$state" != "running" ]]; then
            echo "[INFO] VM shut down cleanly."
            break
        fi
        sleep 1
    done

    # If still running → force stop
    if virsh  domstate skipappvm 2>/dev/null | grep -q running; then
        echo "[WARN] VM did not shut down — forcing power off..."
        virsh  destroy skipappvm || true
    fi
fi

# --- Validate cloud-init files exist ---
if [[ ! -f "$USER_DATA" ]]; then
    echo "[ERROR] Missing user-data at $USER_DATA"
    exit 1
fi

if [[ ! -f "$META_DATA" ]]; then
    echo "[ERROR] Missing meta-data at $META_DATA"
    exit 1
fi

# --- Build seed.iso ---
echo "[INFO] Creating seed.iso..."
genisoimage -output "$ISO_PATH" \
    -volid cidata \
    -joliet -rock \
    "$USER_DATA" "$META_DATA"

echo "[OK] seed.iso rebuilt at: $ISO_PATH"
