#!/usr/bin/env bash
# ==============================================================================
# test_battery_power.sh
# Diagnostic, thermal telemetry, and battery discharge verification harness
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}  $*"; }

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Diagnostic tool for Lenovo D330 battery consumption, thermal state, and Intel P-State EPP.

Options:
    --telemetry     Print instantaneous battery discharge rate, thermal readings, and frequencies
    --stress N      Run an N-second CPU load test and monitor thermal delta
    --tune          Execute power tuning script (lenovo-d330-power-tune.sh)
    --help          Show this message
EOF
}

TELEMETRY=1
STRESS_SEC=0
DO_TUNE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --telemetry) TELEMETRY=1; shift ;;
        --stress)
            if [[ -z "${2:-}" || "${2#--}" != "$2" ]]; then
                log_err "--stress requires a duration in seconds."
                show_help
                exit 1
            fi
            if ! echo "$2" | grep -qE '^[0-9]+$'; then
                log_err "--stress requires a non-negative integer (got: '$2')."
                show_help
                exit 1
            fi
            STRESS_SEC="$2"; shift 2 ;;
        --tune) DO_TUNE=1; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown argument: $1"; show_help; exit 1 ;;
    esac
done

log_info "=== Lenovo D330 Battery & Thermal Diagnostic Harness ==="

if [ $DO_TUNE -eq 1 ]; then
    log_info "Applying power tuning profile..."
    if [ -f "tools/lenovo-d330-power-tune.sh" ]; then
        bash tools/lenovo-d330-power-tune.sh
        log_ok "Power tuning applied."
    fi
fi

# 1. Thermal Telemetry
log_info "Reading thermal zones..."
for tz in /sys/class/thermal/thermal_zone*; do
    if [ -f "$tz/temp" ]; then
        TYPE="unknown"
        [ -f "$tz/type" ] && TYPE=$(cat "$tz/type")
        RAW_TEMP=$(cat "$tz/temp")
        TEMP_C=$(awk "BEGIN {printf \"%.1f\", $RAW_TEMP / 1000}")
        log_ok "Zone $(basename "$tz") ($TYPE): ${TEMP_C}°C"
    fi
done

# 2. CPU Frequencies and EPP
log_info "Checking CPU cores and Intel P-State policies..."
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    CPUNAME=$(basename "$cpu")
    FREQ="N/A"
    EPP="N/A"
    [ -f "$cpu/cpufreq/scaling_cur_freq" ] && FREQ="$(cat "$cpu/cpufreq/scaling_cur_freq") kHz"
    [ -f "$cpu/power/energy_perf_preference" ] && EPP="$(cat "$cpu/power/energy_perf_preference")"
    log_info "  $CPUNAME: Freq = $FREQ | EPP = $EPP"
done

# 3. Battery Telemetry
log_info "Reading Battery subsystem (/sys/class/power_supply/BAT*)..."
BAT_FOUND=0
for bat in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
    if [ -d "$bat" ]; then
        BAT_FOUND=1
        STATUS=$(cat "$bat/status" 2>/dev/null || echo "Unknown")
        CAPACITY=$(cat "$bat/capacity" 2>/dev/null || echo "0")
        
        # Power / Voltage calculation
        VOLTAGE_UV=$(cat "$bat/voltage_now" 2>/dev/null || echo "0")
        CURRENT_UA=$(cat "$bat/current_now" 2>/dev/null || echo "0")
        POWER_UW=$(cat "$bat/power_now" 2>/dev/null || echo "0")

        if [ "$POWER_UW" -eq 0 ] && [ "$VOLTAGE_UV" -gt 0 ] && [ "$CURRENT_UA" -gt 0 ]; then
            POWER_UW=$(awk "BEGIN {print $VOLTAGE_UV * $CURRENT_UA / 1000000}")
        fi

        POWER_W=$(awk "BEGIN {printf \"%.2f\", $POWER_UW / 1000000}")
        VOLTAGE_V=$(awk "BEGIN {printf \"%.2f\", $VOLTAGE_UV / 1000000}")

        log_ok "Battery $(basename "$bat"): Status = $STATUS | Charge = ${CAPACITY}%"
        log_ok "Voltage: ${VOLTAGE_V}V | Discharge Rate: ${POWER_W}W"
        
        if [ "$STATUS" = "Discharging" ] && [ "$POWER_UW" -gt 0 ]; then
            ENERGY_NOW=$(cat "$bat/energy_now" 2>/dev/null || echo "0")
            if [ "$ENERGY_NOW" -gt 0 ]; then
                HOURS=$(awk "BEGIN {printf \"%.1f\", $ENERGY_NOW / $POWER_UW}")
                log_info "Estimated remaining runtime: ~${HOURS} hours"
            fi
        fi
    fi
done

if [ $BAT_FOUND -eq 0 ]; then
    log_warn "No physical battery detected (running on AC-only test bench or VM)"
fi

# 4. Stress load test if requested
if [ "$STRESS_SEC" -gt 0 ]; then
    log_info "Running $STRESS_SEC-second thermal stress test on all available cores..."
    PIDS=()
    for i in $(seq 1 "$(nproc)"); do
        ( yes > /dev/null ) &
        PIDS+=($!)
    done

    sleep "$STRESS_SEC"

    for pid in "${PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true

    log_ok "Stress test completed. Sampling post-stress temperatures..."
    for tz in /sys/class/thermal/thermal_zone*; do
        if [ -f "$tz/temp" ]; then
            TYPE="unknown"
            [ -f "$tz/type" ] && TYPE=$(cat "$tz/type")
            RAW_TEMP=$(cat "$tz/temp")
            TEMP_C=$(awk "BEGIN {printf \"%.1f\", $RAW_TEMP / 1000}")
            log_info "Zone $(basename "$tz") ($TYPE): ${TEMP_C}°C"
        fi
    done
fi

log_ok "Power and thermal diagnostic completed successfully."
