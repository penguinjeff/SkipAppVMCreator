#!/bin/bash
set -euo pipefail

echo "[INFO] Building seed.iso..."

if [[ ! -f user-data || ! -f meta-data ]]; then
    echo "[ERROR] Missing user-data or meta-data."
    exit 1
fi

genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data >/dev/null

if [[ ! -f seed.iso ]]; then
    echo "[ERROR] Failed to create seed.iso"
    exit 1
fi

echo "[OK] seed.iso created."
