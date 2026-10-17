#!/usr/bin/env bash
# ==============================================================================
# scripts/capture_dsi_dumps.sh
#
# Phase 47 per-arm DSI MMIO capture helper (MMIO-01, D-03 / D-04).
#
# Drives the CI-built debugfs snapshot node /sys/kernel/debug/dri/0/i915_dsi_regs
# (patch: patches/d330_dsi_dump.patch, branch instrument/d330-dsi-dump):
#   echo 1  -> node walks the locked display MMIO ranges ONCE into a frozen
#              kernel-side buffer (values frozen at trigger time; snapshot
#              semantics, so a slow cat can never leak past the 18 s window)
#   echo 2  -> unchanged MMIO walk PLUS the phase-50 DCS ID-read section
#              (# DCS ID READ, five LP-mode ID reads, 50-01 node); the
#              trigger write here is wrapped in `timeout -k 5 15`, which
#              bounds interruptible hangs (TERM then KILL). The load-bearing
#              bound is the kernel's 50 ms x 2 per-read waits (50-01); a
#              true D-state kernel sleep cannot be bounded from userspace
#              (locked decision)
#   cat     -> emits that frozen buffer
#
# Zero register writes, no mode changes: the helper only triggers the node's
# own read-only walk. Idempotent: safe to re-run (a re-run replaces the
# snapshot buffer contents; a re-capture replaces the arm's output file).
#
# Usage:
#   capture_dsi_dumps.sh <boot|resume|boot2|resume2> [outdir]
#
#     <arm>      boot   fresh-boot reference (GOP-handover state, panel shows
#                       an image; taken BEFORE any suspend and with no
#                       intervening user modeset per assumption A5)
#                resume S3-resume failure state (panel confirmed BLACK by the
#                       user's eyes; trigger must land within 18 s of wake)
#                boot2  echo-2 capture at the boot arm (MMIO walk + DCS reads)
#                resume2 echo-2 capture at the resume arm (same, timeout-wrapped)
#     [outdir]   directory for <arm>_dsi_regs.txt
#                (default: invoking user's home, i.e. $SUDO_USER, + /d330_dsi_capture)
#
# Output contract checked here (pinned to 47-01's dump format):
#   # RANGE 0x<lo>-0x<hi> (<N> words)  section header per walked range
#   0x<offset>=<8 hex digits>          one record per walked word
#   # SKIPPED: DSI PLL off - DSI block reads skipped
#   # SKIPPED: DSI PLL off - PHY reads skipped
#                                      replace the DSI-block / DSI-PHY
#                                      section's RANGE header when the
#                                      BSpec machine-hang gate trips
#   # NAMED OVERLAY                    rows start with NAME, never match ^0x
#   # DCS ID READ                      phase-50 echo-2 section header, emitted
#                                      strictly AFTER the NAMED OVERLAY;
#                                      echo-1 arms (boot/resume) never emit it,
#                                      so all 47/49 captures stay valid
#   DCS <tag> ret=<n> avail=<0|1> data=<3 hex bytes>
#                                      one row per ID read (tags 0x04 / 0xDA /
#                                      0xDB / 0xDC / GEN00); the leading DCS
#                                      keeps rows out of the ^0x record regex
#                                      like NAME does; ret is the raw transfer
#                                      return value (ALWAYS >= 4 on this host,
#                                      never trust it alone), avail is the
#                                      GEN_READ_DATA_AVAIL post-check (bit 29
#                                      of MIPI_INTR_STAT(A)) that discriminates
#                                      answered-vs-dead
#   DCS SKIP <reason>                  emitted instead of any read row when the
#                                      node skips the reads (PLL off, no DSI
#                                      device); accepted but loudly warned
# Expected per-section word counts: 1024 / 4096 / 1024 / 128 / 1024
# (= 7296 record lines when the DSI block is read; 6272 with the deployed
#  30f077c PLL-off skip of the DSI block alone; 2176 once the post-review
#  gate also skips the PHY walk - both variants accepted, keyed off the
#  skip-marker count, which counts both marker spellings).
#
# Failure policy (loud, before any kit registration):
#   - missing node / debugfs          -> exit 1 (device not on the dump kernel)
#   - empty dump                      -> exit 1
#   - < 5000 record lines, no skip    -> exit 1 (truncated dump)
#   - missing DSI section, no skip    -> exit 1 (corrupted section header)
#   - per-section count mismatch      -> loud warning, capture still delivered
#   - < 5000 record lines WITH the PLL-off skip marker -> loud warning only
#   - echo-2 arms only: the trigger write is wrapped in `timeout -k 5 15`
#     (failure/timeout -> exit 1 with the captured stderr; bounds
#     interruptible hangs - the load-bearing bound is the kernel's 50 ms x 2
#     per-read waits, and a true D-state kernel sleep is unbounded from
#     userspace by design) and the dump MUST carry the
#     `# DCS ID READ` section with five DCS rows (or an explicit DCS SKIP
#     annotation, accepted as a loud warning) -> a missing section or a
#     short section exits non-zero like a truncated dump
#
# v9.0 binding rules honored by construction: the helper never triggers
# suspend/resume and never needs eyes; the user runs every session step and
# owns the panel verdicts.
# ==============================================================================

