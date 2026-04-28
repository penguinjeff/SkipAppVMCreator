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
sudo systemctl enable --now virtqemud
sudo systemctl enable --now virtlogd
sudo systemctl enable --now virtnetworkd
sudo systemctl enable --now virtstoraged

echo "[INFO] Ensuring user is in required groups..."

# Add user to libvirt + kvm groups
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

echo "[INFO] Fixing libvirt socket permissions..."

# Allow unprivileged access to libvirt system socket (may not exist on split-daemon Fedora)
sudo chmod 666 /var/run/libvirt/libvirt-sock 2>/dev/null || true

echo "[INFO] Removing all session-mode libvirt networks..."

# Session-mode networks cannot function (no bridges, no NAT, no dnsmasq)
# So we delete ANY that exist to prevent PCI collisions and NIC injection
for NET in $(virsh --connect qemu:///session net-list --all --name); do
    echo "  - Removing session network: $NET"
    virsh --connect qemu:///session net-destroy "$NET" 2>/dev/null || true
    virsh --connect qemu:///session net-undefine "$NET" 2>/dev/null || true
done

echo "=== Environment ready ==="
echo "[INFO] Session mode: networking will be handled entirely by QEMU user-mode networking."
echo "You MUST log out and log back in for group changes to take effect."
echo "After that, test with:"
echo "  virsh --connect qemu:///session list"
