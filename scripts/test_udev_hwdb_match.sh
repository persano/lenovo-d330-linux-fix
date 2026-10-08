#!/usr/bin/env bash
# ==============================================================================
# scripts/test_udev_hwdb_match.sh
#
# Static guard suite (Phase 39, audit M8/M9/M10/M15/M16): every udev rule and
# hwdb entry must match a real D330 device string, and no modprobe option may
# target an absent module.
#
# Asserted:
#   (1) no space-stripped `pvr...` DMI pattern anywhere under patches/;
#   (2) both hwdb files match on the space-free product code `pn82H0`;
#   (3) the sensor rules use case-insensitive `[Bb][Oo][Ss][Cc]0200` /
#       `[Aa][Cc][Pp][Ii]0008` globs;
#   (4) the wireless modprobe conf contains no Intel option;
#   (5) the 88 hardware rules carry no MODE=/GROUP= attribute (a sysfs no-op);
#   (6) no dead SOUND_INITIALIZED / WL_OUTPUT properties remain;
#   (7) the wireless conf configures the in-tree `rtw88_8821ce` module.
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

# (2) both hwdb files use the space-free product code
if grep -q "pn82H0" "$SENSOR_HWDB" && grep -q "pn82H0" "$TOUCH_HWDB"; then
    ok "sensor/touchscreen hwdb match on pn82H0"
else
    fail "hwdb files missing the pn82H0 product code"
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

# (7) the wireless conf names the in-tree module
if grep -q "options rtw88_8821ce" "$WIRELESS_CONF"; then
    ok "wireless conf configures rtw88_8821ce"
else
    fail "wireless conf does not configure rtw88_8821ce"
fi

echo ""
echo "=========================================================="
echo " udev/hwdb match guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
