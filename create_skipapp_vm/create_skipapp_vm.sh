#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== SkipApp VM Creation Pipeline ==="

./00_check_dependencies.sh
./01_download_image.sh
./02_generate_ssh_key.sh
./03_create_cloud_init.sh
./04_build_seed_iso.sh
./05_create_vm.sh
./06_boot_once.sh

echo "=== SkipApp VM setup complete ==="
