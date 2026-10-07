#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL VA-API Video Acceleration Diagnostics
# Tests Intel iHD driver, hardware codecs (H.264, VP9, HEVC), and browser support

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-vaapi-check] $*"
}

echo "=== Lenovo D330 Hardware Video Acceleration Status ==="

export LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-iHD}"

if command -v vainfo >/dev/null 2>&1; then
    echo "--- 1. VA-API Driver & Profile Query ---"
    vainfo 2>&1 | grep -E "(VAProfileH264|VAProfileVP9|VAProfileHEVC|va_openDriver)" || true
else
    echo "[INFO] vainfo not installed. Install vainfo or libva-utils."
fi

echo ""
echo "--- 2. Intel GPU Driver in Use ---"
if [[ -d /sys/class/drm/card0 ]]; then
    driver=$(readlink /sys/class/drm/card0/device/driver 2>/dev/null || echo "unknown")
    echo "  GPU Kernel Driver: $(basename "$driver")"
fi

echo ""
echo "--- 3. Recommended Browser Launch Flags ---"
echo "  Chromium / Chrome: --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks --use-gl=angle --use-angle=gl"
echo "  Firefox:           MOZ_DISABLE_RDD_SANDBOX=1 MOZ_ENABLE_WAYLAND=1 firefox"
