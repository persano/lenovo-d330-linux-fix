#!/usr/bin/env bash
# ==============================================================================
# scripts/tcon_i2c_sweep.sh
#
# Phase 50 I2C sideband sweep (TCON-03): archives everything the sideband
# conclusion needs into ONE kit-ready file in a single root run, so 50-04's
# device session is one command.
#
# Archives, in order:
#   - timestamped header + tool provenance (i2cdetect/gpioinfo versions, with
#     an honest note when a tool is absent and its section degrades to sysfs)
#   - bus inventory from BOTH `i2cdetect -l` and /sys/bus/i2c/devices name
#     reads (bus list is derived dynamically - never a hardcoded range; the
#     research's seq 0 9 is a floor, not a bound)
#   - per-bus `i2cdetect -y <n>` for every enumerated bus (standard quick-
#     write probes only, i2cdetect default - threat T-50-06)
#   - `gpioinfo` filtered for panel/backlight/reset/PMIC rail claims, with
#     the unfiltered line count so the filter stays auditable
#   - `dmesg` lines for PMIC / I2C controller enumeration
#   - sha256 of the archive + the capture-script session record block
#
# Failure policy (loud, but never fatal mid-sweep):
#   - not root                    -> exit 1
#   - every probe is `|| true`    -> one dead/busy adapter must never abort
#     the sweep; degradation is noted inline in the archive, never silent
#   - tool absent                 -> honest "(not installed, degrading to
#     sysfs)" note in the archive, sweep continues (Assumption A4)
#
# Usage:
#   tcon_i2c_sweep.sh [outdir]
#
# Honest boundary (Pitfall 5): this archives KERNEL-ERA I2C traffic and
# topology only. Pre-kernel GOP I2C activity is invisible here - proving
# that negative needs the Phase 53 logic analyzer, not this script.
#
# v9.0/v10.0 rules honored by construction: no suspend/resume triggered, no
# register writes, read-only probes; the user runs every session step.
# ==============================================================================

set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [outdir]

One-run I2C sideband archive (TCON-03): bus inventory, per-bus i2cdetect,
gpioinfo panel/PMIC rail claims, dmesg controller lines - one kit-ready file.

  outdir    output directory (default: \$SUDO_USER's home + /d330_dsi_capture)

Run as root (sudo). Every probe is failure-tolerant; a dead bus is archived
as such and the sweep continues. Registers afterwards with:
  scripts/prepare_safety_kit.sh --register <outdir>/i2c_sweep.txt
EOF
}

[ $# -le 1 ] || { usage; exit 2; }

[ "$(id -u)" -eq 0 ] || {
    log_err "must run as root (sudo $(basename "$0") [outdir])"
    exit 1
}

if [ $# -ge 1 ]; then
    OUTDIR="$1"
else
    if [ -n "${SUDO_USER:-}" ]; then
        OUTDIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)/d330_dsi_capture"
    else
        OUTDIR="$PWD/d330_dsi_capture"
    fi
fi
mkdir -p "$OUTDIR"
OUT="$OUTDIR/i2c_sweep.txt"

SWEEP_TIME="$(date '+%F %T %z')"

{
    echo "# I2C SWEEP $SWEEP_TIME (phase 50 TCON sideband, TCON-03)"
    echo "# kernel: $(uname -r)"

    # ---- tool provenance (Assumption A4: degrade honestly) -------------------
    echo "== tool provenance"
    if command -v i2cdetect >/dev/null 2>&1; then
        echo "i2cdetect: $(i2cdetect --version 2>&1 | head -1)"
    else
        echo "i2cdetect: NOT INSTALLED - bus inventory degrades to sysfs only; per-bus probes unavailable"
    fi
    if command -v gpioinfo >/dev/null 2>&1; then
        echo "gpioinfo: $(gpioinfo --version 2>&1 | head -1)"
    else
        echo "gpioinfo: NOT INSTALLED - rail-claim section degrades to sysfs only"
    fi

    # ---- bus inventory: BOTH sources, dynamic range --------------------------
    echo "== i2cdetect -l (adapter inventory)"
    i2cdetect -l 2>/dev/null || echo "(i2cdetect -l failed or unavailable)"
    echo "== /sys/bus/i2c/devices (name reads)"
    shopt -s nullglob
    for d in /sys/bus/i2c/devices/i2c-*; do
        name=""
        [ -r "$d/name" ] && name="$(cat "$d/name" 2>/dev/null || true)"
        echo "$d name=${name:-<unreadable>}"
    done
    shopt -u nullglob

    # ---- per-bus probe: bus list derived, never a hardcoded seq --------------
    BUSES="$( {
        i2cdetect -l 2>/dev/null | awk '{print $1}' | sed 's/^i2c-//' || true
        for d in /sys/bus/i2c/devices/i2c-*; do
            basename "$d" | sed 's/^i2c-//'
        done
    } | grep -E '^[0-9]+$' | sort -un )"
    echo "== enumerated buses: $(echo "$BUSES" | tr '\n' ' ')"
    for n in $BUSES; do
        echo "== i2cdetect -y $n"
        i2cdetect -y "$n" 2>&1 || echo "(i2cdetect -y $n failed - dead/busy adapter archived, sweep continues)"
    done

    # ---- gpioinfo rail claims (filtered + auditable count) -------------------
    echo "== gpioinfo (panel/backlight/reset/PMIC claims)"
    if command -v gpioinfo >/dev/null 2>&1; then
        gpioinfo_out="$(gpioinfo 2>/dev/null || true)"
        echo "gpioinfo unfiltered line count: $(printf '%s\n' "$gpioinfo_out" | grep -c . || true)"
        printf '%s\n' "$gpioinfo_out" | grep -iE 'panel|backlight|bklt|reset|pmic|INT33FF' \
            || echo "(no panel/backlight/reset/PMIC claims matched)"
    else
        echo "(gpioinfo not installed - rail claims unavailable; install libgpiod-tools)"
    fi

    # ---- dmesg PMIC / I2C controller enumeration ------------------------------
    echo "== dmesg (PMIC / I2C controller lines)"
    dmesg 2>/dev/null | grep -iE 'pmic|INT33FF|i2c_designware|i2c i2c-[0-9]+:' \
        || echo "(no matching dmesg lines - dmesg restricted or ring wrapped)"

    echo "# END OF SWEEP - kernel-era traffic only; pre-kernel GOP I2C is"
    echo "# invisible here (needs the Phase 53 logic analyzer)."
} > "$OUT" 2>&1

HASH=$(sha256sum "$OUT" | awk '{print $1}')
SIZE=$(stat -c '%s' "$OUT" 2>/dev/null || stat -f '%z' "$OUT")
LINES=$(wc -l < "$OUT")
log_ok "sweep archived: $OUT ($SIZE bytes, $LINES lines)"
log_ok "sha256: $HASH"

echo "[INFO] ---- capture record (paste into the session log) ----"
echo "script=tcon_i2c_sweep out=$OUT sweep_time=$SWEEP_TIME"
echo "sha256=$HASH"
echo "bytes=$SIZE lines=$LINES"
