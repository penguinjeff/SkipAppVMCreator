#!/bin/bash
set -euo pipefail

PUB_KEY="$HOME/.ssh/rsa-skipapp.pub"

if [[ ! -f "$PUB_KEY" ]]; then
    echo "[ERROR] SSH public key missing: $PUB_KEY"
    exit 1
fi

echo "[INFO] Generating cloud-init config..."

cat > user-data <<EOF
#cloud-config
hostname: skipappvm
manage_etc_hosts: true

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent

runcmd:
  - systemctl enable --now qemu-guest-agent

power_state:
  mode: poweroff
  timeout: 30
  condition: true

ssh_authorized_keys:
  - $(cat "$PUB_KEY")

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
