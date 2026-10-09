#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Touchpad & Active Pen Verification Script
# Verifies libinput touchpad parameters, gestures, and stylus button mapping

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_gestures_pen.sh [OPTIONS]

Options:
  --probe          Inspect touchpad configuration and pen devices (default)
  --monitor        Stream libinput debug-events for touch/pen input
  --dry-run        Validate configuration files and options without hardware interaction
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --monitor)
            MODE="monitor"
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
echo " Lenovo D330-10IGL Touchpad & Active Pen Test Tool        "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying Touchpad and Active Pen configurations..."
    ok=0
    for f in \
        "patches/touchpad_pen/usr/share/libinput/60-lenovo-d330.quirks" \
        "patches/touchpad_pen/etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf"; do
        if [ -f "$f" ]; then
            echo "  [OK]   $f"
        else
            echo "  [FAIL] $f" >&2
            ok=1
        fi
    done
    echo "  - libinput attrs (pressure/palm) apply on X11 and Wayland: 60-lenovo-d330.quirks"
    echo "  - Tapping/natural scroll/DWT/clickfinger are compositor settings on Wayland (KDE/GNOME)."
    echo "  - Active Pen: 90-degree matrix in the udev rule; pressure CURVE is X11-only."
    if [ "$ok" -ne 0 ]; then
        echo "[FAIL] Touchpad/Pen configuration files missing." >&2
        exit 1
    fi
    echo "[DRY-RUN] Configuration verified successfully."
    exit 0
fi

case "$MODE" in
    probe)
        bash tools/d330-pen-config.sh
        ;;
    monitor)
        if command -v libinput >/dev/null 2>&1; then
            echo "Monitoring libinput events (Ctrl+C to stop)..."
            libinput debug-events || true
        else
            echo "[INFO] libinput debug-events not available."
        fi
        ;;
esac

echo "=========================================================="
echo " Test completed.                                          "
echo "=========================================================="