set -euo pipefail

NODE="/sys/kernel/debug/dri/0/i915_dsi_regs"
RECORD_RE='^0x[0-9a-f]+=[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$'
SKIP_MARKER='# SKIPPED: DSI PLL off'
DSI_LO='6b000'
FLOOR_RECORDS=5000

# Locked walked scope (RESUME_CAPTURE_PROTOCOL.md:119-125) -> expected words.
ORDER=(6b000 160000 46000 c7200 138000)
declare -A EXPECTED=( [6b000]=1024 [160000]=4096 [46000]=1024 [c7200]=128 [138000]=1024 )
declare -A NAME=(
    [6b000]="DSI ports A+C block (0x6b000-0x6c000)"
    [160000]="BXT/GLK DSI PHY (0x160000-0x164000)"
    [46000]="CDCLK / DSI PLL / DE PLL (0x46000-0x47000)"
    [c7200]="legacy PPS (0xc7200-0xc7400)"
    [138000]="GT DISP PWRON / MIPIO_RST_CTRL (0x138000-0x139000)"
)

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <boot|resume|boot2|resume2> [outdir]

Trigger the CI-built D330 DSI MMIO snapshot node and capture one arm's dump.

  arm       'boot'    fresh-boot reference (panel shows the desktop image)
            'resume'  S3-resume failure state (panel BLACK, within 18 s of wake)
            'boot2'   echo-2 capture at the boot arm (MMIO walk + DCS ID reads)
            'resume2' echo-2 capture at the resume arm (same; the trigger is
                      wrapped in 'timeout -k 5 15', which bounds
                      interruptible hangs - a D-state kernel sleep stays
                      unbounded from userspace)
  outdir    output directory (default: \$SUDO_USER's home + /d330_dsi_capture)

Run as root (sudo). The node performs a read-only register walk; re-running
is always safe.
EOF
}

[ $# -ge 1 ] && [ $# -le 2 ] || { usage; exit 2; }
ARM="$1"
case "$ARM" in
    boot|resume|boot2|resume2) ;;
    *) log_err "arm must be 'boot', 'resume', 'boot2' or 'resume2' (got '$ARM')"; usage; exit 2 ;;
esac
case "$ARM" in
    boot2|resume2) ECHO=2 ;;
    *)             ECHO=1 ;;
esac

[ "$(id -u)" -eq 0 ] || {
    log_err "must run as root (sudo $(basename "$0") $ARM [outdir])"
    exit 1
}

# ---- (a) resolve the node ----------------------------------------------------
# The i915 card's debugfs minor can drift between boots (card0 vs card1: on
# 2026-10-14 the post-deploy boot enumerated i915 as card1/dri/1). Resolve the
# node across dri minors; prefer minor 0 when present. One i915 card per
# machine (D330), so the first hit is the node.
if [ ! -d /sys/kernel/debug/dri ]; then
    log_err "debugfs not mounted at /sys/kernel/debug (mount -t debugfs none /sys/kernel/debug, or check 'uname -r')"
    exit 1
fi
NODE=""
for cand in /sys/kernel/debug/dri/*/i915_dsi_regs; do
    [ -e "$cand" ] || continue
    case "$(basename "$(dirname "$cand")")" in
        0) NODE="$cand"; break ;;                     # canonical minor wins
        [0-9]*) [ -z "$NODE" ] && NODE="$cand" ;;     # keep first numeric minor
    esac
done
if [ -z "$NODE" ]; then
    log_err "node missing: no /sys/kernel/debug/dri/*/i915_dsi_regs found"
    log_err "device is not running the 47-01 dump kernel"
    log_err "(CI artifact linux-image-7.0.14-d330-fix, sha256 ba47df8d...fe87be; check 'uname -r' and 'journalctl -k | grep -i \"i915.*probe\"')"
    exit 1
