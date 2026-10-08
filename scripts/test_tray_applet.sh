#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL System Tray Applet Verification Script
#
# SC1: this harness must FAIL (non-zero) when the tray wiring is wrong -- e.g.
# the autostart `Exec=` points at a binary the installer never deploys. It also
# guards the tablet systemd USER unit shape and the no-cwd-fallback rule.

set -uo pipefail

MODE="probe"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DESKTOP="patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop"
INSTALLER="scripts/install_dkms.sh"
TRAY_PY="tools/d330-tray.py"
DAEMON_USER_UNIT="patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service"
DAEMON_SYS_UNIT="patches/dock/etc/systemd/system/d330-tablet-daemon.service"

show_help() {
    cat << 'EOF'
Usage: scripts/test_tray_applet.sh [OPTIONS]

Options:
  --probe          Inspect tray script, desktop autostart and user unit (default)
  --dry-run        Validate tray applet logic only
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)   MODE="probe"; shift ;;
        --dry-run) MODE="dry-run"; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL System Tray Applet Test Tool           "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying tray applet..."
    rc=0
    python3 tools/d330-tray.py --status || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "[DRY-RUN] FAIL: tray --status exited $rc"
        exit 1
    fi
    echo "[DRY-RUN] Verification complete."
    exit 0
fi

PASSED=0
FAILED=0
ok()   { echo "  [OK] $1";   PASSED=$((PASSED + 1)); }
bad()  { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }

# --- SC1: autostart Exec must equal the binary the installer deploys ---
desktop_exec=""
if [ -f "$DESKTOP" ]; then
    desktop_exec="$(grep -E '^Exec=' "$DESKTOP" | head -n1 | cut -d= -f2- | awk '{print $1}')"
fi

installed_name=""
if [ -f "$INSTALLER" ]; then
    installed_name="$(grep -A2 'tools/d330-tray\.py' "$INSTALLER" \
        | grep -oE '/usr/local/bin/d330-tray[a-zA-Z0-9._-]*' | head -n1)"
fi

if [ ! -f "$DESKTOP" ]; then bad "desktop entry missing: $DESKTOP"; else ok "desktop entry exists"; fi
if [ ! -f "$INSTALLER" ]; then bad "installer missing: $INSTALLER"; else ok "installer exists"; fi

if [ -n "$desktop_exec" ] && [ -n "$installed_name" ] && [ "$desktop_exec" = "$installed_name" ]; then
    ok "autostart Exec matches deployed binary ($desktop_exec)"
else
    bad "autostart Exec '$desktop_exec' != deployed binary '$installed_name' (SC1)"
fi

# --- tray.py must not keep cwd-relative tools/d330-* fallbacks ---
if [ -f "$TRAY_PY" ]; then
    if grep -q 'tools/d330-' "$TRAY_PY"; then
        bad "tray.py still has a cwd-relative tools/d330- fallback"
    else
        ok "tray.py has no cwd-relative tools/d330- fallback"
    fi
else
    bad "tray.py missing: $TRAY_PY"
fi

# --- tablet daemon must be a systemd USER unit only ---
if [ -f "$DAEMON_USER_UNIT" ] && grep -q '^WantedBy=default\.target' "$DAEMON_USER_UNIT"; then
    ok "tablet daemon user unit present (WantedBy=default.target)"
else
    bad "tablet daemon user unit missing or lacks WantedBy=default.target"
fi
if [ -e "$DAEMON_SYS_UNIT" ]; then
    bad "legacy system unit still present: $DAEMON_SYS_UNIT"
else
    ok "no legacy system unit file"
fi
if [ -f "$INSTALLER" ] && grep -qF '/etc/systemd/system/d330-tablet-daemon.service' "$INSTALLER"; then
    bad "installer still references /etc/systemd/system/d330-tablet-daemon.service"
else
    ok "installer has no system-unit path reference"
fi
if [ -f "$INSTALLER" ] && grep -qF 'systemctl --global enable d330-tablet-daemon' "$INSTALLER"; then
    ok "installer enables the user unit globally"
else
    bad "installer does not run 'systemctl --global enable d330-tablet-daemon'"
fi

# --- CLI status must run cleanly ---
if python3 tools/d330-tray.py --status >/dev/null 2>&1; then
    ok "tray --status exits 0"
else
    bad "tray --status exited non-zero"
fi

echo "----------------------------------------------------------"
echo " Tray applet checks: passed=$PASSED failed=$FAILED"
echo "=========================================================="

if [ "$FAILED" -gt 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
exit 0
