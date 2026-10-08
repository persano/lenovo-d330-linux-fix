#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Low-Battery Hibernate Verification Script
# Verifies power supply monitoring, hibernate capability, and dry-run safety

set -euo pipefail

MODE="probe"
FAILED=0

show_help() {
    cat << 'EOF'
Usage: scripts/test_auto_hibernate.sh [OPTIONS]

Options:
  --probe          Inspect battery status, swap space, and hibernation state (default)
  --simulate       Run auto-hibernate script in dry-run mode
  --dry-run        Validate script logic and parameters
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --simulate)
            MODE="simulate"
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
echo " Lenovo D330-10IGL Auto-Hibernate Verification Tool       "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying auto-hibernate daemon..."
    echo "  - Critical threshold: <= 5% capacity"
    echo "  - Trigger: Discharging state"
    if ! python3 tools/d330-auto-hibernate.py --dry-run; then
        echo "[FAIL] auto-hibernate dry-run validation failed." >&2
        FAILED=$((FAILED + 1))
    fi
    if [ "$FAILED" -gt 0 ]; then
        echo "[FAIL] ${FAILED} check(s) failed." >&2
        exit 1
    fi
    echo "[DRY-RUN] Logic verified successfully."
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. Power State & Hibernation Support ---"
        if [[ -f /sys/power/state ]]; then
            echo "  Supported sleep states: $(cat /sys/power/state)"
        fi
        if [[ -f /sys/power/resume ]]; then
            echo "  Resume device major:minor: $(cat /sys/power/resume)"
        fi

        echo ""
        echo "--- 2. Battery Monitoring ---"
        if ! python3 tools/d330-auto-hibernate.py --dry-run; then
            echo "[FAIL] auto-hibernate battery monitor failed." >&2
            FAILED=$((FAILED + 1))
        fi
        ;;
    simulate)
        echo "Simulating low-battery auto-hibernate..."
        if ! python3 tools/d330-auto-hibernate.py --dry-run; then
            echo "[FAIL] auto-hibernate simulation failed." >&2
            FAILED=$((FAILED + 1))
        fi
        ;;
esac

if [ "$FAILED" -gt 0 ]; then
    echo "[FAIL] ${FAILED} check(s) failed." >&2
    exit 1
fi

echo "=========================================================="
echo " Verification completed.                                  "
echo "=========================================================="
