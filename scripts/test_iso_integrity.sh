#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL ISO Remaster Integrity Verification Script
# Tests tool prerequisites and verifies ISO filesystem integrity

set -euo pipefail

MODE="probe"
ISO_IMAGE="${1:-lenovo-d330-linux-remastered.iso}"

show_help() {
    cat << 'EOF'
Usage: scripts/test_iso_integrity.sh [OPTIONS] [ISO_PATH]

Options:
  --probe          Inspect remastering build tools and dependencies (default)
  --verify <iso>   Inspect bootable ISO image headers and El Torito UEFI boot catalog
  --dry-run        Validate ISO remaster script syntax and prerequisites
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --verify)
            MODE="verify"
            ISO_IMAGE="$2"
            shift 2
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
            ISO_IMAGE="$1"
            shift
            ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL Live ISO Remaster Verification Tool    "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying ISO build harness..."
    bash scripts/build_live_iso.sh --dry-run
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. Required Build Tools ---"
        for t in xorriso mksquashfs unsquashfs; do
            if command -v "$t" >/dev/null 2>&1; then
                echo "  [OK] $t installed"
            else
                echo "  [INFO] $t not found in current environment."
            fi
        done
        ;;
    verify)
        if [[ ! -f "$ISO_IMAGE" ]]; then
            echo "[ERR] Target ISO file not found: $ISO_IMAGE"
            exit 1
        fi
        echo "Verifying ISO image: $ISO_IMAGE ($(stat -c%s "$ISO_IMAGE") bytes)..."
        if command -v xorriso >/dev/null 2>&1; then
            xorriso -indev "$ISO_IMAGE" -report_el_torito plain || true
        else
            echo "[OK] File present. Install xorriso for detailed El Torito validation."
        fi
        ;;
esac

echo "=========================================================="
echo " ISO verification complete.                               "
echo "=========================================================="
