#!/bin/bash
# create_skipapp_vm/03_create_cloud_init.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

PUB_KEY="$HOME/.ssh/rsa-skipapp.pub"

if [[ ! -f "$PUB_KEY" ]]; then
    echo "[ERROR] SSH public key missing: $PUB_KEY"
    echo "Run 02_generate_ssh_key.sh first."
    exit 1
fi

echo "[INFO] Generating cloud-init config..."

cat > user-data <<EOF
#cloud-config
hostname: skipappvm
manage_etc_hosts: true

# --- Ensure networking is up BEFORE package install ---
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: true

users:
  - name: "$USER"
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - "$(cat "$PUB_KEY")"
    lock_passwd: false

chpasswd:
  expire: false
  list:
    - "$USER:Password@123"

# --- Install SkipApp updater/runner script ---
write_files:
  - path: /home/$USER/update-and-run-skipapp.sh
    owner: $USER:$USER
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail

      APPDIR="\$HOME/skipapp"
      mkdir -p "\$APPDIR"
      cd "\$APPDIR"

      echo "[INFO] Checking for latest SkipApp..."
      LATEST_URL=\$(curl -s https://flirc.tv/downloads/skipapp/linux | \
                     grep -oP 'https://[^"]+SkipApp[^"]+AppImage' | head -n1)

      if [[ -z "\$LATEST_URL" ]]; then
          echo "[ERROR] Could not find SkipApp download URL"
          exit 1
      fi

      echo "[INFO] Downloading SkipApp..."
      curl -L "\$LATEST_URL" -o SkipApp.AppImage
      chmod +x SkipApp.AppImage

      echo "[INFO] Running SkipApp..."
      ./SkipApp.AppImage

      echo "[INFO] SkipApp exited, shutting down VM..."
      sudo shutdown -h now

# --- Install guest agent reliably ---
runcmd:
  - apt-get update
  - apt-get install -y --fix-broken
  - apt-get install -y qemu-guest-agent
  - systemctl enable --now qemu-guest-agent
  - chown $USER:$USER /home/$USER/update-and-run-skipapp.sh
  - chmod +x /home/$USER/update-and-run-skipapp.sh

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
