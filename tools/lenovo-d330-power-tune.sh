#!/usr/bin/env bash
# ==============================================================================
# lenovo-d330-power-tune.sh
#
# Applies the AC-aware CPU performance cap.
#
# Ownership (Phase 40): TLP is the single runtime-PM owner for the classes it
# manages -- PCI/PCIe and USB -- via RUNTIME_PM_ON_AC / RUNTIME_PM_ON_BAT in
# /etc/tlp.d/50-lenovo-d330.conf, and the scoped udev rule owns the i2c bus,
# the Intel audio DSP, the eMMC host and the dock. TLP also owns EPP
# (CPU_ENERGY_PERF_POLICY_*) and the scaling governor
# (CPU_SCALING_GOVERNOR_*). This script must NOT write the runtime-PM control
# attribute, EPP or the governor; it used to, and that raced TLP and silently
# discarded its AC/DC policy. It only sets max_perf_pct.
#
# Idempotent and safe to re-run; it is re-applied on AC plug/unplug by the
# SUBSYSTEM=="power_supply" ENV{POWER_SUPPLY_TYPE}=="Mains" ACTION=="change"
# udev rule in /etc/udev/rules.d/95-lenovo-d330-power.rules.
# ==============================================================================

set -euo pipefail

# 1. Determine AC or Battery power state from the power_supply class.
#    Detect by the node's `type == "Mains"` rather than a name glob: the
#    adapter node may be AC*, ADP*, ucsi-source-psy-*, main-charger, ... and
#    matching names is fragile. RESET from the aggregate and DEFAULT TO BATTERY
#    when nothing matches, so a missed node never leaves the AC performance cap
#    enabled on battery.
IS_ON_AC=0
for psy in /sys/class/power_supply/*; do
    [ -f "$psy/type" ] || continue
    [ "$(cat "$psy/type" 2>/dev/null || true)" = "Mains" ] || continue
    online=$(cat "$psy/online" 2>/dev/null || true)
    # Guarded numeric compare: a non-numeric value would abort under set -e.
    if [[ "$online" =~ ^[0-9]+$ ]] && [ "$online" -ne 0 ]; then
        IS_ON_AC=1
    fi
done

# 2. Select the AC-aware max_perf_pct cap (100 on AC, 75 on battery)
if [ "$IS_ON_AC" -eq 1 ]; then
    MAX_PERF=100
else
    MAX_PERF=75
fi

# 3. Apply the AC-aware CPU performance cap. EPP and scaling_governor are NOT
#    touched here: TLP owns CPU_ENERGY_PERF_POLICY_* / CPU_SCALING_GOVERNOR_*,
#    and writing them from this script would be a second writer on those knobs.
if [ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]; then
    echo "$MAX_PERF" > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true
fi

# 4. Runtime PM is intentionally NOT touched here. TLP (RUNTIME_PM_ON_AC/ON_BAT)
#    owns PCI/USB; the scoped udev rule owns i2c, sound, the eMMC host and the
#    dock. Writing the runtime-PM control attribute from this script would be a
#    second writer on the same knob.

exit 0
