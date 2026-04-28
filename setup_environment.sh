#!/bin/bash
# setup_environment.sh
set -euo pipefail

echo "=== Setting up virtualization environment ==="

# Install virtualization stack
sudo dnf install -y \
    @virtualization \
    virt-install \
    libvirt \
    qemu-kvm \
    genisoimage \
    cloud-utils

echo "[INFO] Enabling all libvirt daemons..."

# Fedora uses split daemons — all must be enabled
sudo systemctl enable --now libvirtd

echo "[INFO] Ensuring user is in required groups..."

# Add user to libvirt + kvm groups
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

echo "=== Environment ready ==="
echo "You MUST log out and log back in for group changes to take effect."
