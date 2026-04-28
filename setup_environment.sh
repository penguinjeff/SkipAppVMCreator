#!/bin/bash
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
sudo systemctl enable --now virtqemud
sudo systemctl enable --now virtlogd
sudo systemctl enable --now virtnetworkd
sudo systemctl enable --now virtstoraged

echo "[INFO] Ensuring user is in required groups..."

# Add user to libvirt + kvm groups
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

echo "[INFO] Fixing libvirt socket permissions..."

# Allow unprivileged access to libvirt system socket
sudo chmod 666 /var/run/libvirt/libvirt-sock || true

echo "[INFO] Ensuring default network exists..."

# Check if default network exists
if ! sudo virsh net-info default >/dev/null 2>&1; then
    echo "[WARN] Default network missing — creating it..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml
fi

echo "[INFO] Enabling and starting default network..."

sudo virsh net-autostart default
sudo virsh net-start default 2>/dev/null || true

echo "=== Environment ready ==="
echo "You MUST log out and log back in for group changes to take effect."
echo "After that, test with:"
echo "  virsh --connect qemu:///system list"
