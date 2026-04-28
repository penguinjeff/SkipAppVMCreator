#!/bin/bash
# create_skipapp_vm/02_generate_ssh_key.sh

set -euo pipefail

KEY="$HOME/.ssh/rsa-skipapp"
PUB="$KEY.pub"

echo "[INFO] Checking SSH key..."

# Ensure ~/.ssh exists with correct permissions
if [[ ! -d "$HOME/.ssh" ]]; then
    echo "[INFO] Creating ~/.ssh directory..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
fi

# If both key files exist, validate them
if [[ -f "$KEY" && -f "$PUB" ]]; then
    if ssh-keygen -l -f "$PUB" >/dev/null 2>&1; then
        echo "[OK] Valid SSH key already exists: $PUB"
        exit 0
    else
        echo "[WARN] Existing SSH key is invalid — regenerating."
        rm -f "$KEY" "$PUB"
    fi
fi

# If only one exists, delete both to avoid mismatches
if [[ -f "$KEY" || -f "$PUB" ]]; then
    echo "[WARN] Incomplete SSH keypair detected — regenerating."
    rm -f "$KEY" "$PUB"
fi

echo "[INFO] Generating SSH key..."
ssh-keygen -t rsa -b 4096 -N "" -f "$KEY"

chmod 600 "$KEY"
chmod 644 "$PUB"

echo "[OK] SSH key generated: $PUB"
