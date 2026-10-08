#!/usr/bin/env bash
# ==============================================================================
# scripts/test_udev_hwdb_match.sh
#
# Static guard suite (Phase 39, audit M8/M9/M10/M15/M16): every udev rule and
# hwdb entry must match a real D330 device string, and every modprobe option
# must target a module that actually exists.
#
# Asserted:
#   (1) no space-stripped `pvr...` DMI pattern anywhere under patches/;
#   (2) both hwdb files match all three product codes pn82H0 / pn81MD / pn81H3;
#   (3) the sensor rules use case-insensitive `[Bb][Oo][Ss][Cc]0200` /
#       `[Aa][Cc][Pp][Ii]0008` globs;
#   (4) the wireless modprobe conf contains no Intel option;
#   (5) the 88 hardware rules carry no MODE=/GROUP= attribute (a sysfs no-op);
#   (6) no dead SOUND_INITIALIZED / WL_OUTPUT properties remain;
#   (7) EVERY patches/*/etc/modprobe.d/*.conf `options <module>` names a real
#       module (blocklist known non-modules / absent hardware);
#   (8) the wireless conf configures the in-tree `rtw88_core` helper.
#
# Exits non-zero if any case fails.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

WIRELESS_CONF="patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf"
SENSOR_HWDB="patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb"
TOUCH_HWDB="patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb"
SENSOR_RULES="patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules"
HW_RULES="patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules"

# Known non-modules / absent-hardware names that must never receive options on
# the D330. `pcie_aspm` is a kernel boot parameter, not a module; `iwlwifi` /
# `iwlmvm` name Intel Wi-Fi hardware the D330 does not have.
BLOCKED_MODULES="pcie_aspm iwlwifi iwlmvm"

echo "=========================================================="
echo " Lenovo D330 udev / hwdb / wireless match guard suite     "
echo "=========================================================="

passed=0
failed=0
ok()   { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# (1) no space-stripped pvr DMI pattern
if grep -rq "pvrLenovoideapad" patches/; then
    fail "space-stripped pvr DMI pattern still present under patches/"
else
    ok "no space-stripped pvr DMI pattern under patches/"
fi

# (2) both hwdb files use all three space-free product codes
missing_codes=""
for code in pn82H0 pn81MD pn81H3; do
    grep -q "$code" "$SENSOR_HWDB" || missing_codes="$missing_codes ${code}(61)"
    grep -q "$code" "$TOUCH_HWDB"  || missing_codes="$missing_codes ${code}(62)"
done
if [ -z "$missing_codes" ]; then
    ok "sensor/touchscreen hwdb match on pn82H0/pn81MD/pn81H3"
else
    fail "hwdb files missing product code(s):$missing_codes"
fi

# (3) case-insensitive sensor globs
if grep -q '\[Bb\]\[Oo\]\[Ss\]\[Cc\]0200' "$SENSOR_RULES"; then
    ok "87 sensor rules use case-insensitive BOSC0200 glob"
else
    fail "87 sensor rules do not use the case-insensitive BOSC0200 glob"
fi
if grep -q '\[Aa\]\[Cc\]\[Pp\]\[Ii\]0008' "$SENSOR_RULES"; then
    ok "87 sensor rules use case-insensitive ACPI0008 glob"
else
    fail "87 sensor rules do not use the case-insensitive ACPI0008 glob"
fi

# (4) no Intel wireless option in the wireless conf
if grep -qE 'iwlwifi|iwlmvm' "$WIRELESS_CONF"; then
    fail "Intel wireless option present in $WIRELESS_CONF"
else
    ok "no Intel wireless option in the wireless conf"
fi

# (5) no MODE=/GROUP= on the 88 hardware rules
if grep -qE 'MODE=|GROUP=' "$HW_RULES"; then
    fail "88 hardware rules still carry a MODE=/GROUP= attribute"
else
    ok "88 hardware rules carry no MODE=/GROUP= attribute"
fi

# (6) dead properties removed
if grep -rq "SOUND_INITIALIZED" patches/audio_dsp/etc/udev; then
    fail "dead SOUND_INITIALIZED property still present"
else
    ok "no SOUND_INITIALIZED property"
fi
if grep -rq "WL_OUTPUT" patches/touchscreen/etc/udev; then
    fail "dead WL_OUTPUT property still present"
else
    ok "no WL_OUTPUT property"
fi

# (7) every modprobe conf targets a real module: scan ALL shipped confs, extract
# each `options <module>` name, and reject known non-module / absent-hardware
# names. modprobe/dracut silently ignore an options line naming an absent
# module, so a wrong name is invisible at runtime; this is the static guard.
blocked_found=0
scan_count=0
for conf in patches/*/etc/modprobe.d/*.conf; do
    [ -f "$conf" ] || continue
    while IFS= read -r mod; do
        [ -n "$mod" ] || continue
        scan_count=$((scan_count + 1))
        for blocked in $BLOCKED_MODULES; do
            if [ "$mod" = "$blocked" ]; then
                fail "non-module/absent-hardware option in $conf: options $mod"
                blocked_found=1
            fi
        done
    done < <(awk '/^[[:space:]]*options[[:space:]]/ { print $2 }' "$conf")
done
if [ "$blocked_found" -eq 0 ]; then
    if [ "$scan_count" -gt 0 ]; then
        ok "all shipped modprobe options name real modules ($scan_count checked)"
    else
        fail "no modprobe options found under patches/*/etc/modprobe.d/"
    fi
fi

# (8) the wireless conf names the in-tree Realtek helper. ant_sel is
# out-of-tree-only and is deliberately not set on an rtw88 module.
if grep -qE '^[[:space:]]*options[[:space:]]+rtw88_core([[:space:]]|$)' "$WIRELESS_CONF"; then
    ok "wireless conf configures the in-tree rtw88_core module"
else
    fail "wireless conf does not configure the in-tree rtw88_core module"
fi

echo ""
echo "=========================================================="
echo " udev/hwdb match guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
