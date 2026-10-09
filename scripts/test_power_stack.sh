#!/usr/bin/env bash
# ==============================================================================
# scripts/test_power_stack.sh
#
# Static guard suite (Phase 40, audit M13/M14): the power stack must have exactly
# one writer per knob. TLP owns runtime PM (PCI/PCIe) + GPU freq + EPP/governor,
# the udev rules are scoped to the controllers TLP does not manage, the CPU perf
# cap is AC-aware and re-applied on mains-source change, `nowatchdog` is gone
# and no auto-panic watchdog override is set, and the thermal fallback guards its
# arithmetic.
#
# Asserted:
#   (1) tools/lenovo-d330-power-tune.sh reads AC state (by type == "Mains",
#       defaulting to battery), writes max_perf_pct from an AC/battery branch
#       (no unconditional cap) and no longer writes the runtime-PM control
#       attribute or the EPP/governor knobs TLP owns;
#   (2) 95-lenovo-d330-power.rules has a Mains-filtered power_supply
#       ACTION=="change" re-run rule;
#   (3) every power/control writer in patches/*/etc/udev/rules.d/*.rules is
#       scoped: the 95 rules cover i2c/sound/mmc/dock only (no pci), and any
#       PCI writer repo-wide is device-scoped (the IPU3 camera exception);
#   (4) TLP declares RUNTIME_PM_ON_AC as the runtime-PM writer;
#   (5) no rejected INTEL_GPU_MIN_FREQ_ON_AC=100, and MAX/BOOST are kept;
#   (6) nowatchdog absent and no auto-panic watchdog override in the real
#       GRUB_CMDLINE_LINUX_DEFAULT tokens (comment text does not count);
#   (7) d330-thermal-tune.sh has numeric guards before its arithmetic;
#   (8) thermald thermal-conf.xml uses the real x86_pkg_temp zone type;
#   (9) packaging/debian/control Recommends thermald.
#
# Exits non-zero if any case fails.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

POWER_TUNE="tools/lenovo-d330-power-tune.sh"
POWER_RULES="patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules"
TLP_CONF="patches/power/etc/tlp.d/50-lenovo-d330.conf"
FASTBOOT_CFG="patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg"
THERMAL_XML="patches/thermal/etc/thermald/thermal-conf.xml"
THERMAL_TUNE="tools/d330-thermal-tune.sh"
DEBIAN_CONTROL="packaging/debian/control"

echo "=========================================================="
echo " Lenovo D330 power-stack single-writer guard suite        "
echo "=========================================================="

