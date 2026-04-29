#!/bin/bash
# create_skipapp_vm/03_create_cloud_init.sh

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

PUB_KEY="$HOME/.ssh/rsa-skipapp.pub"

if [[ ! -f "$PUB_KEY" ]]; then
    echo "[ERROR] SSH public key missing: $PUB_KEY"
    exit 1
fi

USERNAME="$USER"

echo "[INFO] Generating cloud-init config..."

cat > user-data <<EOF
#cloud-config
hostname: skipappvm
manage_etc_hosts: true

network:
  version: 2
  ethernets:
    ens3:
      dhcp4: true

users:
  - name: "$USERNAME"
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - "$(cat "$PUB_KEY")"
    lock_passwd: false

chpasswd:
  expire: false
  list:
    - "$USERNAME:Password@123"

runcmd:
  - apt-get update
  - apt-get install -y --fix-broken
  - apt-get install -y qemu-guest-agent
  - systemctl enable --now qemu-guest-agent

power_state:
  mode: poweroff
  timeout: 30
  condition: true

final_message: "SkipApp VM is ready."
EOF

cat > meta-data <<EOF
instance-id: skipappvm
local-hostname: skipappvm
EOF

echo "[INFO] Validating cloud-init YAML syntax..."
python3 - <<'EOF'
import sys, yaml
try:
    yaml.safe_load(open("user-data"))
except Exception as e:
    print("[ERROR] Invalid YAML in user-data:", e)
    sys.exit(1)
EOF

echo "[OK] YAML syntax valid."
echo "[OK] Cloud-init configuration generated."
