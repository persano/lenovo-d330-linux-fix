#!/usr/bin/env bash
# ==============================================================================
# scripts/test_re_diff_evidence.sh
#
# Static evidence guard suite for Phase 45 RE + differential work (WRE-01/02/03,
# ROOT-01). Checks the shipped research docs and the checksummed RE kit without
# root, hardware, or device access:
#
#   1. re-kit-manifest-covers      MANIFEST names the load-bearing artifacts
#   2. re-kit-verify               sha256 -c against docs/dumps/re_kit passes
#   3. findings-doc-citations      GOP_DSI_RE_FINDINGS.md has the RE citations
#   4. two-vbt-story               both VBTs + block-53 runtime facts present
#   5. differential-doc-arms       Arm R + Arm L evidence in the differential
#   6. sequence-table-facts        GPIO/DCS sequence table content present
#
# Pristine-first ordering (SC1 rule): the verify case runs before anything
# could mutate the kit (nothing in this suite mutates it, but the ordering is
# kept for consistency with scripts/test_safety_kit.sh).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

KIT="docs/dumps/re_kit"
FINDINGS="docs/research/GOP_DSI_RE_FINDINGS.md"
DIFFDOC="docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 45 RE/differential evidence guard suite (6 static cases, no
root, no hardware).

Options:
  -h, --help    Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

echo "=========================================================="
echo " RE + Differential Evidence Guard Suite                   "
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

# Case 1: the kit manifest names the load-bearing artifacts.
need='vbt.bin runtime_vbt.bin gop_driver_dc90d1e2.efi igdkmd64.sys diff_armR_trace.txt diff_armL2_trace_10s.txt'
missing=0
for f in $need; do
    grep -q "  $f\$" "$KIT/MANIFEST.sha256" || missing=$((missing + 1))
done
check "re-kit-manifest-covers" "[ $missing -eq 0 ]"

# Case 2: kit verifies against its manifest (pristine-first).
if bash scripts/prepare_safety_kit.sh --verify --kit-dir "$KIT" >/dev/null 2>&1; then
    echo "[OK] re-kit-verify"
    passed=$((passed + 1))
else
    echo "[FAIL] re-kit-verify" >&2
    failed=$((failed + 1))
fi

# Case 3: findings doc has the RE citations (file+offset+bytes style).
c=0
grep -q '0x54425624' "$FINDINGS" && c=$((c + 1))
grep -q 'IntelGraphicsMem' "$FINDINGS" && c=$((c + 1))
grep -q 'offset \*\*0x4a40\*\*' "$FINDINGS" && c=$((c + 1))
grep -q 'offset \*\*0x612\*\*' "$FINDINGS" && c=$((c + 1))
grep -q '0x56ea70' "$FINDINGS" && c=$((c + 1))
grep -q 'INTMIPIENCODER_SetEncoderPowerState' "$FINDINGS" && c=$((c + 1))
grep -q '2736' "$FINDINGS" && c=$((c + 1))
grep -q 'DriverVer=09/11/2020,27.20.100.8729' "$FINDINGS" && c=$((c + 1))
check "findings-doc-citations (8 anchors)" "[ $c -eq 8 ]"

# Case 4: the two-VBT story (regression guard: SPI VBT alone is NOT the story).
c=0
grep -q 'VBT A — SPI flash, "BROXTON", BDB 206' "$FINDINGS" && c=$((c + 1))
grep -q 'VBT B — runtime (GOP handoff), "GEMINILAKE", BDB 212' "$FINDINGS" && c=$((c + 1))
grep -q 'i915_vbt' "$FINDINGS" && c=$((c + 1))
grep -q 'Block 53 "MIPI sequence block", version v3' "$FINDINGS" && c=$((c + 1))
check "two-vbt-story (4 anchors)" "[ $c -eq 4 ]"

# Case 5: differential doc carries both arms' evidence and the answer.
c=0
grep -q 'intel_pps_vdd_off_sync' "$DIFFDOC" && c=$((c + 1))
grep -q 'bl_power = 4' "$DIFFDOC" && c=$((c + 1))
grep -q 'enabled = disabled' "$DIFFDOC" && c=$((c + 1))
grep -q 'intel_dsi_vbt_exec_sequence' "$DIFFDOC" && c=$((c + 1))
grep -q 'dpms = On' "$DIFFDOC" && c=$((c + 1))
grep -q 'ROOT-01' "$DIFFDOC" && c=$((c + 1))
check "differential-doc-arms (6 anchors)" "[ $c -eq 6 ]"

# Case 6: the sequence table content (what a correct enable replays).
c=0
grep -q 'GPIO \*\*160\*\* = panel reset' "$FINDINGS" && c=$((c + 1))
grep -q 'GPIO \*\*144\*\* = panel power' "$FINDINGS" && c=$((c + 1))
grep -q 'GPIO \*\*145\*\* = backlight' "$FINDINGS" && c=$((c + 1))
grep -q '0x11' "$FINDINGS" && c=$((c + 1))
grep -q '0x29' "$FINDINGS" && c=$((c + 1))
grep -q 'MIPI_SEQ_DISPLAY_ON' "$FINDINGS" && c=$((c + 1))
check "sequence-table-facts (6 anchors)" "[ $c -eq 6 ]"

echo "=========================================================="
echo " RE evidence suite summary: passed=$passed failed=$failed"
echo "=========================================================="
[ "$failed" -eq 0 ]
