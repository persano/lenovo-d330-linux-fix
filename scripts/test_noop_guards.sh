#!/usr/bin/env bash
# ==============================================================================
# scripts/test_noop_guards.sh
#
# Machine-checkable honesty harness for the D330 tools (Phase 37, audit M4/M5/M17).
#
# Asserts that no shipped tool reports success for work it did not do:
#   (a) the no-op PWM boot service is gone from the tree AND not deployed by
#       scripts/install_dkms.sh;
#   (b) `d330-backlight-pwm.py --apply` exits non-zero and prints no [OK] on a
#       PATH without `intel_reg` (no false success without a register write);
#   (c) `d330-sensor-filter.py` does not self-terminate: a `--monitor` run is
#       still alive after 60 s (killed by `timeout`, rc 124), proving SC1;
#   (d) `d330-backlight-pwm.py --apply` read-back delta: [OK] when a stub
#       `intel_reg` write changes the value, [FAIL] + non-zero when it does not
#       (also exercises the `name (0xADDR): 0xVALUE` value parser, CR-01).
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
        echo "  (a) absent + undeployed: $SERVICE in $INSTALLER"
        echo "  (b) $PWM_TOOL --apply non-zero and no [OK] without intel_reg"
        echo "  (c) $FILTER_TOOL --monitor still alive after $((LIVENESS_TIMEOUT - 2))s (timeout rc 124)"
        echo "  (d) $PWM_TOOL --apply [OK] on a delta / [FAIL] with no delta (stub intel_reg)"
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
# (a) no-op PWM boot service removed from tree + installer deploy manifest
# ------------------------------------------------------------------------------
if [ -e "$SERVICE" ]; then
    fail "PWM boot service still present: $SERVICE"
elif grep -qE '/etc/systemd/system/lenovo-d330-backlight-pwm\.service([[:space:]]|$)' "$INSTALLER"; then
    # Match only a deployed manifest path (the dangling-reference form). The
    # WR-08 migration deliberately names the retired unit on a `find -delete`
    # cleanup line; that is a removal, not a deploy, and must not fail here.
    fail "installer still deploys lenovo-d330-backlight-pwm.service"
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
    # A fresh EMPTY dir as the sole PATH: python3 is still invoked by absolute
    # path, but no `intel_reg` can be found (even when it co-locates with
    # python3 in /usr/bin), so the guard can never touch a real MMIO register.
    empty_path="$(mktemp -d "${TMPDIR:-/tmp}/d330-noop-path.XXXXXX")"
    unset INTEL_REG D330_INTEL_REG
    pwm_out="$(PATH="$empty_path" "$PY3" "$PWM_TOOL" --apply 2>&1)"
    pwm_rc=$?
    rm -rf "$empty_path"
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

# ------------------------------------------------------------------------------
# (d) read-back delta verification (the actual M4 fix, untested until now):
#     the tool must print [OK] when the write changes the register and
#     [FAIL]+non-zero when it does not. A stub `intel_reg` emulates the real
#     `name (0xADDR): 0xVALUE` output format, so this also exercises the parser
#     (CR-01: value after the last ':', never the address).
# ------------------------------------------------------------------------------
if [ -z "$PY3" ]; then
    fail "python3 not available; cannot run the PWM delta checks"
else
    stub_dir="$(mktemp -d "${TMPDIR:-/tmp}/d330-stub.XXXXXX")"
    stub="$stub_dir/intel_reg"
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
# Stub `intel_reg`: emulates `name (0xADDR): 0xVALUE` read output. A `write`
# stores the value unless D330_STUB_IGNORE_WRITE=1 (the no-delta variant).
state="${D330_STUB_STATE:?}"
action="${1:-}"
shift || true
if [ "$action" = "write" ]; then
    if [ "${D330_STUB_IGNORE_WRITE:-0}" = "1" ]; then
        exit 0
    fi
    printf '%s\n' "$2" > "$state"
    exit 0
fi
addr="${1:-0x0}"
if [ -e "$state" ]; then
    val="$(cat "$state")"
else
    val="${D330_STUB_INITIAL:-0x64}"
fi
printf 'BXT_BLC_PWM_FREQ1 (%s): %s\n' "$addr" "$val"
STUB
    chmod +x "$stub"

    # (d1) write changes the value -> verified delta -> [OK], rc 0.
    st1="$stub_dir/state-delta"
    d1_out="$(PATH="$stub_dir:$PATH" D330_STUB_STATE="$st1" D330_STUB_INITIAL=0x64 "$PY3" "$PWM_TOOL" --apply 2>&1)"
    d1_rc=$?
    if [ "$d1_rc" -eq 0 ] && printf '%s' "$d1_out" | grep -q '\[OK\]'; then
        ok "pwm-readback-delta-ok (rc=$d1_rc)"
    else
        fail "PWM --apply did not report [OK] on a verified delta (rc=$d1_rc): $d1_out"
    fi

    # (d2) write leaves the value unchanged -> no delta -> [FAIL], rc non-zero.
    st2="$stub_dir/state-nodelta"
    d2_out="$(PATH="$stub_dir:$PATH" D330_STUB_STATE="$st2" D330_STUB_INITIAL=0x64 D330_STUB_IGNORE_WRITE=1 "$PY3" "$PWM_TOOL" --apply 2>&1)"
    d2_rc=$?
    if [ "$d2_rc" -ne 0 ] && printf '%s' "$d2_out" | grep -q '\[FAIL\]'; then
        ok "pwm-readback-no-delta-fail (rc=$d2_rc)"
    else
        fail "PWM --apply did not report [FAIL]+non-zero on an unchanged register (rc=$d2_rc): $d2_out"
    fi

    rm -rf "$stub_dir"
fi

echo ""
echo "=========================================================="
echo " No-op guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