passed=0
failed=0
ok()   { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# (1) AC-aware CPU perf cap: detects AC via power_supply type == "Mains"
# (defaulting to battery), writes max_perf_pct from a branch (100 on AC / 75 on
# battery), and does not write the runtime-PM control attribute or the EPP/
# governor knobs (those belong to TLP).
if grep -q 'power_supply' "$POWER_TUNE" \
   && grep -Fq 'IS_ON_AC=0' "$POWER_TUNE" \
   && grep -Fq '"Mains"' "$POWER_TUNE" \
   && grep -q 'online=' "$POWER_TUNE" \
   && grep -q 'max_perf_pct' "$POWER_TUNE" \
   && grep -q 'MAX_PERF=100' "$POWER_TUNE" \
   && grep -q 'MAX_PERF=75' "$POWER_TUNE" \
   && grep -Fq '$MAX_PERF' "$POWER_TUNE"; then
    ok "CPU perf cap is AC-aware (detects Mains, max_perf_pct from AC/battery branch)"
else
    fail "CPU perf cap is not AC-aware (missing Mains detection or branch/write)"
fi
if grep -q '/power/control' "$POWER_TUNE"; then
    fail "power-tune.sh still writes /power/control (a second runtime-PM writer)"
else
    ok "power-tune.sh no longer writes /power/control (TLP is sole runtime-PM owner)"
fi

# (2) power_supply change re-run rule, Mains-filtered
if grep -q 'SUBSYSTEM=="power_supply"' "$POWER_RULES" \
   && grep -q 'ACTION=="change"' "$POWER_RULES" \
   && grep -q 'POWER_SUPPLY_TYPE}=="Mains"' "$POWER_RULES"; then
    ok "95-power rules re-run on Mains power_supply change (AC plug lifts the cap)"
else
    fail "95-power rules lack a Mains-filtered power_supply ACTION==change re-run rule"
fi

# (3) scoped runtime PM: the 95 rules cover only i2c/sound/mmc/dock (no pci);
# repo-wide, any PCI power/control writer must be device-scoped (the IPU3 camera
# exception), so TLP remains the sole broad PCI writer.
broad=0
grep -qE 'SUBSYSTEM=="pci".*power/control' "$POWER_RULES" && broad=1
missing=""
for cls in i2c sound mmc usb; do
    grep -qE "SUBSYSTEM==\"$cls\".*power/control" "$POWER_RULES" || missing="$missing $cls"
done
repo_broad=0
pci_lines=$(grep -rhE 'SUBSYSTEM=="pci".*power/control' patches/*/etc/udev/rules.d/*.rules 2>/dev/null || true)
while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | grep -q 'ATTR{device}' || repo_broad=1
done <<< "$pci_lines"
if [ -z "$missing" ] && [ "$broad" -eq 0 ] && [ "$repo_broad" -eq 0 ]; then
    ok "udev runtime PM scoped (i2c/sound/mmc/usb present; no pci in 95; PCI writers device-scoped)"
else
    fail "udev runtime PM not scoped (missing:$missing 95-pci=$broad repo-broad-pci=$repo_broad)"
fi

# (4) TLP is the declared runtime-PM owner
if grep -q 'RUNTIME_PM_ON_AC' "$TLP_CONF"; then
    ok "TLP declares RUNTIME_PM_ON_AC/ON_BAT as the runtime-PM writer"
else
    fail "TLP does not declare RUNTIME_PM_ON_AC"
fi

# (5) no rejected sub-minimum GPU freq; MAX/BOOST kept
if grep -q 'INTEL_GPU_MIN_FREQ_ON_AC=100' "$TLP_CONF"; then
    fail "TLP still sets INTEL_GPU_MIN_FREQ_ON_AC=100 (below GLK min, rejected)"
else
    ok "no rejected INTEL_GPU_MIN_FREQ_ON_AC=100"
fi
if grep -qE 'INTEL_GPU_(MAX_FREQ_ON_AC|BOOST_FREQ_ON_AC)' "$TLP_CONF"; then
    ok "TLP keeps the documented GPU MAX/BOOST frequencies"
else
    fail "TLP GPU MAX/BOOST frequencies are missing"
fi

# (6) watchdog: nowatchdog gone, and no auto-panic override (softlockup_panic /
# panic=) in the real GRUB_CMDLINE_LINUX_DEFAULT line (comment text does not
# satisfy these). Detection stays on; a lockup logs instead of panicking.
if grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=.*nowatchdog' "$FASTBOOT_CFG"; then
    fail "fastboot cfg still disables watchdog detection with nowatchdog"
else
    ok "no nowatchdog in fastboot cfg cmdline"
fi
if grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=.*(softlockup_panic|panic=)' "$FASTBOOT_CFG"; then
    fail "fastboot cfg carries an auto-panic watchdog override (softlockup_panic/panic=)"
else
    ok "no auto-panic watchdog override in fastboot cfg cmdline (watchdog logs only)"
fi

# (7) thermal numeric guards (pl1/pl2 and thermal-zone temp); portable
# fixed-string match, not GNU-grep-dependent \^ handling.
if grep -Fq '=~ ^[0-9]' "$THERMAL_TUNE"; then
    ok "d330-thermal-tune.sh guards its arithmetic with a numeric regex"
else
    fail "d330-thermal-tune.sh lacks the numeric guard before its arithmetic"
fi

# (8) thermald zone type matches the real sysfs type
if grep -q '<Type>x86_pkg_temp</Type>' "$THERMAL_XML"; then
    ok "thermald thermal-conf.xml uses the x86_pkg_temp zone type"
else
    fail "thermald thermal-conf.xml zone type is not x86_pkg_temp"
fi

# (9) thermald declared
if grep -qiE '^Recommends:.*thermald' "$DEBIAN_CONTROL"; then
    ok "debian control Recommends thermald"
else
    fail "debian control does not declare thermald in Recommends"
fi

echo ""
echo "=========================================================="
echo " power-stack guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
