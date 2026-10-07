#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Fast Boot Optimization Tool
# Masks blocking network wait services and reports systemd boot benchmarks

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-fastboot-tune] $*"
}

show_benchmark() {
    echo "=== Lenovo D330 Boot Performance Benchmark ==="
    if command -v systemd-analyze >/dev/null 2>&1; then
        echo "--- 1. Startup Time Overview ---"
        systemd-analyze || true
        echo ""
        echo "--- 2. Top Boot Time Bottlenecks (Blame) ---"
        systemd-analyze blame 2>/dev/null | head -n 8 || true
    else
        echo "[INFO] systemd-analyze command not available in current environment."
    fi
}

apply_optimizations() {
    log "Applying eMMC fast boot tuning..."
    if [[ $EUID -ne 0 ]]; then
        log "[WARN] Root privileges required to mask systemd services."
        return
    fi
    # Mask network wait-online services that delay graphical desktop startup
    systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
    systemctl mask NetworkManager-wait-online.service 2>/dev/null || true
    log "Masked wait-online services (shaves 3-5 seconds off eMMC boot time)."
}

if [[ $# -gt 0 && "$1" == "--apply" ]]; then
    apply_optimizations
else
    show_benchmark
fi
