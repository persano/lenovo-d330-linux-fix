#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Packaging Verification Script
# Validates Debian control/rules, Fedora RPM spec, and Arch PKGBUILD recipes

set -euo pipefail

MODE="probe"
FAILED=0

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

ok()  { echo "  [OK] $*"; }
bad() { echo "  [FAIL] $*" >&2; FAILED=$((FAILED + 1)); }

require_file() {
    local file="$1"
    local desc="$2"
    if [[ -f "$file" ]]; then
        ok "Found $desc ($file)"
    else
        bad "Missing $desc at $file"
    fi
}

validate_fields() {
    if grep -q "^Package: lenovo-d330-fix" "$DEB_CTRL" 2>/dev/null; then
        ok "Debian package: lenovo-d330-fix valid"
    else
        bad "Debian control missing 'Package: lenovo-d330-fix' in $DEB_CTRL"
    fi
    if grep -q "^Name:.*lenovo-d330-fix" "$RPM_SPEC" 2>/dev/null; then
        ok "RPM spec: lenovo-d330-fix valid"
    else
        bad "RPM spec missing 'Name: lenovo-d330-fix' in $RPM_SPEC"
    fi
    if bash -n "$ARCH_PKG" 2>/dev/null; then
        ok "Arch PKGBUILD bash syntax valid"
    else
        bad "Arch PKGBUILD failed bash -n: $ARCH_PKG"
    fi
}

case "$MODE" in
    probe)
        echo "--- 1. Packaging Recipe Verification ---"
        require_file "$DEB_CTRL" "Debian control file"
        require_file "$RPM_SPEC" "RPM spec file"
        require_file "$ARCH_PKG" "Arch PKGBUILD"
        echo ""
        echo "--- 2. Syntax Validation ---"
        validate_fields
        ;;
    dry-run)
        echo "[DRY-RUN] Validating packaging metadata syntax (no install)..."
        validate_fields
        echo "[DRY-RUN] Syntax validation complete."
        ;;
esac

if [ "$FAILED" -gt 0 ]; then
    echo "[FAIL] ${FAILED} packaging check(s) failed." >&2
    exit 1
fi

echo "=========================================================="
echo " Packaging validation finished successfully.             "
echo "=========================================================="
