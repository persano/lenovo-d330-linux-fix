#!/usr/bin/env bash
# ==============================================================================
# scripts/test_doc_parity.sh
#
# Doc<->code parity guard (Phase 42, SC1). Asserts that the claims in
# CHANGES_AUDIT.md and the shipping docs still match the code that implements
# them, so an audit cannot silently drift back to a previous value.
#
# Checks:
#   1. swappiness is 180 in the zram sysctl and in the audit (not 150)
#   2. eMMC I/O scheduler is mq-deadline in the udev rule and audit (not bfq)
#   3. i915 enable_fbc=0 in the boot cfg, the modprobe conf and audit (not enable_fbc=1)
#   4. panel_orientation is present in the boot cfg and audit
#   5. no watchdog override (no nowatchdog, no softlockup_panic/panic=) in fastboot cfg and audit
#   6. no PWM 1000 Hz boot service (no tracked unit, audit documents removal)
#   7. no GTK3 / AppIndicator tray claim (stdlib tray helper, no GTK imports)
#   8. no iwlwifi / Intel Wi-Fi option (Realtek RTL8821CE only)
#   9. the shipped scripts/test_*.sh count stated in the audit matches the tree
#  10. no touch-mode claim in the audit or d330-ctl
#  11. scripts/*.sh and tools/*.sh are mode 100755 in the index
#  12. no 0-byte tracked files (sized from the index, not the worktree)
#  13. FCC unlock hook: source non-empty + deploy/remove/manifest parity
#
# Modes: default runs every check; `--probe` lists them; `--help` prints usage.
# Exit status is non-zero when any check fails.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

AUDIT="CHANGES_AUDIT.md"
ZRAM_SYSCTL="patches/storage_memory/etc/sysctl.d/99-lenovo-d330-zram.conf"
EMMC_RULE="patches/storage_memory/etc/udev/rules.d/60-lenovo-d330-emmc.rules"
BOOT_CFG="patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg"
MODPROBE_I915="patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf"
FASTBOOT_CFG="patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg"
WIRELESS_CONF="patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf"
TRAY_TOOL="tools/d330-tray.py"
CTL_TOOL="tools/d330-ctl"
PWM_SERVICE="patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service"
INSTALLER="scripts/install_dkms.sh"
FCC_SRC="patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086"
FCC_TARGET="/etc/ModemManager/fcc-unlock.d/8086:7360"

case "${1:-}" in
    --probe)
        echo "doc-parity would check:"
        echo "  1. swappiness 180      : $ZRAM_SYSCTL + $AUDIT"
        echo "  2. mq-deadline         : $EMMC_RULE + $AUDIT"
        echo "  3. enable_fbc=0        : $BOOT_CFG + $MODPROBE_I915 + $AUDIT"
        echo "  4. panel_orientation   : $BOOT_CFG + $AUDIT"
        echo "  5. no watchdog override: $FASTBOOT_CFG + $AUDIT"
        echo "  6. no PWM boot service : $PWM_SERVICE absent"
        echo "  7. no GTK/AppIndicator : $TRAY_TOOL + $AUDIT"
        echo "  8. no iwlwifi          : $WIRELESS_CONF + $AUDIT"
        echo "  9. test-script count   : git ls-files scripts/test_*.sh vs $AUDIT"
        echo " 10. no touch-mode       : $CTL_TOOL + $AUDIT"
        echo " 11. shell modes 100755  : scripts/*.sh tools/*.sh"
        echo " 12. no 0-byte files     : git ls-files -s (index)"
        echo " 13. FCC unlock deploy   : $FCC_SRC -> $FCC_TARGET"
        exit 0
        ;;
    -h|--help)
        cat <<'EOF'
Usage: scripts/test_doc_parity.sh [--probe]

  --probe   Print the checks without running them.
EOF
        exit 0
        ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

echo "=========================================================="
echo " Lenovo D330 Doc/Code Parity Guard                        "
echo "=========================================================="

passed=0
failed=0
ok()   { echo "  [OK] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1" >&2; failed=$((failed + 1)); }

# 1. swappiness 180 -----------------------------------------------------------
if grep -qE '^[[:space:]]*vm\.swappiness[[:space:]]*=[[:space:]]*180[[:space:]]*$' "$ZRAM_SYSCTL"; then
    ok "zram-sysctl-swappiness-180"
else
    fail "$ZRAM_SYSCTL does not set vm.swappiness = 180"
fi
if grep -q 'swappiness=180' "$AUDIT" && ! grep -q 'swappiness=150' "$AUDIT"; then
    ok "audit-swappiness-180"
else
    fail "$AUDIT does not state swappiness=180 (or still says 150)"
fi

# 2. mq-deadline --------------------------------------------------------------
if grep -q 'mq-deadline' "$EMMC_RULE"; then
    ok "emmc-scheduler-mq-deadline"
else
    fail "$EMMC_RULE does not set mq-deadline"
fi
if grep -q 'mq-deadline' "$AUDIT" && ! grep -qi 'bfq' "$AUDIT"; then
    ok "audit-scheduler-mq-deadline"
else
    fail "$AUDIT does not state mq-deadline (or still mentions bfq)"
fi

# 3. enable_fbc=0 -------------------------------------------------------------
if grep -q 'i915.enable_fbc=0' "$BOOT_CFG"; then
    ok "boot-cfg-enable-fbc-0"
else
    fail "$BOOT_CFG does not carry i915.enable_fbc=0"
fi
if grep -q 'enable_fbc=0' "$MODPROBE_I915" && grep -q 'enable_psr=0' "$MODPROBE_I915"; then
    ok "modprobe-i915-enable-fbc-psr-0"
