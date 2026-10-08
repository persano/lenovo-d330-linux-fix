#!/usr/bin/env bash
# ==============================================================================
# scripts/test_noop_guards.sh
#
# Machine-checkable honesty harness for the D330 tools (Phase 37, audit M4/M5/M17).
#
# Asserts that no shipped tool reports success for work it did not do:
#   (a) the no-op PWM boot service is gone from the tree AND unreferenced by
#       scripts/install_dkms.sh;
#   (b) `d330-backlight-pwm.py --apply` exits non-zero and prints no [OK] on a
#       PATH without `intel_reg` (no false success without a register write);
#   (c) `d330-sensor-filter.py` does not self-terminate: a `--monitor` run is
#       still alive after 60 s (killed by `timeout`, rc 124), proving SC1.
#
# Modes: default runs every check; `--probe` prints what it would check.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

SERVICE="patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service"
INSTALLER="scripts/install_dkms.sh"
PWM_TOOL="tools/d330-backlight-pwm.py"
FILTER_TOOL="tools/d330-sensor-filter.py"
LIVENESS_TIMEOUT=62   # > 60 s liveness proof (SC1)

case "${1:-}" in
    --probe)
        echo "noop-guards would check:"
        echo "  (a) absent + unreferenced: $SERVICE in $INSTALLER"
        echo "  (b) $PWM_TOOL --apply non-zero and no [OK] without intel_reg"
        echo "  (c) $FILTER_TOOL --monitor still alive after $((LIVENESS_TIMEOUT - 2))s (timeout rc 124)"
        exit 0
        ;;
    -h|--help)
        cat <<'EOF'
Usage: scripts/test_noop_guards.sh [--probe]

  --probe   Print the checks without running them.
EOF
        exit 0
        ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

echo "=========================================================="
echo " Lenovo D330 No-Op Guard Suite (honesty harness)          "
echo "=========================================================="

passed=0
failed=0
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }
ok()   { echo "  [OK] $1"; passed=$((passed + 1)); }

# ------------------------------------------------------------------------------
# (a) no-op PWM boot service removed from tree + installer manifest
# ------------------------------------------------------------------------------
if [ -e "$SERVICE" ]; then
    fail "PWM boot service still present: $SERVICE"
elif grep -q "lenovo-d330-backlight-pwm.service" "$INSTALLER"; then
    fail "installer still references lenovo-d330-backlight-pwm.service"
else
    ok "pwm-service-removed"
fi

# ------------------------------------------------------------------------------
# (b) --apply never claims success without a verified register write
# ------------------------------------------------------------------------------
PY3="$(command -v python3 || true)"
if [ -z "$PY3" ]; then
    fail "python3 not available; cannot run the PWM honesty check"
else
    PYDIR="$(dirname "$PY3")"
    unset INTEL_REG D330_INTEL_REG
    pwm_out="$(PATH="$PYDIR" "$PY3" "$PWM_TOOL" --apply 2>&1)"
    pwm_rc=$?
    if [ "$pwm_rc" -eq 0 ]; then
        fail "PWM --apply exited 0 on a PATH without intel_reg"
    elif printf '%s' "$pwm_out" | grep -q '\[OK\]'; then
        fail "PWM --apply printed [OK] without a verified register write"
    else
        ok "pwm-no-false-success (rc=$pwm_rc)"
    fi
fi

# ------------------------------------------------------------------------------
# (c) sensor filter liveness: must not self-terminate before 62 s
# ------------------------------------------------------------------------------
if [ -z "$PY3" ]; then
    fail "python3 not available; cannot run the sensor liveness check"
else
    iio_tmp="$(mktemp -d "${TMPDIR:-/tmp}/d330-noop.XXXXXX")"
    dev="$iio_tmp/iio:device0"
    mkdir -p "$dev"
    # A fake accelerometer keeps the filter from early-returning on "no sensors".
    printf 'bosc0200\n' > "$dev/name"
    printf '100\n' > "$dev/in_accel_x_raw"
    printf '0\n' > "$dev/in_accel_y_raw"
    printf '0\n' > "$dev/in_accel_z_raw"
    D330_IIO_BASE="$iio_tmp" timeout "$LIVENESS_TIMEOUT" "$PY3" "$FILTER_TOOL" --monitor >/dev/null 2>&1
    live_rc=$?
    rm -rf "$iio_tmp"
    if [ "$live_rc" -eq 124 ]; then
        ok "sensor-filter-alive->60s (timeout rc=124)"
    else
        fail "sensor filter exited on its own (rc=$live_rc; expected timeout 124)"
    fi
fi

echo ""
echo "=========================================================="
echo " No-op guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
