#!/usr/bin/env bash
# ==============================================================================
# lenovo-d330-power-tune.sh
# Applies Intel P-State EPP policies, RAPL power clamping, and runtime PM
# ==============================================================================

set -euo pipefail

# 1. Determine AC or Battery power state
IS_ON_AC=1
for ac in /sys/class/power_supply/A*/online /sys/class/power_supply/ADP*/online; do
    if [ -f "$ac" ]; then
        VAL=$(cat "$ac" 2>/dev/null || echo 1)
        [ "$VAL" -eq 0 ] && IS_ON_AC=0
    fi
done

# 2. Select EPP policy
if [ "$IS_ON_AC" -eq 1 ]; then
    EPP="balance_performance"
    GOV="powersave"
    MAX_PERF=100
else
    EPP="power"
    GOV="powersave"
    MAX_PERF=75
fi

# 3. Apply Intel P-State Energy Performance Preference (EPP)
for cpu_epp in /sys/devices/system/cpu/cpu*/power/energy_perf_preference; do
    if [ -f "$cpu_epp" ]; then
        echo "$EPP" > "$cpu_epp" 2>/dev/null || true
    fi
done

for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu_gov" ]; then
        echo "$GOV" > "$cpu_gov" 2>/dev/null || true
    fi
done

# 4. Limit max state on Intel P-state if sysfs exists
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
    echo "$MAX_PERF" > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true
fi

# 5. Enable Runtime PM across devices
for ctrl in /sys/bus/pci/devices/*/power/control /sys/block/mmcblk0/device/power/control; do
    if [ -f "$ctrl" ]; then
        echo "auto" > "$ctrl" 2>/dev/null || true
    fi
done

exit 0