else
    fail "$MODPROBE_I915 must set enable_fbc=0 and enable_psr=0 (audit 2.1)"
fi
if grep -q 'enable_fbc=0' "$AUDIT" && ! grep -q 'enable_fbc=1' "$AUDIT"; then
    ok "audit-enable-fbc-0"
else
    fail "$AUDIT does not state enable_fbc=0 (or still says enable_fbc=1)"
fi

# 4. panel_orientation --------------------------------------------------------
if grep -q 'panel_orientation=right_side_up' "$BOOT_CFG"; then
    ok "boot-cfg-panel-orientation"
else
    fail "$BOOT_CFG does not carry panel_orientation=right_side_up"
fi
if grep -q 'panel_orientation' "$AUDIT"; then
    ok "audit-panel-orientation"
else
    fail "$AUDIT does not mention panel_orientation"
fi

# 5. no watchdog override (nowatchdog removed, no auto-panic) -----------------
if ! grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=.*(nowatchdog|softlockup_panic|panic=)' "$FASTBOOT_CFG"; then
    ok "fastboot-no-watchdog-override"
else
    fail "$FASTBOOT_CFG cmdline must not set nowatchdog/softlockup_panic/panic="
fi
if grep -qi 'softlockup_panic' "$AUDIT"; then
    fail "$AUDIT must not claim a softlockup_panic override"
else
    ok "audit-no-watchdog-override"
fi

# 6. no PWM 1000 Hz boot service ---------------------------------------------
if git ls-files '*backlight-pwm*.service' | grep -q .; then
    fail "a PWM boot service is still tracked: $(git ls-files '*backlight-pwm*.service')"
elif [ -e "$PWM_SERVICE" ]; then
    fail "PWM boot service file still present: $PWM_SERVICE"
elif ! grep -qi 'removed' "$AUDIT"; then
    fail "$AUDIT does not document that the PWM boot service was removed"
else
    ok "no-pwm-boot-service"
fi

# 7. no GTK3 / AppIndicator tray claim ---------------------------------------
# Ignore the audit's own negative claims ("no GTK", "without AppIndicator"); a
# positive GTK/AppIndicator tray claim must fail.
gtk_claim="$(grep -inE 'GTK|AppIndicator' "$AUDIT" | grep -viE 'no[ -]?(GTK|AppIndicator)|without[ -]?(GTK|AppIndicator)' || true)"
if [ -n "$gtk_claim" ]; then
    fail "$AUDIT still claims a GTK/AppIndicator tray"
elif grep -qE '(^|[[:space:]])(import[[:space:]]+gi|from[[:space:]]+gi|import[[:space:]]+Gtk|gi\.repository)' "$TRAY_TOOL"; then
    fail "$TRAY_TOOL imports GTK/gi"
else
    ok "tray-stdlib-no-gtk"
fi

# 8. no iwlwifi ---------------------------------------------------------------
if grep -qi 'iwlwifi' "$AUDIT" || grep -qi 'iwlwifi' "$WIRELESS_CONF"; then
    fail "an Intel iwlwifi option/claim is present"
else
    ok "no-iwlwifi"
fi

# 9. test-script count parity -------------------------------------------------
test_count="$(git ls-files 'scripts/test_*.sh' | wc -l | tr -d '[:space:]')"
if grep -qE "(^|[^0-9])${test_count} (test|validation)" "$AUDIT"; then
    ok "test-script-count-parity ($test_count)"
else
    fail "$AUDIT does not state the real scripts/test_*.sh count ($test_count)"
fi

# 10. no touch-mode claim -----------------------------------------------------
if grep -q 'touch-mode' "$AUDIT" || grep -q 'touch-mode' "$CTL_TOOL"; then
    fail "a nonexistent touch-mode subcommand is claimed"
else
    ok "no-touch-mode-claim"
fi

# 11. shell scripts are mode 100755 ------------------------------------------
bad_modes="$(git ls-files -s scripts/*.sh tools/*.sh | grep -v '100755' || true)"
if [ -z "$bad_modes" ]; then
    ok "shell-scripts-100755"
else
    fail "non-100755 shell scripts in the index: $bad_modes"
fi

# 12. no 0-byte tracked files -------------------------------------------------
# Size the index blobs (git cat-file -s) rather than the worktree, so a deleted
# or unchecked-out 0-byte tracked blob still fails.
empty_files=""
while read -r mode hash stage path; do
    [ "$stage" = "0" ] || continue
    if [ "$(git cat-file -s "$hash" 2>/dev/null || echo 1)" -eq 0 ]; then
        empty_files="${empty_files} ${path}"
    fi
done < <(git ls-files -s)
if [ -z "$empty_files" ]; then
    ok "no-zero-byte-tracked-files"
else
    fail "0-byte tracked files:${empty_files}"
fi

# 13. FCC unlock hook deploy parity ------------------------------------------
# The headline cellular fix: the tracked `8086` source (non-empty) is copied to
# the colon-named ModemManager target on install, removed on uninstall, and
# listed in the deploy manifest.
if [ -s "$FCC_SRC" ] \
   && grep -qE 'cp .*fcc-unlock\.d/8086.* /etc/ModemManager/fcc-unlock\.d/8086:7360' "$INSTALLER" \
   && grep -q "rm -f ${FCC_TARGET}" "$INSTALLER" \
   && grep -q "^${FCC_TARGET}[[:space:]]" "$INSTALLER"; then
    ok "fcc-unlock-deploy-parity"
else
    fail "FCC unlock deploy/remove/manifest parity broken (source $FCC_SRC, target $FCC_TARGET)"
fi

echo ""
echo "=========================================================="
echo " Doc-parity summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
