#!/bin/bash
set -euo pipefail

APPDIR="$HOME/skipapp"
mkdir -p "$APPDIR"
cd "$APPDIR"

echo "[INFO] Checking for latest SkipApp..."
LATEST_URL=$(curl -s https://flirc.tv/downloads/skipapp/linux | \
             grep -oP 'https://[^"]+SkipApp[^"]+AppImage' | head -n1)

if [[ -z "$LATEST_URL" ]]; then
    echo "[ERROR] Could not find SkipApp download URL"
    exit 1
fi

echo "[INFO] Downloading SkipApp..."
curl -L "$LATEST_URL" -o SkipApp.AppImage
chmod +x SkipApp.AppImage

echo "[INFO] Running SkipApp..."
./SkipApp.AppImage

echo "[INFO] SkipApp exited, shutting down VM..."
sudo shutdown -h now
