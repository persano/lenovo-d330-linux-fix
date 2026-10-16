#!/usr/bin/env bash
# ==============================================================================
# scripts/test_dsi_mmio_evidence.sh
#
# Phase 47 static evidence guard suite (MMIO-01 / MMIO-02, D-05 / D-07 / D-08).
# Holds docs/research/DSI_MMIO_DIFF.md to the locked evidence standard and the
# checksummed RE kit to the capture contract, without root or hardware:
#
#   1. mmio-kit-verify            docs/dumps/re_kit sha256 verify (pristine-first;
#                                 runs FIRST so nothing is judged on a tampered kit)
#   2. mmio-kit-manifest-covers   MANIFEST names both dumps + the diff artifact
#   3. mmio-diffdoc-citations     DSI_MMIO_DIFF.md has >= 10 file:line citation
#                                 anchors (D-07 bar)
#   4. mmio-exclusion-table       per-range exclusion table + >= 3 distinct
#                                 reason strings (D-06)
#   5. mmio-single-claim          exactly ONE mechanism-claim section, and the
#                                 claim text cites a 0x... offset (D-05)
#   6. mmio-handoff               "what to restore/replicate" section (D-08)
#   7. mmio-allow-markers         narrow planner-discipline-allow markers present
#                                 (derive them from the ledger's alias column)
#
# Modes:
#   (plain)         real mode: cases run against the repo as found. RED in waves
#                   1-2 by design — the kit entries (47-03) and the DIFF doc
#                   (47-04) land later; the plain run's red is the Nyquist
#                   RED->GREEN shape of this phase.
#   --fixtures      run cases 3-7's matching logic against an embedded fixture
#                   markdown that satisfies every case — proves the case logic
#                   now (backstop: the suite can actually fail and pass). Also
#                   proves the NEGATIVE direction: a second, contract-violating
#                   fixture must make the cases fail (non-vacuity backstop).
#   -h, --help      usage.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

KIT="docs/dumps/re_kit"
DIFFDOC="docs/research/DSI_MMIO_DIFF.md"

# Canonical exclusion reason anchors — the same table
# scripts/dsi_mmio_diff.sh:build_exclusions carries (47-04's doc mirrors it).
# Distinct = >= 3 of these appear in the doc's exclusion section.
REASON_ANCHORS=(
    'write-1-to-clear'
    'RX FIFO, pop-on-read'
    'GEN FIFO status'
    'PPS sequence state'
    'compositor-volatile surface state'
    'monotonic counters'
    'interrupt-enable mask'
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [--fixtures] [-h|--help]

Phase 47 DSI MMIO evidence guard suite.

  (plain)     run all 7 cases against the repo as found (RED until the
              47-03 kit entries and the 47-04 DIFF doc land - by design)
  --fixtures  prove cases 3-7 against the embedded fixture doc (exits 0)
EOF
}

MODE="real"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fixtures) MODE="fixtures"; shift ;;
        --fixtures-violating) MODE="fixtures-violating"; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done


echo "=========================================================="
echo " DSI MMIO Evidence Guard Suite (Phase 47)                 "
echo "=========================================================="

passed=0
failed=0

check() {
    local name="$1" cond="$2"
    if eval "$cond"; then
        echo "[OK] $name"
        passed=$((passed + 1))
    else
        echo "[FAIL] $name" >&2
        failed=$((failed + 1))
    fi
}

