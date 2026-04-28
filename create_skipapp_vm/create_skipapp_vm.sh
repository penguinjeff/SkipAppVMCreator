#!/bin/bash
# create_skipapp_vm/create_skipapp_vm.sh

set -euo pipefail

# --- Resolve directories ---
ROOT_DIR="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$ROOT_DIR/create_skipapp_vm"
BUILD_DIR="$ROOT_DIR/build"
LOG_DIR="$BUILD_DIR/logs"
LOGFILE="$LOG_DIR/pipeline.log"

mkdir -p "$BUILD_DIR" "$LOG_DIR"

cleanup() {
    echo "[FATAL] Pipeline aborted. Check $LOGFILE for details."
}
trap cleanup ERR

echo "=== SkipApp VM Creation Pipeline ===" | tee "$LOGFILE"

run_step() {
    local script="$1"
    echo "[RUN] $script" | tee -a "$LOGFILE"
    "$SCRIPT_DIR/$script" 2>&1 | tee -a "$LOGFILE"
    echo "[OK] $script completed" | tee -a "$LOGFILE"
}

run_step 00_check_dependencies.sh
run_step 01_download_image.sh
run_step 02_generate_ssh_key.sh
run_step 03_create_cloud_init.sh
run_step 04_build_seed_iso.sh
run_step 05_create_vm.sh
run_step 06_boot_once.sh

echo "=== SkipApp VM setup complete ===" | tee -a "$LOGFILE"
