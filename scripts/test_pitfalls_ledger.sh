#!/usr/bin/env bash
# Banned-lever ledger gate (Phase 43, GUARD-01 + GUARD-02).
#
# docs/research/RESUME_FIX_LEDGER.md is the ONLY keyword source: this suite
# parses the ledger's machine table (sentinels LEDGER-LEVERS-START/END, 5-cell
# pipe rows, escaped pipes inside alias cells) and enforces it.
#
# What it enforces:
#   1. ledger_parses        - sentinels unique, every row has 5 non-empty
#                             cells, header count == actual rows, every alias
#                             regex compiles (grep -E rc 0/1, never 2) and
#                             matches at least one line of the three source
#                             docs, canonical names unique.
#   2. gate_fails_on_banned_fix - fixture probe: a plan-shaped file planting a
#                             banned-lever fix proposal must make the gate exit
#                             non-zero and print the file + line marker
#                             (non-vacuity; no repo files are touched - the
#                             probe scans D330_LEDGER_SCAN_DIR only).
#   3. allowlist_marker_honored - the same fixture with a
#                             <!-- planner-discipline-allow: <string> -->
#                             marker line passes clean (per exact string, per
#                             file; marker lines themselves never match).
#   4. pristine_tree_passes - the gate over the REAL tree is green: scan list
#                             from `git ls-files` filtered to *-PLAN.md /
#                             *-SUMMARY.md under .planning/phases/ (the
#                             tracked spelling; .gsd/phases is a junction and
#                             is tracked under the .planning spelling) plus
#                             docs/research/*.md minus the allowlist; the
#                             plan/summary subset count is asserted > 0
#                             separately from the total so a docs/research-only
#                             scan can never pass vacuously; working-tree glob
#                             (.gsd/phases / .planning/phases) only as fallback
#                             when git ls-files is unavailable.
#
# Standalone gate probe (used by fixtures and by hand):
#   D330_LEDGER_SCAN_DIR=<dir> bash scripts/test_pitfalls_ledger.sh --gate-probe
#   -> exit 0 clean, exit 1 on any banned-lever hit or ledger parse failure.
#
# Malformed ledger, missing sentinels or an empty table fail closed. Never
# widen exemptions wholesale; exemptions are per exact string per file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

LEDGER="docs/research/RESUME_FIX_LEDGER.md"
SOURCE_DOCS=(
    "docs/research/DISPLAY_RESUME_CCS_MODIFIER.md"
    "docs/research/DSI_RESUME_TRACE_ANALYSIS.md"
    "docs/research/COMMUNITY_FINDINGS.md"
    "docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md"
    "docs/research/NO_CLEAN_FIX_PROOF.md"
)
ALLOWLIST=(
    "RESUME_FIX_LEDGER.md"
    "DISPLAY_RESUME_CCS_MODIFIER.md"
    "DSI_RESUME_TRACE_ANALYSIS.md"
    "COMMUNITY_FINDINGS.md"
    "RESUME_CAPTURE_PROTOCOL.md"
)
MIN_LEDGER_ROWS=22

MODE="suite"
PROBE_SCAN_DIR="${D330_LEDGER_SCAN_DIR:-}"
for arg in "$@"; do
    case "$arg" in
        --gate-probe) MODE="probe" ;;
        *) echo "usage: $0 [--gate-probe]  (probe needs D330_LEDGER_SCAN_DIR)" >&2; exit 2 ;;
    esac
done
if [ "$MODE" = "probe" ] && [ -z "$PROBE_SCAN_DIR" ]; then
    echo "--gate-probe requires D330_LEDGER_SCAN_DIR" >&2
    exit 2
fi

LEV_NAME=()
LEV_RE=()
LEV_COUNT=0
PARSE_ERR=0
PARSE_MSG=""
GATE_STATUS=0
GATE_FILES=0
GATE_SUBSET=0
SCAN_FILES=()

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

allowlisted() {
    local base="$1" a
    for a in "${ALLOWLIST[@]}"; do
        if [ "$base" = "$a" ]; then return 0; fi
    done
    return 1
}

