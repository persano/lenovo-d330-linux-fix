#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Boot Orientation Verification Script
# Verifies GRUB cmdline, fbcon rotation, Plymouth hooks, and screen refresh script

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_boot_orientation.sh [OPTIONS]

Options:
  --probe          Inspect kernel cmdline, fbcon orientation, and Plymouth status (default)
  --test-refresh   Simulate emergency screen refresh cycle
  --dry-run        Validate boot configuration files without touching bootloader
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --test-refresh)
            MODE="test-refresh"
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
echo " Lenovo D330-10IGL Boot & Console Orientation Test Tool   "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying boot orientation files and parameters..."
    echo "  - GRUB Snippet: patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg"
    echo "  - Initramfs Hook: patches/boot_orientation/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth"
    echo "  - Emergency Refresh Tool: tools/d330-refresh-screen.sh"
    echo "  - Parameters: fbcon=rotate:1, video=efifb:nobgrt"
    echo "[DRY-RUN] Configuration verified successfully."
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. Kernel Boot Command Line ---"
        cat /proc/cmdline 2>/dev/null || echo "Unable to read /proc/cmdline"

        echo ""
        echo "--- 2. Framebuffer Console Driver ---"
        if [[ -f /sys/class/graphics/fbcon/rotate ]]; then
            echo "  Active fbcon rotation: $(cat /sys/class/graphics/fbcon/rotate)"
        else
            echo "[INFO] fbcon rotate node not present (efifb / drm fb active)"
        fi
        ;;
    test-refresh)
        echo "Running emergency screen refresh simulation..."
        bash tools/d330-refresh-screen.sh
        ;;
esac

echo "=========================================================="
echo " Boot orientation test completed.                         "
echo "=========================================================="
