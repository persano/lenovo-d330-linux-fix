#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL MicroSD & Cellular LTE Verification Script
# Verifies secondary MicroSD block device and Intel XMM 7360 LTE modem

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_storage_cellular.sh [OPTIONS]

Options:
  --probe          Inspect MicroSD card slot and LTE modem state (default)
  --test-microsd   Run probe using tools/d330-microsd-setup.sh
  --dry-run        Validate scripts and configs without modifying hardware
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --test-microsd)
            MODE="test-microsd"
            shift
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL MicroSD & LTE Cellular Test Tool       "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying MicroSD tool and Cellular configurations..."
    # New lines anchor via SCRIPT_DIR/REPO_ROOT (test_resume_loop.sh pattern);
    # existing cwd-relative lines elsewhere are left alone (Phase 41 owns that).
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "$REPO_ROOT"

    for f in tools/d330-microsd-setup.sh scripts/test_microsd_guards.sh scripts/test_storage_cellular.sh; do
        if bash -n "$f"; then
            echo "[OK] bash -n $f"
        else
            echo "[FAIL] bash -n $f" >&2
            exit 1
        fi
    done

    # Guard suite: its non-zero exit propagates under set -e, so any failing
    # case fails this mode; its passed=N failed=M summary flows into this output.
    bash scripts/test_microsd_guards.sh

    # Inventory context only - these paths are not checks.
    echo "[INFO] ModemManager FCC Unlock: patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:7360"
    echo "[INFO] Cellular Rules: patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules"
    echo "[OK] dry-run verification complete"
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. MicroSD Storage State ---"
        bash tools/d330-microsd-setup.sh --probe

        echo ""
        echo "--- 2. LTE Cellular Modem State ---"
        if lspci -d 8086:7360 >/dev/null 2>&1; then
            echo "[OK] Intel XMM 7360 LTE modem detected on PCI bus:"
            lspci -d 8086:7360
            if command -v mmcli >/dev/null 2>&1; then
                mmcli -L || true
            fi
        else
            echo "[INFO] No PCI 8086:7360 LTE modem found (Wi-Fi only SKU or disabled in BIOS)."
        fi
        ;;
    test-microsd)
        bash tools/d330-microsd-setup.sh --probe
        ;;
esac

echo "=========================================================="
echo " Test completed.                                          "
echo "=========================================================="
