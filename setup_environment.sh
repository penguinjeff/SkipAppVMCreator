#!/bin/bash
set -euo pipefail

echo "=== Installing virtualization packages ==="
sudo dnf install -y virt-manager qemu-kvm libvirt virt-install genisoimage cloud-init

echo "=== Enabling libvirtd ==="
sudo systemctl enable --now libvirtd

echo "=== Ensuring default libvirt network exists ==="
if ! sudo virsh net-info default >/dev/null 2>&1; then
    echo "Recreating libvirt default network..."
    sudo virsh net-define /usr/share/libvirt/networks/default.xml
    sudo virsh net-start default
    sudo virsh net-autostart default
elif [[ "$(sudo virsh net-info default | awk '/Active/ {print $2}')" != "yes" ]]; then
    echo "Starting libvirt default network..."
    sudo virsh net-start default
    sudo virsh net-autostart default
fi

echo "=== Adding $USER to virtualization groups ==="
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"
sudo usermod -aG qemu "$USER" 2>/dev/null || true

echo "=== Fixing libvirt socket permissions ==="
sudo chmod 666 /var/run/libvirt/libvirt-sock

echo "=== Restarting libvirtd ==="
sudo systemctl restart libvirtd

echo "=== Setup complete ==="
echo "You MUST log out and log back in for group changes to take effect."