# doc_path as $1; real mode passes the repo DIFFDOC, fixtures mode the fixture.
run_doc_cases() {
    local doc="$1" c n claim_txt

    # Case 3: D-07 citation bar — >= 10 file:line anchors over both captures.
    c=$({ grep -oE 'boot_dsi_regs\.txt:[0-9]+|broken_dsi_regs\.txt:[0-9]+' "$doc" 2>/dev/null || true; } | wc -l)
    if [ ! -f "$doc" ]; then
        echo "  missing: $doc (produced by plan 47-04; registered in the kit by 47-03)" >&2
    fi
    check "mmio-diffdoc-citations (>=10 anchors)" "[ $c -ge 10 ]"

    # Case 4: D-06 — a per-range exclusion table heading + >= 3 distinct
    # canonical reason strings.
    c=0
    local a
    for a in "${REASON_ANCHORS[@]}"; do
        if grep -qF -- "$a" "$doc" 2>/dev/null; then c=$((c + 1)); fi
    done
    check "mmio-exclusion-table (heading + >=3 reasons; found $c reasons)" \
        "[ -f $doc ] && grep -qiE '^#+.*exclusion' $doc && [ $c -ge 3 ]"

    # Case 5: D-05 — exactly ONE mechanism-claim section heading, and the
    # claim text cites a 0x... register offset.
    c="$(grep -cE '^## .*(Mechanism|mechanism claim)' "$doc" 2>/dev/null || true)"
    claim_txt="$(awk '/^## .*(Mechanism|mechanism claim)/ {f=1; next} f && /^## / {f=0} f' "$doc" 2>/dev/null || true)"
    check "mmio-single-claim (exactly 1 heading + 0x offset in claim)" \
        "[ -f $doc ] && [ $c -eq 1 ] && grep -qE '0x[0-9a-f]+' <<< \"\$claim_txt\""

    # Case 6: D-08 — Phase-48 handoff section heading.
    check "mmio-handoff (what to restore/replicate section)" \
        "[ -f $doc ] && grep -qiE '^#+.*restore/replicate' $doc"

    # Case 7: narrow ledger-allow markers present (the doc needs them for
    # register names that are ledger aliases; absence fails loudly so the
    # 47-04 executor derives markers from the ledger's alias column).
    c="$(grep -c 'planner-discipline-allow:' "$doc" 2>/dev/null || true)"
    check "mmio-allow-markers (>=1 narrow marker)" "[ -f $doc ] && [ $c -ge 1 ]"
}

if [ "$MODE" = "fixtures-violating" ]; then
    # Internal backstop mode (invoked by --fixtures): run the doc cases against
    # a deliberately contract-violating fixture. Must exit non-zero.
    set +e
    FIXV="$(mktemp -d)"
    trap 'rm -rf "$FIXV"' EXIT
    cat > "$FIXV/violating.md" <<'VIOLATING'
<!-- planner-discipline-allow: 0x138090 -->

# Violating fixture

## Exclusion table (per range, with reasons)

- interrupt status (write-1-to-clear), volatile
- RX FIFO, pop-on-read side effect
- GEN FIFO status, read-only; level drains with link idle

## Raw diff rows

| offset | boot | resume | interpretation | verdict | citation |
|---|---|---|---|---|---|
| 0x6b004 | 00000000 | 40200000 | interrupt status | excluded-volatile | boot_dsi_regs.txt:912 |

## Mechanism claim

GOP sets 0x162024=8080e480 at boot; resume leaves 0x162024=00000000.

## Mechanism claim (duplicate - violates the ONE-claim rule)

GOP sets 0x162028=8080e480 at boot; resume leaves 0x162028=00000000.

VIOLATING
    run_doc_cases "$FIXV/violating.md"
    # a violating fixture MUST fail: exit 1 when any case caught the violation,
    # exit 0 only if every case wrongly passed (non-vacuity failure signal).
    if [ "$failed" -gt 0 ]; then exit 1; fi
    echo "[FAIL] violating fixture passed all cases (non-vacuity failure)" >&2
    exit 0
fi

if [ "$MODE" = "fixtures" ]; then
    FIX="$(mktemp -d)"
    trap 'rm -rf "$FIX"' EXIT
    cat > "$FIX/DSI_MMIO_DIFF.fixture.md" <<'FIXTURE'
<!-- planner-discipline-allow: 0x138090 -->
<!-- planner-discipline-allow: BXT_DSI_PLL_CTL -->

# DSI MMIO Diff (boot vs resume) — fixture

## Method

One CI-built debugfs dump node, both arms, one session. Diffs computed by
scripts/dsi_mmio_diff.sh; every row below cites offset + capture file + line.

## Exclusion table (per range, with reasons)

| offset(s) | reason |
|---|---|
| 0x6b004 / 0x6b804 / 0x6b090 | interrupt status (write-1-to-clear), volatile |
| 0x6b094 | interrupt-enable mask, config state; NOT W1C status |
| 0x6b118-0x6b137, 0x6b064 / 0x6b068 | RX FIFO, pop-on-read side effect |
| 0x6b074 | GEN FIFO status, read-only; level drains with link idle |
| 0xc7200 | PPS sequence state, timing-volatile |
| 0x70040-0x7004c, 0x7019c, 0x701ac | compositor-volatile surface state |
| 0x138070 / 0x138074, 0x45264-0x45308 | monotonic counters, not config |

## Raw diff rows

