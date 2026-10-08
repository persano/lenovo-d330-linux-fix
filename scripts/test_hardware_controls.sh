#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Hardware Controls Verification Script
# Verifies ideapad_laptop VPC2004 features: conservation_mode, fn_lock, d330-ctl

set -euo pipefail

# CWD anchoring: resolve the repo root from this script's own location so the
# tools/ references below work from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

MODE="probe"
APPLY=0
FAILED=0

show_help() {
    cat << 'EOF'
Usage: scripts/test_hardware_controls.sh [OPTIONS]

Options:
  --probe          Inspect active VPC2004 sysfs nodes and ideapad_laptop driver (default)
  --test-toggle    Toggle battery conservation mode and restore it (requires --apply)
  --apply          Actually write to hardware (required for --test-toggle)
  --dry-run        Validate CLI tool and script without writing to hardware
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --test-toggle)
            MODE="test-toggle"
            shift
            ;;
        --apply)
            APPLY=1
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
echo " Lenovo D330-10IGL Hardware Controls (VPC2004) Test Tool  "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying d330-ctl tool execution..."
    if ! python3 "$SCRIPT_DIR/tools/d330-ctl" status; then
        echo "[FAIL] d330-ctl status failed." >&2
        exit 1
    fi
    echo "[DRY-RUN] Hardware controls logic validated."
    exit 0
fi

case "$MODE" in
    probe)
        if ! python3 "$SCRIPT_DIR/tools/d330-ctl" status; then
            echo "[FAIL] d330-ctl status failed." >&2
            FAILED=$((FAILED + 1))
        fi
        ;;
    test-toggle)
        echo "Testing Battery Conservation Mode toggle..."
        if [[ "$APPLY" -ne 1 ]]; then
            echo "[INFO] --test-toggle is read-only without --apply."
            echo "[INFO] Would toggle conservation_mode and restore the original value."
            python3 "$SCRIPT_DIR/tools/d330-ctl" battery status || true
            exit 0
        fi
        if [[ $EUID -ne 0 ]]; then
            echo "[FAIL] Root privileges required to toggle conservation_mode." >&2
            exit 1
        fi
        node=""
        for d in /sys/bus/platform/drivers/ideapad_laptop/VPC2004:00 \
                 /sys/devices/platform/VPC2004:00 \
                 /sys/bus/platform/devices/VPC2004:00; do
            if [[ -e "$d/conservation_mode" ]]; then
                node="$d/conservation_mode"
                break
            fi
        done
        if [[ -z "$node" ]]; then
            echo "[FAIL] conservation_mode node not found (ideapad_laptop driver inactive)." >&2
            exit 1
        fi
        original="$(cat "$node")"
        if ! echo 1 > "$node" 2>/dev/null; then
            echo "[FAIL] Could not write conservation_mode=1 to $node." >&2
            exit 1
        fi
        toggled="$(cat "$node")"
        if ! echo "$original" > "$node" 2>/dev/null; then
            echo "[FAIL] Could not restore conservation_mode=$original to $node." >&2
            exit 1
        fi
        restored="$(cat "$node")"
        if [[ "$toggled" != "1" || "$restored" != "$original" ]]; then
            echo "[FAIL] Toggle/restore mismatch (toggled=$toggled restored=$restored original=$original)." >&2
            exit 1
        fi
        echo "[OK] Conservation mode toggled to 1 and restored to $original."
        ;;
esac

if [ "$FAILED" -gt 0 ]; then
    echo "[FAIL] ${FAILED} check(s) failed." >&2
    exit 1
fi

echo "=========================================================="
echo " Test completed.                                          "
echo "=========================================================="