fi
case "$NODE" in
    */dri/0/i915_dsi_regs) log_ok "node: $NODE" ;;
    *) log_warn "node at non-canonical minor: $NODE (i915 took card1 this boot; minor drift is a boot-order artifact)" ;;
esac

if [ $# -ge 2 ]; then
    OUTDIR="$2"
else
    if [ -n "${SUDO_USER:-}" ]; then
        OUTDIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)/d330_dsi_capture"
    else
        OUTDIR="$PWD/d330_dsi_capture"
    fi
fi
mkdir -p "$OUTDIR"
OUT="$OUTDIR/${ARM}_dsi_regs.txt"

# ---- (b) trigger -------------------------------------------------------------
# The write is synchronous: it returns only after the walk finished and the
# D330DSIREG confirmation line is in the ring. Timestamps feed the session
# record (threat T-47-14 elapsed-context evidence).
TRIG_TIME="$(date '+%F %T %z')"
T0="$(date +%s)"

BEFORE=$(dmesg 2>/dev/null | grep -c 'D330DSIREG' || true)
ERRFILE="$(mktemp)"
if [ "$ECHO" -eq 2 ]; then
    # Echo-2 arms: timeout-wrapped trigger (locked decision, T-50-04) - TERM
    # at 15 s, KILL at 20 s bounds interruptible hangs. The load-bearing bound
    # is the kernel side (50-01: two 50 ms waits per DCS read); a write stuck
    # in D-state ignores TERM/KILL and stays unbounded from userspace.
    if ! timeout -k 5 15 sh -c "echo 2 > '$NODE'" 2>"$ERRFILE"; then
        log_err "echo-2 trigger failed or timed out after 15 s: $(cat "$ERRFILE")"
        log_err "(EBUSY would mean another trigger is in flight; a timeout means the DSI read path wedged - do NOT retry blindly, capture the dmesg first)"
        rm -f "$ERRFILE"
        exit 1
    fi
elif ! echo 1 > "$NODE" 2>"$ERRFILE"; then
    log_err "trigger failed: $(cat "$ERRFILE")"
    log_err "(EBUSY would mean another trigger is in flight; retry in a moment)"
    rm -f "$ERRFILE"
    exit 1
fi
rm -f "$ERRFILE"
log_ok "trigger written at $TRIG_TIME"

# ---- (c) wait up to 10 s for the D330DSIREG confirmation line ----------------
CONFIRMED=""
i=0
while [ "$i" -lt 20 ]; do
    NOW_COUNT=$(dmesg 2>/dev/null | grep -c 'D330DSIREG' || true)
    if [ "$NOW_COUNT" -gt "$BEFORE" ]; then
        CONFIRMED="$(dmesg | grep 'D330DSIREG' | tail -1)"
        break
    fi
    sleep 0.5
    i=$((i + 1))
done
if [ -z "$CONFIRMED" ]; then
    log_warn "no D330DSIREG confirmation line seen within 10 s (dmesg restricted or ring wrapped)"
    log_warn "continuing to cat anyway - the trigger write itself was synchronous"
else
    log_ok "dmesg: $CONFIRMED"
    T1="$(date +%s)"
    log_info "trigger -> confirmation elapsed: $((T1 - T0)) s"
fi

# ---- (d) cat the frozen buffer ------------------------------------------------
if ! cat "$NODE" > "$OUT"; then
    log_err "cat failed writing $OUT"
    exit 1
fi

SIZE=$(stat -c '%s' "$OUT" 2>/dev/null || stat -f '%z' "$OUT")
LINES=$(wc -l < "$OUT")
RECORDS=$(grep -cE "$RECORD_RE" "$OUT" || true)
SKIPS=$(grep -cF "$SKIP_MARKER" "$OUT" || true)

# ---- (e) checksum -------------------------------------------------------------
HASH=$(sha256sum "$OUT" | awk '{print $1}')
log_ok "dump written: $OUT ($SIZE bytes, $LINES lines, $RECORDS record lines)"
log_ok "sha256: $HASH"

# ---- (f) per-section record counts vs expected word counts --------------------
echo "[INFO] per-section counts:"
awk -v rec="$RECORD_RE" '
    /^# RANGE /          { split($3, b, "-"); cur=substr(b[1], 3); next }
    /^# SKIPPED:/        { cur=""; skip++; print "  SKIP-MARKER: " $0; next }
    /^# /                { cur=""; next }
    $0 ~ rec {
        if (cur != "") cnt[cur]++
        next
    }
    END {
        for (k in cnt) printf "SECTION %s %d\n", k, cnt[k]
        printf "SKIPCOUNT %d\n", skip + 0
    }
' "$OUT" > "$OUT.sections.$$"