| offset | boot | resume | interpretation | verdict | citation |
|---|---|---|---|---|---|
| 0x6b004 | 00000000 | 40200000 | interrupt status (write-1-to-clear), volatile | excluded-volatile | boot_dsi_regs.txt:912; broken_dsi_regs.txt:940 |
| 0x6b104 | 00000401 | 00000001 | GLK MIPI_CTRL RO status bits | differs | boot_dsi_regs.txt:930; broken_dsi_regs.txt:958 |
| 0x162024 | 8080e480 | 00000000 | DSI PHY IREF0RC | differs | boot_dsi_regs.txt:2140; broken_dsi_regs.txt:2168 |
| 0x162028 | 8080e480 | 00000000 | DSI PHY IREF1RC | differs | boot_dsi_regs.txt:2141; broken_dsi_regs.txt:2169 |
| 0x46000 | 00300278 | 00b0013b | CDCLK frequency select | differs | boot_dsi_regs.txt:1180; broken_dsi_regs.txt:1208 |
| 0xc7200 | 00000000 | 00000004 | PPS sequence state, timing-volatile | excluded-volatile | boot_dsi_regs.txt:3302; broken_dsi_regs.txt:3330 |

## Mechanism claim

GOP sets DSI PHY calibration 0x162024=8080e480 / 0x162028=8080e480 at boot; the
kernel resume path leaves 0x162024=00000000 / 0x162028=00000000 — the PHY
reference-current calibration the GOP programs is never restored. Forcing
readable host registers was disproven before; this is calibration state the
enable path fails to reach, testable by writing the boot values in the resume
path and re-reading the block.

## What to restore/replicate

- 0x162024 / 0x162028: GOP PHY IREF calibration values (claim state)
- 0x46000: CDCLK frequency select as GOP left it
- MIPI_CTRL RO status target state: PHY status ready, ULPS not active

FIXTURE
    echo "[FIXTURES] proving case logic against the embedded fixture doc"
    run_doc_cases "$FIX/DSI_MMIO_DIFF.fixture.md"

    # Negative backstop: a contract-violating fixture MUST make the cases fail.
    vrc=0
    bash "$SCRIPT_DIR/test_dsi_mmio_evidence.sh" --fixtures-violating \
        > "$FIX/violating.out" 2>&1 || vrc=$?
    check "fixtures-backstop: violating fixture makes the suite fail (non-zero)" "[ $vrc -ne 0 ]"
    check "fixtures-backstop: citation-count case caught the violation" \
        "[ -f $FIX/violating.out ] && grep -q '\[FAIL\] mmio-diffdoc-citations' $FIX/violating.out"
    check "fixtures-backstop: single-claim case caught the duplicate heading" \
        "[ -f $FIX/violating.out ] && grep -q '\[FAIL\] mmio-single-claim' $FIX/violating.out"

    echo "=========================================================="
    echo " DSI MMIO evidence suite summary: passed=$passed failed=$failed"
    echo "=========================================================="
    [ "$failed" -eq 0 ]
    exit $?
fi

# ---- real mode (repo as found) ----

# Case 1: kit verify pristine-first (tamper gate before any judgment).
if bash scripts/prepare_safety_kit.sh --verify --kit-dir "$KIT" >/dev/null 2>&1; then
    echo "[OK] mmio-kit-verify"
    passed=$((passed + 1))
else
    echo "[FAIL] mmio-kit-verify" >&2
    echo "  missing/failing: $KIT/MANIFEST.sha256 verify (dumps registered by plan 47-03)" >&2
    failed=$((failed + 1))
fi

# Case 2: manifest names both dumps + the raw diff artifact.
need='boot_dsi_regs.txt broken_dsi_regs.txt dsi_regs_diff.txt'
missing=0
for f in $need; do
    if [ -f "$KIT/MANIFEST.sha256" ]; then
        grep -q "  $f\$" "$KIT/MANIFEST.sha256" || missing=$((missing + 1))
    else
        missing=$((missing + 1))
    fi
done
check "mmio-kit-manifest-covers (3 artifacts)" "[ $missing -eq 0 ]"
if [ "$missing" -ne 0 ]; then
    for f in $need; do
        if [ -f "$KIT/MANIFEST.sha256" ] && grep -q "  $f\$" "$KIT/MANIFEST.sha256"; then
            continue
        fi
        echo "  missing manifest line: $f (registered by plan 47-03)" >&2
    done
fi

# Cases 3-7 against the real doc (47-04's deliverable).
run_doc_cases "$DIFFDOC"

echo "=========================================================="
echo " DSI MMIO evidence suite summary: passed=$passed failed=$failed"
echo "=========================================================="
[ "$failed" -eq 0 ]
