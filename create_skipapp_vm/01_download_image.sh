#!/bin/bash
set -euo pipefail

IMAGE_NAME="ubuntu-cloud.img"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

echo "[INFO] Checking Ubuntu cloud image..."

if [[ -f "$IMAGE_NAME" ]]; then
    SIZE=$(stat -c%s "$IMAGE_NAME")
    if (( SIZE < 100000000 )); then
        echo "[WARN] Existing image too small — deleting."
        rm -f "$IMAGE_NAME"
    fi
fi

if [[ ! -f "$IMAGE_NAME" ]]; then
    echo "[INFO] Downloading Ubuntu cloud image..."
    curl -L --fail --retry 5 --retry-delay 3 -o "$IMAGE_NAME" "$IMAGE_URL"
fi

echo "[OK] Ubuntu cloud image verified: $IMAGE_NAME"
