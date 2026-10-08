#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Wi-Fi & Bluetooth Coexistence Verification Script
# Verifies the Realtek RTL8821CE module configuration and antenna settings.
#
# `--dry-run` parses the shipped modprobe conf and exits non-zero if an unknown
# module name is configured or the in-tree `rtw88_8821ce` name is missing (SC3).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

CONF="patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf"
SLEEP_HOOK="patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh"

# Modules the D330 may legitimately configure. Realtek only: the D330 has no
# Intel wireless, so any Intel option (or any other unknown name) is an error.
KNOWN_MODULES="rtl8821ce rtw88_8821ce rtw88_core rtw88_pci"

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_wireless_coex.sh [OPTIONS]

Options:
  --probe          Inspect wireless module parameters and active adapters (default)
  --dry-run        Validate the modprobe conf module names and options
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)   MODE="probe";   shift ;;
        --dry-run) MODE="dry-run"; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL Wireless Coexistence Test Tool         "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying wireless coexistence configuration..."
    fail=0

    if [[ ! -f "$CONF" ]]; then
        echo "[FAIL] missing modprobe conf: $CONF" >&2
        exit 1
    fi

    # Every `options <module> ...` line must name a known module.
    mods="$(awk '/^[[:space:]]*options[[:space:]]/ { print $2 }' "$CONF")"
    if [[ -z "$mods" ]]; then
        echo "[FAIL] no module options found in $CONF" >&2
        exit 1
    fi
    for m in $mods; do
        if ! printf '%s\n' $KNOWN_MODULES | grep -qx -- "$m"; then
            echo "[FAIL] unknown module configured: $m" >&2
            fail=1
        else
            echo "  [OK] known module: $m"
        fi
    done

    # The in-tree driver name must be present (the D330's primary driver).
    if ! printf '%s\n' $mods | grep -qx "rtw88_8821ce"; then
        echo "[FAIL] in-tree module rtw88_8821ce is not configured" >&2
        fail=1
    fi

    # ant_sel must actually be set on a Realtek 8821ce line.
    if grep -qE '^[[:space:]]*options[[:space:]]+(rtl8821ce|rtw88_8821ce)[[:space:]].*ant_sel=' "$CONF"; then
        echo "  [OK] ant_sel set on a Realtek 8821ce module"
    else
        echo "[FAIL] no ant_sel= option on a Realtek 8821ce module" >&2
        fail=1
    fi

    # No Intel wireless options (the D330 has no Intel wireless).
    if grep -qE 'iwlwifi|iwlmvm' "$CONF"; then
        echo "[FAIL] Intel wireless option present in $CONF" >&2
        fail=1
    else
        echo "  [OK] no Intel wireless options"
    fi

    if [[ -f "$SLEEP_HOOK" ]]; then
        echo "  [OK] sleep hook present: $SLEEP_HOOK"
    else
        echo "[FAIL] sleep hook missing: $SLEEP_HOOK" >&2
        fail=1
    fi

    if [[ "$fail" -ne 0 ]]; then
        echo "[DRY-RUN] Verification FAILED." >&2
        exit 1
    fi
    echo "[DRY-RUN] Verification complete."
    exit 0
fi

echo "--- 1. Loaded Wireless Drivers ---"
for mod in rtw88_8821ce rtl8821ce rtw88_core rtw88_pci btusb; do
    if lsmod | grep -q "^$mod"; then
        echo "  [OK] $mod loaded"
    fi
done

echo ""
echo "--- 2. Active Wireless Interfaces ---"
for iface in /sys/class/net/wl*; do
    if [[ -d "$iface" ]]; then
        name="${iface##*/}"
        operstate=$(cat "$iface/operstate" 2>/dev/null || echo "unknown")
        echo "  - $name: state=$operstate"
    fi
done

echo "=========================================================="
echo " Wireless test completed.                                 "
echo "=========================================================="
