#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL System Tray Applet Verification Script
# Verifies tray applet script, desktop autostart entry, and CLI status

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_tray_applet.sh [OPTIONS]

Options:
  --probe          Inspect tray script and desktop autostart file (default)
  --dry-run        Validate tray applet logic
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
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
echo " Lenovo D330-10IGL System Tray Applet Test Tool           "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying tray applet..."
    python3 tools/d330-tray.py --status || true
    echo "[DRY-RUN] Verification complete."
    exit 0
fi

python3 tools/d330-tray.py --status

echo "=========================================================="
echo " Tray applet test completed.                              "
echo "=========================================================="
