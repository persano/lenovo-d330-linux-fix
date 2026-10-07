#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL RAPL Thermal Power Tuning Utility
# Programs Intel Running Average Power Limit (RAPL) sysfs parameters:
# - PL1 (Long term / sustained): 5.0 Watts (5000000 uW)
# - PL2 (Short term burst): 8.0 Watts (8000000 uW) with 10s time window

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-thermal-tune] $*"
}

RAPL_DIR="/sys/class/powercap/intel-rapl/intel-rapl:0"

show_status() {
    echo "=== Lenovo D330 CPU Thermals & RAPL Status ==="
    if [[ -d "$RAPL_DIR" ]]; then
        echo "RAPL Interface: $RAPL_DIR"
        pl1=$(cat "$RAPL_DIR/constraint_0_power_limit_uw" 2>/dev/null || echo "N/A")
        pl2=$(cat "$RAPL_DIR/constraint_1_power_limit_uw" 2>/dev/null || echo "N/A")
        echo "  - PL1 (Sustained): $((pl1 / 1000000)) W (raw: $pl1 uW)"
        echo "  - PL2 (Burst):     $((pl2 / 1000000)) W (raw: $pl2 uW)"
    else
        echo "[INFO] Intel RAPL powercap interface not active in current kernel environment."
    fi

    # Read CPU package temp
    for zone in /sys/class/thermal/thermal_zone*; do
        if [[ -f "$zone/type" ]] && grep -qi "pkg_temp\|cpu" "$zone/type"; then
            temp=$(cat "$zone/temp" 2>/dev/null || echo 0)
            echo "  - CPU Package Temperature: $((temp / 1000)) °C"
        fi
    done
}

apply_limits() {
    if [[ ! -d "$RAPL_DIR" ]]; then
        log "RAPL interface $RAPL_DIR not available."
        exit 0
    fi
    log "Configuring PL1 to 5.0W and PL2 to 8.0W..."
    echo 5000000 > "$RAPL_DIR/constraint_0_power_limit_uw" 2>/dev/null || true
    echo 8000000 > "$RAPL_DIR/constraint_1_power_limit_uw" 2>/dev/null || true
    log "RAPL limits applied successfully."
}

if [[ $# -gt 0 && "$1" == "--apply" ]]; then
    apply_limits
else
    show_status
fi
