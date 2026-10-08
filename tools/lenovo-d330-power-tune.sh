#!/usr/bin/env bash
# ==============================================================================
# lenovo-d330-power-tune.sh
#
# Applies Intel P-State EPP policy and the AC-aware CPU performance cap.
#
# Ownership (Phase 40): TLP is the single runtime-PM owner for the classes it
# manages -- PCI/PCIe, USB and the Intel audio DSP -- via RUNTIME_PM_ON_AC /
# RUNTIME_PM_ON_BAT in /etc/tlp.d/50-lenovo-d330.conf, and the scoped udev rule
# owns the eMMC host + dock. This script must NOT write the runtime-PM control
# attribute; it used to, and that raced TLP and silently discarded its AC/DC
# policy. It only sets EPP and max_perf_pct.
#
# Idempotent and safe to re-run; it is re-applied on AC plug/unplug by the
# SUBSYSTEM=="power_supply" ACTION=="change" udev rule in
# /etc/udev/rules.d/95-lenovo-d330-power.rules.
# ==============================================================================

set -euo pipefail

# 1. Determine AC or Battery power state from the power_supply class
IS_ON_AC=1
for ac in /sys/class/power_supply/A*/online /sys/class/power_supply/ADP*/online; do
    if [ -f "$ac" ]; then
        VAL=$(cat "$ac" 2>/dev/null || echo 1)
        [ "$VAL" -eq 0 ] && IS_ON_AC=0
    fi
done

# 2. Select EPP policy and the AC-aware max_perf_pct cap
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

# 4. Apply the AC-aware CPU performance cap (100 on AC, 75 on battery)
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
    echo "$MAX_PERF" > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true
fi

# 5. Runtime PM is intentionally NOT touched here. TLP (RUNTIME_PM_ON_AC/ON_BAT)
#    owns PCI/USB/I2C/sound; the scoped udev rule owns the eMMC host and dock.
#    Writing the runtime-PM control attribute from this script would be a second
#    writer on the same knob.

exit 0
