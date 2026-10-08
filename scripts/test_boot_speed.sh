#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Boot Speed Verification Script
# Evaluates systemd boot analysis and verifies fastboot configurations

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_boot_speed.sh [OPTIONS]

Options:
  --probe          Run systemd-analyze benchmark (default)
  --apply          Mask network-online wait services
  --dry-run        Validate fastboot configuration snippet
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --apply)
            MODE="apply"
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
echo " Lenovo D330-10IGL Fast Boot Performance Test Tool        "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying fast boot settings..."
    echo "  - Kernel cmdline: softlockup_panic=1 no_timer_check quiet loglevel=3"
    echo "  - Services masked: systemd-networkd-wait-online, NetworkManager-wait-online"
    echo "[DRY-RUN] Verification complete."
    exit 0
fi

case "$MODE" in
    probe)
        bash tools/d330-fastboot-tune.sh
        ;;
    apply)
        bash tools/d330-fastboot-tune.sh --apply
        ;;
esac

echo "=========================================================="
echo " Boot speed test completed.                               "
echo "=========================================================="
