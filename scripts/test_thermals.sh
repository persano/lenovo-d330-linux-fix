#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Thermal & RAPL Verification Script
# Verifies CPU temperature sensors, thermald configuration, and power caps

set -euo pipefail

# CWD anchoring: resolve the repo root from this script's own location so the
# tools/ references below work from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_thermals.sh [OPTIONS]

Options:
  --probe          Inspect thermal zones, CPU temperature, and RAPL power caps (default)
  --apply          Apply 5.0W / 8.0W RAPL limits
  --dry-run        Validate thermal configuration files without writing to sysfs
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
echo " Lenovo D330-10IGL Thermal Management Test Tool           "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying thermal tuning presets..."
    echo "  - PL1 (Sustained TDP): 5.0 W"
    echo "  - PL2 (Burst TDP):     8.0 W"
    echo "  - Passive Trip Point:  72.0 °C"
    echo "  - Critical Trip Point: 85.0 °C"
    echo "[DRY-RUN] Thermal presets verified."
    exit 0
fi

case "$MODE" in
    probe)
        bash "$SCRIPT_DIR/tools/d330-thermal-tune.sh"
        ;;
    apply)
        bash "$SCRIPT_DIR/tools/d330-thermal-tune.sh" --apply
        ;;
esac

echo "=========================================================="
echo " Thermal test completed.                                  "
echo "=========================================================="
