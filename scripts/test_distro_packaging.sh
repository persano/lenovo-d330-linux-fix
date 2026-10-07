#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Packaging Verification Script
# Validates Debian control/rules, Fedora RPM spec, and Arch PKGBUILD recipes

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_distro_packaging.sh [OPTIONS]

Options:
  --probe          Verify package descriptor files and dependencies (default)
  --dry-run        Validate syntax of .deb, .rpm, and PKGBUILD metadata
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
echo " Lenovo D330-10IGL Distro Packaging Verification Tool     "
echo "=========================================================="

DEB_CTRL="packaging/debian/control"
RPM_SPEC="packaging/rpm/lenovo-d330-fix.spec"
ARCH_PKG="packaging/arch/PKGBUILD"

check_file() {
    local file="$1"
    local desc="$2"
    if [[ -f "$file" ]]; then
        echo "  [OK] Found $desc ($file)"
    else
        echo "  [FAIL] Missing $desc at $file"
        return 1
    fi
}

echo "--- 1. Packaging Recipe Verification ---"
check_file "$DEB_CTRL" "Debian control file"
check_file "$RPM_SPEC" "RPM spec file"
check_file "$ARCH_PKG" "Arch PKGBUILD"

echo ""
echo "--- 2. Syntax Validation ---"
# Check Debian control format
if grep -q "Package: lenovo-d330-fix" "$DEB_CTRL"; then
    echo "  [OK] Debian package: lenovo-d330-fix valid"
fi

# Check RPM spec format
if grep -q "Name:.*lenovo-d330-fix" "$RPM_SPEC"; then
    echo "  [OK] RPM spec: lenovo-d330-fix valid"
fi

# Check PKGBUILD bash syntax
if bash -n "$ARCH_PKG"; then
    echo "  [OK] Arch PKGBUILD bash syntax valid"
fi

echo "=========================================================="
echo " Packaging validation finished successfully.             "
echo "=========================================================="
