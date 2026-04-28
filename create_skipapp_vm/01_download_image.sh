#!/bin/bash
# create_skipapp_vm/01_download_image.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

IMAGE_NAME="ubuntu-cloud.img"
TMP_IMAGE="${IMAGE_NAME}.tmp"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CHECKSUM_URL="https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"

echo "[INFO] Checking Ubuntu cloud image..."

# --- Remove obviously bad images ---
if [[ -f "$IMAGE_NAME" ]]; then
    SIZE=$(stat -c%s "$IMAGE_NAME")
    if (( SIZE < 200000000 )); then
        echo "[WARN] Existing image too small ($SIZE bytes) — deleting."
        rm -f "$IMAGE_NAME"
    fi
fi

# --- Download image if missing ---
if [[ ! -f "$IMAGE_NAME" ]]; then
    echo "[INFO] Downloading Ubuntu cloud image..."
    curl -L --fail --retry 5 --retry-delay 3 -o "$TMP_IMAGE" "$IMAGE_URL"

    # Ensure non-zero size
    if [[ ! -s "$TMP_IMAGE" ]]; then
        echo "[ERROR] Download failed — empty file."
        rm -f "$TMP_IMAGE"
        exit 1
    fi

    mv "$TMP_IMAGE" "$IMAGE_NAME"
fi

# --- Validate image format ---
if ! qemu-img info "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "[ERROR] Invalid or corrupted cloud image — redownloading."
    rm -f "$IMAGE_NAME"
    curl -L --fail --retry 5 --retry-delay 3 -o "$IMAGE_NAME" "$IMAGE_URL"
fi

# --- Verify checksum ---
echo "[INFO] Downloading SHA256 checksum list..."
curl -L --fail --retry 5 --retry-delay 3 -o SHA256SUMS "$CHECKSUM_URL"

echo "[INFO] Verifying SHA256 checksum..."
grep -E " \*jammy-server-cloudimg-amd64.img$" SHA256SUMS \
  | sed "s/jammy-server-cloudimg-amd64.img/$IMAGE_NAME/" \
  | sha256sum -c -

echo "[OK] Ubuntu cloud image verified: $IMAGE_NAME"



echo "[OK] Ubuntu cloud image verified: $IMAGE_NAME"
