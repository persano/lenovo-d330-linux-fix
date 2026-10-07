#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Pen & Touchpad Diagnostics Utility
# Inspects active stylus devices, pressure ranges, and barrel buttons

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-pen-config] $*"
}

echo "=== Lenovo D330 Touchpad & Active Pen Diagnostics ==="

if command -v libinput >/dev/null 2>&1; then
    echo "--- 1. libinput Devices ---"
    libinput list-devices 2>/dev/null | grep -E "(Device:|Kernel:|Capabilities:|Tap:)" || true
else
    echo "[INFO] libinput tool not found. Install libinput-tools."
fi

if command -v xsetwacom >/dev/null 2>&1; then
    echo ""
    echo "--- 2. Wacom / Tablet Devices ---"
    xsetwacom --list devices || true
fi

echo ""
echo "Diagnostics finished."
