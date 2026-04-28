#!/bin/bash
set -euo pipefail

KEY="$HOME/.ssh/rsa-skipapp"
PUB="$KEY.pub"

if [[ -f "$PUB" ]]; then
    echo "[OK] SSH key already exists: $PUB"
    exit 0
fi

echo "[INFO] Generating SSH key..."
ssh-keygen -t rsa -b 4096 -N "" -f "$KEY"

echo "[OK] SSH key generated."