parse_ledger() {
    local sent_start sent_end header_count row n name regex disproof evidence rest
    LEV_NAME=()
    LEV_RE=()
    LEV_COUNT=0
    PARSE_ERR=0
    PARSE_MSG=""
    if [ ! -f "$LEDGER" ]; then
        PARSE_ERR=1; PARSE_MSG="ledger missing: $LEDGER"
        return 0
    fi
    sent_start="$(grep -c 'LEDGER-LEVERS-START' "$LEDGER" || true)"
    sent_end="$(grep -c 'LEDGER-LEVERS-END' "$LEDGER" || true)"
    if [ "$sent_start" -ne 1 ] || [ "$sent_end" -ne 1 ]; then
        PARSE_ERR=1; PARSE_MSG="sentinels not unique (START=$sent_start END=$sent_end)"
        return 0
    fi
    header_count="$(awk '/Lever rows:/{for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) {print $i; exit}}' "$LEDGER")"
    if [ -z "$header_count" ]; then
        PARSE_ERR=1; PARSE_MSG="no 'Lever rows:' count line"
        return 0
    fi
    local rows=()
    mapfile -t rows < <(awk '
        /LEDGER-LEVERS-START/ {ins=1; next}
        /LEDGER-LEVERS-END/   {ins=0; next}
        ins && /^\|/ && $0 !~ /^\|[[:space:]]*#/ && $0 !~ /^\|---/ && $0 !~ /^\|[[:space:]]*$/ {print}
    ' "$LEDGER")
    local esc=$'\001'
    for row in "${rows[@]}"; do
        row="${row//\\|/$esc}"
        n=0
        IFS='|' read -r _a num name regex disproof evidence rest <<< "$row"
        num="$(trim "${num:-}")"; name="$(trim "${name:-}")"
        regex="$(trim "${regex:-}")"; disproof="$(trim "${disproof:-}")"; evidence="$(trim "${evidence:-}")"
        regex="${regex#\`}"
        regex="${regex%\`}"
        if [ -n "${rest:-}" ] || [ -z "$num" ] || [ -z "$name" ] || [ -z "$regex" ] || [ -z "$disproof" ] || [ -z "$evidence" ]; then
            PARSE_ERR=1; PARSE_MSG="malformed row (need exactly 5 non-empty cells): ${row:0:60}"
            return 0
        fi
        regex="${regex//$esc/|}"
        LEV_NAME+=("$name")
        LEV_RE+=("$regex")
    done
    LEV_COUNT="${#LEV_NAME[@]}"
    if [ "$LEV_COUNT" -eq 0 ]; then
        PARSE_ERR=1; PARSE_MSG="empty lever table (fail closed)"
        return 0
    fi
    if [ "$header_count" -ne "$LEV_COUNT" ]; then
        PARSE_ERR=1; PARSE_MSG="header count $header_count != actual rows $LEV_COUNT"
        return 0
    fi
}

build_scan_list() {
    local mode="$1" f base list="" phasedir="" d
    SCAN_FILES=()
    if [ "$mode" = "probe" ]; then
        for f in "$PROBE_SCAN_DIR"/*.md; do
            [ -f "$f" ] || continue
            base="$(basename "$f")"
            if allowlisted "$base"; then continue; fi
            SCAN_FILES+=("$f")
        done
        return 0
    fi
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Active phases live under .planning/phases/; the active milestone's
        # archived phases live under .planning/milestones/<vN>-phases/ (the
        # v8.0 archive move). Older milestones' archives are historical
        # disproof records and are not scanned.
        active="$(sed -n 's/^milestone:[[:space:]]*//p' .planning/STATE.md 2>/dev/null | head -1 | tr -d '[:space:]')"
        pat='^\.planning/phases/[^/]+/[^/]+-(PLAN|SUMMARY)\.md$'
        if [ -n "$active" ]; then
            pat="^\\.planning/(phases|milestones/${active}-phases)/[^/]+/[^/]+-(PLAN|SUMMARY)\\.md\$"
        fi
        list="$(git ls-files 2>/dev/null | grep -E "${pat}|^docs/research/[^/]+\.md$" || true)"
    fi
    if [ -z "$list" ]; then
        for d in .gsd/phases .planning/phases; do
            if [ -d "$d" ]; then phasedir="$d"; break; fi
        done
        list="$( { ls "$phasedir"/*/*.md 2>/dev/null || true; ls docs/research/*.md 2>/dev/null || true; } | grep -E -- '-(PLAN|SUMMARY)\.md$|^docs/research/[^/]+\.md$' || true)"
    fi
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        if allowlisted "$base"; then continue; fi
        SCAN_FILES+=("$f")
    done <<< "$list"
    if [ "${#SCAN_FILES[@]}" -gt 0 ]; then
        mapfile -t SCAN_FILES < <(printf '%s\n' "${SCAN_FILES[@]}" | LC_ALL=C sort -u)
    fi
}

gate_scan() {
    local mode="$1" f base re name line lineno text hitline exempt marker_skip
    GATE_STATUS=0; GATE_FILES=0; GATE_SUBSET=0
    parse_ledger
    if [ "$PARSE_ERR" -ne 0 ]; then
        echo "Ledger gate: parse failure - $PARSE_MSG"
        GATE_STATUS=1
        return 0
    fi
    build_scan_list "$mode"
    GATE_FILES="${#SCAN_FILES[@]}"
    for f in "${SCAN_FILES[@]}"; do
        base="$(basename "$f")"
        if [[ "$f" == *-PLAN.md || "$f" == *-SUMMARY.md ]]; then
            GATE_SUBSET=$((GATE_SUBSET + 1))
        fi
        local allows=()
        mapfile -t allows < <(grep -o 'planner-discipline-allow:.*' "$f" 2>/dev/null | sed 's/^planner-discipline-allow:[[:space:]]*//; s/[[:space:]]*-->.*$//' || true)
        for i in "${!LEV_NAME[@]}"; do
            name="${LEV_NAME[$i]}"; re="${LEV_RE[$i]}"
            while IFS= read -r hitline || [ -n "$hitline" ]; do
                [ -n "$hitline" ] || continue
                lineno="${hitline%%:*}"
                text="${hitline#*:}"
                if [[ "$text" == *"planner-discipline-allow:"* ]]; then continue; fi
                exempt=0
                for a in "${allows[@]}"; do
                    if [[ -n "$a" && "$text" == *"$a"* ]]; then exempt=1; break; fi
                done
                if [ "$exempt" -eq 0 ]; then
                    printf 'BANNED LEVER: %s at %s:%s\n' "$name" "$f" "$lineno"
                    printf '  line: %s\n' "$(trim "${text:0:160}")"
                    GATE_STATUS=1
                fi
            done < <(grep -Ein -- "$re" "$f" 2>/dev/null || true)
        done
    done
    printf 'Ledger gate: files=%s hits=%s\n' "$GATE_FILES" "$([ "$GATE_STATUS" -eq 0 ] && echo 0 || echo 1)"
    if [ "$mode" = "normal" ]; then
        # Between milestones (none active in STATE.md) there are no plans to
        # scan; docs/research coverage is then the full, legitimate scan.
        active="$(sed -n 's/^milestone:[[:space:]]*//p' .planning/STATE.md 2>/dev/null | head -1 | tr -d '[:space:]')"
        if [ "$GATE_FILES" -eq 0 ]; then
            echo "Ledger gate: FAIL - scan produced zero files (mechanism failure)"
            GATE_STATUS=1
        elif [ "$GATE_SUBSET" -eq 0 ] && [ -n "$active" ]; then
            echo "Ledger gate: FAIL - plan/summary subset is empty (docs/research-only coverage never counts as a passing scan)"
            GATE_STATUS=1
        fi
    fi
    return 0
}

if [ "$MODE" = "probe" ]; then
    gate_scan probe
    exit "$GATE_STATUS"
fi

# ---- guard suite ----
passed=0
failed=0
CASE_FAIL=0
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

expect_rc_eq() {
    if [ "$1" -ne "$2" ]; then
        echo "    [detail] expected rc=$2, got rc=$1"
        CASE_FAIL=1
    fi
}

case_ledger_parses() {
    parse_ledger
    if [ "$PARSE_ERR" -ne 0 ]; then
        echo "    [detail] ledger parse failure: $PARSE_MSG"
        CASE_FAIL=1
        return 0
    fi
    if [ "$LEV_COUNT" -lt "$MIN_LEDGER_ROWS" ]; then
        echo "    [detail] ledger has only $LEV_COUNT rows (need at least $MIN_LEDGER_ROWS)"
        CASE_FAIL=1
    fi
    local -A seen=()
    local i re rc probe_line
    for i in "${!LEV_NAME[@]}"; do
        if [ -n "${seen[${LEV_NAME[$i]}]+x}" ]; then
            echo "    [detail] duplicate canonical lever name: ${LEV_NAME[$i]}"
            CASE_FAIL=1
        fi
        seen["${LEV_NAME[$i]}"]=1
        re="${LEV_RE[$i]}"
        rc=0
        printf 'compile probe\n' | grep -Eq -- "$re" 2>/dev/null || rc=$?
        if [ "$rc" -ge 2 ]; then
            echo "    [detail] alias regex does not compile (rc=$rc): $re"
            CASE_FAIL=1
            continue
        fi
        if ! grep -Eiq -- "$re" "${SOURCE_DOCS[@]}" 2>/dev/null; then
            echo "    [detail] alias regex matches none of the source docs (vacuous row): $re"
            CASE_FAIL=1
        fi
    done
}

case_gate_fails_on_banned_fix() {
    local planted="Plan: fix black resume by setting i915.enable_psr=0"
    local idx=-1 i
    for i in "${!LEV_NAME[@]}"; do
        if [[ "${LEV_NAME[$i]}" == *enable_psr* ]]; then idx="$i"; break; fi
    done
    if [ "$idx" -eq -1 ]; then
        echo "    [detail] enable_psr lever row not found in ledger"
        CASE_FAIL=1
        return 0
    fi
    if ! grep -Eqi -- "${LEV_RE[$idx]}" <<< "$planted"; then
        echo "    [detail] planted line not matched by the lever's own alias regex (probe would be vacuous)"
        CASE_FAIL=1
        return 0
    fi
    local tmp="$FIX/fixture1"
    mkdir -p "$tmp"
    printf '%s\n' "$planted" > "$tmp/44-01-PLAN.md"
    local out="" rc=0
    out="$(D330_LEDGER_SCAN_DIR="$tmp" bash "$SCRIPT_DIR/test_pitfalls_ledger.sh" --gate-probe 2>&1)" || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "    [detail] gate passed a banned-lever fix proposal (non-vacuity failure)"
        CASE_FAIL=1
    fi
    if ! grep -qF "44-01-PLAN.md" <<< "$out"; then
        echo "    [detail] gate output missing fixture filename"
        CASE_FAIL=1
    fi
    if ! grep -qE "BANNED LEVER: .* at .*44-01-PLAN\.md:[0-9]+" <<< "$out"; then
        echo "    [detail] gate output missing file:line marker"
        CASE_FAIL=1
    fi
}

case_allowlist_marker_honored() {
    local tmp="$FIX/fixture2"
    mkdir -p "$tmp"
    {
        printf 'Plan: fix black resume by setting i915.enable_psr=0\n'
        printf '<!-- planner-discipline-allow: i915.enable_psr=0 -->\n'
    } > "$tmp/44-02-PLAN.md"
    local rc=0
    D330_LEDGER_SCAN_DIR="$tmp" bash "$SCRIPT_DIR/test_pitfalls_ledger.sh" --gate-probe >/dev/null 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
}

case_pristine_tree_passes() {
    gate_scan normal
    if [ "$GATE_FILES" -eq 0 ]; then
        echo "    [detail] total scanned count is 0 (scan mechanism failure)"
        CASE_FAIL=1
    fi
    # Mirror gate_scan normal's own rule: an empty plan/summary subset is a
    # failure only while a milestone is active in STATE.md; between
    # milestones (none active) docs/research coverage is the full scan.
    local active
    active="$(sed -n 's/^milestone:[[:space:]]*//p' .planning/STATE.md 2>/dev/null | head -1 | tr -d '[:space:]')"
    if [ "$GATE_SUBSET" -eq 0 ] && [ -n "$active" ]; then
        echo "    [detail] scanned plan/summary subset count is 0 while milestone '$active' is active (docs/research-only coverage never counts as a passing scan)"
        CASE_FAIL=1
    fi
    if [ "$GATE_STATUS" -ne 0 ]; then
        echo "    [detail] pristine tree has banned-lever hits above (fix the text or add a per-string planner-discipline-allow marker)"
        CASE_FAIL=1
    fi
}

CASE_NAMES=(
    case_ledger_parses
    case_gate_fails_on_banned_fix
    case_allowlist_marker_honored
    case_pristine_tree_passes
)
for fn in "${CASE_NAMES[@]}"; do
    CASE_FAIL=0
    "$fn" || true
    name="${fn#case_}"
    name="${name//_/-}"
    if [ "$CASE_FAIL" -eq 0 ]; then
        echo "  [OK] $name"
        passed=$((passed + 1))
    else
        echo "  [FAIL] $name"
        failed=$((failed + 1))
    fi
done
echo ""
echo "=========================================================="
echo " Ledger gate suite summary: passed=$passed failed=$failed"
echo "=========================================================="
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
