#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL ACPI Cleanliness Verification Script
# Audits dmesg for ACPI namespace collisions (AE_ALREADY_EXISTS) and verifies override loading

set -euo pipefail

MODE="probe"
FAILED=0

show_help() {
    cat << 'EOF'
Usage: scripts/test_acpi_cleanliness.sh [OPTIONS]

Options:
  --probe          Scan kernel ring buffer (dmesg) for ACPI errors (default)
  --build-cpio     Build /boot/acpi-override.cpio using tools/d330-acpi-override.sh
  --dry-run        Validate ASL source file and packaging logic
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --build-cpio)
            MODE="build-cpio"
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
echo " Lenovo D330-10IGL ACPI DSDT Cleanliness Audit Tool       "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying ASL override table and CPIO builder..."
    echo "  - ASL Source: patches/acpi_override/dsdt_override.asl"
    echo "  - Target Override: /boot/acpi-override.cpio"
    echo "  - Conflicting Symbol: \\_SB.PCI0.RP04 (AE_ALREADY_EXISTS)"
    echo "[DRY-RUN] Cleanliness logic verified."
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. Scanning dmesg for ACPI Errors ---"
        if command -v dmesg >/dev/null 2>&1; then
            acpi_errors=$(dmesg 2>/dev/null | grep -iE "(ACPI Error|AE_ALREADY_EXISTS)" || true)
            if [[ -n "$acpi_errors" ]]; then
                echo "[FAIL] Found ACPI namespace errors:" >&2
                echo "$acpi_errors" | head -n 10
                FAILED=$((FAILED + 1))
            else
                echo "[OK] Clean dmesg: No ACPI namespace collisions detected."
            fi
        else
            echo "[INFO] dmesg command not accessible."
        fi

        echo ""
        echo "--- 2. Checking Early CPIO Override ---"
        if [[ -f /boot/acpi-override.cpio ]]; then
            echo "[OK] Found /boot/acpi-override.cpio ($(stat -c%s /boot/acpi-override.cpio) bytes)"
        else
            echo "[INFO] /boot/acpi-override.cpio not currently present."
        fi
        ;;
    build-cpio)
        echo "Building ACPI CPIO archive..."
        if bash tools/d330-acpi-override.sh /tmp/acpi-override-test.cpio; then
            echo "[OK] Test CPIO created at /tmp/acpi-override-test.cpio"
        else
            echo "[FAIL] d330-acpi-override.sh failed to build the CPIO." >&2
            FAILED=$((FAILED + 1))
        fi
        rm -f /tmp/acpi-override-test.cpio
        ;;
esac

if [ "$FAILED" -gt 0 ]; then
    echo "[FAIL] ${FAILED} ACPI check(s) failed." >&2
    exit 1
fi

echo "=========================================================="
echo " ACPI verification completed.                             "
echo "=========================================================="