SKIPCOUNT=$(awk '/^SKIPCOUNT /{print $2}' "$OUT.sections.$$")
declare -A ACTUAL
while read -r _ lo n; do
    [ -n "${lo:-}" ] && ACTUAL[$lo]=$n
done < "$OUT.sections.$$"
rm -f "$OUT.sections.$$"

MISSING_DSI=""
for lo in "${ORDER[@]}"; do
    exp="${EXPECTED[$lo]}"
    act="${ACTUAL[$lo]:-0}"
    if [ "$act" -eq "$exp" ]; then
        echo "  [OK]   ${NAME[$lo]}: $act/$exp records"
    elif [ "$act" -eq 0 ]; then
        echo "  [MISS] ${NAME[$lo]}: 0/$exp records"
        [ "$lo" = "$DSI_LO" ] && MISSING_DSI=1
    else
        echo "  [DIFF] ${NAME[$lo]}: $act/$exp records (MISMATCH)"
    fi
done

if [ "$SKIPCOUNT" -gt 0 ]; then
    log_warn "PLL-off skip marker(s) present ($SKIPCOUNT): the gated DSI-block and/or DSI-PHY sections are intentionally unreadable (BSpec machine-hang gate) - only acceptable together with the marker(s), which are present"
fi

# ---- (g) floor / emptiness gates ----------------------------------------------
rc=0
if [ "$RECORDS" -eq 0 ] || [ "$SIZE" -eq 0 ]; then
    log_err "dump is EMPTY - capture failed before any kit registration"
    rc=1
elif [ "$RECORDS" -lt "$FLOOR_RECORDS" ] && [ "$SKIPCOUNT" -eq 0 ]; then
    log_err "record lines below floor: $RECORDS < $FLOOR_RECORDS (truncated dump - caught BEFORE registration)"
    rc=1
elif [ "$RECORDS" -lt "$FLOOR_RECORDS" ] && [ "$SKIPCOUNT" -gt 0 ]; then
    log_warn "record lines below floor: $RECORDS < $FLOOR_RECORDS, but the PLL-off skip marker explains the missing DSI section"
fi

if [ -n "$MISSING_DSI" ] && [ "$SKIPCOUNT" -eq 0 ]; then
    log_err "DSI section (0x$DSI_LO) missing WITHOUT the PLL-off skip marker - corrupted section header, dump invalid"
    rc=1
fi

# ---- (g2) echo-2 DCS ID READ section validation --------------------------------
# The 50-01 node guarantees, in an echo-2 dump: the '# DCS ID READ' header
# and either five DCS-prefixed read rows or an explicit 'DCS SKIP <reason>'
# annotation. A missing/short section is format drift - fail loudly, like a
# truncated dump, BEFORE any kit registration. Echo-1 arms never emit the
# section and are not checked here.
if [ "$ECHO" -eq 2 ]; then
    DCS_HEADER=$(grep -c '^# DCS ID READ$' "$OUT" || true)
    DCS_SKIPROWS=$(grep -c '^DCS SKIP ' "$OUT" || true)
    DCS_ROWS=$(grep -cE '^DCS (0x04|0xDA|0xDB|0xDC|GEN00) ret=' "$OUT" || true)
    if [ "$DCS_HEADER" -eq 0 ]; then
        log_err "'# DCS ID READ' section MISSING from an echo-2 dump - format drift vs the 50-01 node (dump invalid, caught BEFORE registration)"
        rc=1
    elif [ "$DCS_SKIPROWS" -gt 0 ]; then
        log_warn "DCS SKIP annotation present ($DCS_SKIPROWS row(s)) - the node skipped the ID reads; accepted, but register WHY in the session log before trusting the arm"
    elif [ "$DCS_ROWS" -ne 5 ]; then
        log_err "DCS ID READ section present but $DCS_ROWS read rows, expected 5 (tags 0x04/0xDA/0xDB/0xDC/GEN00) - short section, dump invalid"
        rc=1
    else
        log_ok "DCS ID READ section validated: header + 5 read rows"
    fi
fi

if [ "$rc" -eq 0 ]; then
    log_ok "arm '$ARM' capture complete and floor-checked"
else
    log_err "arm '$ARM' capture FAILED the checks above - do NOT register this dump; re-run the arm"
fi

echo "[INFO] ---- capture record (paste into the session log) ----"
echo "arm=$ARM trigger_time=$TRIG_TIME out=$OUT"
echo "sha256=$HASH"
echo "bytes=$SIZE lines=$LINES records=$RECORDS skipped_sections=$SKIPCOUNT"

exit "$rc"
