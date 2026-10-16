#!/usr/bin/env bash
# ==============================================================================
# scripts/dsi_mmio_diff.sh
#
# Boot-vs-resume DSI MMIO dump diff (Phase 47, MMIO-01 / D-06 / D-07).
#
# Input contract (pinned verbatim with 47-01's dump format):
#   section header   `# RANGE <lo>-<hi> (<N> words)`
#   data lines       `0x<offset>=<8 hex digits>`   (range walks only)
#   skip marker      `# SKIPPED: DSI PLL off - DSI block reads skipped`
#                    `# SKIPPED: DSI PLL off - PHY reads skipped`
#                    (replace the DSI-block / DSI-PHY section's `# RANGE`
#                    header when the DSI PLL is off - BSpec machine-hang
#                    gate; each marker keys to exactly its own range, so a
#                    corrupted non-gated section on a marker arm still
#                    classifies parse-warning, never skipped-pll-off)
#   overlay          `# NAMED OVERLAY` section, rows `NAME 0x…=… <decode>`
#                    (leading NAME never matches the record regex)
#
# Output: one markdown table with columns
#   offset | boot | resume | interpretation | verdict | citation
# Verdict vocabulary: differs | excluded-volatile | state | parse-warning.
# Excluded rows still print (offset + both values + reason + verdict) -
# excluded means de-prioritized for the claim, never hidden (D-06).
# Every row cites each capture file plus its line number (D-07).
#
# Per-arm range state classification (hardened: a zero-record section can
# never classify `readable`):
#   skipped-pll-off        a skip marker matching THIS range is present and
#                          the section is absent/empty (DSI block
#                          0x6b000-0x6c000 keys to the DSI-block marker;
#                          DSI PHY 0x160000-0x164000 keys to the PHY marker)
#   unreadable-0xffffffff  >90% of the section's records read 0xffffffff
#   parse-warning          section present but empty with no matching skip
#                          marker (also: marker present but section has
#                          records, or no marker at all)
#   readable               otherwise
# A range whose arm states differ, or that is non-readable on both arms,
# produces ONE state row instead of per-register rows.
#
# Usage:
#   dsi_mmio_diff.sh <boot_dump> <resume_dump> [-o OUTFILE] [--names FILE]
#   dsi_mmio_diff.sh --selftest
#
# --names FILE maps offsets to register names (one `0xOFFSET NAME` line per
# register, e.g. produced by a tree grep); without it rows show offsets only.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 47-01 format contract constants.
RECORD_BASH_RE='^0x[0-9a-f]+=[0-9a-fA-F]{8}$'
SKIP_MARKER='# SKIPPED: DSI PLL off - DSI block reads skipped'
PHY_SKIP_MARKER='# SKIPPED: DSI PLL off - PHY reads skipped'
DSI_LO=6b000      # the DSI-block skip marker's section: the DSI ports block
DSI_HI=6c000
PHY_LO=160000     # the PHY skip marker's section: the BXT/GLK DSI PHY
PHY_HI=164000
TAB=$'\t'

usage() {
    cat <<EOF
Usage: $(basename "$0") <boot_dump> <resume_dump> [-o OUTFILE] [--names FILE]
       $(basename "$0") --selftest

Joins two i915_dsi_regs dump files on register offset and emits a cited
markdown diff (offset | boot | resume | interpretation | verdict | citation)
with the Phase 47 per-range exclusion table and 0xffffffff classification.

Options:
  -o OUTFILE     write the diff to OUTFILE instead of stdout
  --names FILE   optional offset-to-name mapping file (0xOFFSET NAME lines)
  --selftest     run the embedded fixture selftest (no hardware needed)
  -h, --help     show this help
EOF
}

die() { echo "error: $*" >&2; exit 2; }

# ------------------------------------------------------------------------------
# Exclusion table (D-06). The canonical table docs/research/DSI_MMIO_DIFF.md
# (47-04) mirrors. Each entry states the register's TRUE semantics - enable/
# config/status families are never lumped together. Format (TSV):
#   E <8-hex offset>            <reason>
#   R <8-hex lo> <8-hex hi>     <reason>
# Excluded rows still print with verdict excluded-volatile; the reason string
# carries the true semantics - no separate verdict class for config-family rows.
# ------------------------------------------------------------------------------
build_exclusions() {
    local f="$1"
    {
        printf 'E\t%s\t%s\n' 0006b004 'interrupt status (write-1-to-clear), volatile'
        printf 'E\t%s\t%s\n' 0006b804 'interrupt status (write-1-to-clear), volatile'
        printf 'E\t%s\t%s\n' 0006b090 'interrupt status (write-1-to-clear), volatile'
        printf 'E\t%s\t%s\n' 0006b094 'interrupt-enable mask, config state; prior differing row 00000001→00000000 (DISPLAY_RESUME_CCS_MODIFIER.md:82), de-prioritized per ledger rows 3/18 (prior forcing result disproven)'
        printf 'R\t%s\t%s\t%s\n' 0006b118 0006b137 'RX FIFO, pop-on-read side effect'
        printf 'E\t%s\t%s\n' 0006b064 'RX FIFO, pop-on-read side effect'
        printf 'E\t%s\t%s\n' 0006b068 'RX FIFO, pop-on-read side effect'
        printf 'E\t%s\t%s\n' 0006b074 'GEN FIFO status, read-only; level drains with link idle'
        printf 'E\t%s\t%s\n' 0006b138 'read-valid flag, volatile'
        printf 'E\t%s\t%s\n' 000c7200 'PPS sequence state, timing-volatile'
        printf 'R\t%s\t%s\t%s\n' 00070040 0007004c 'compositor-volatile surface state'
        printf 'E\t%s\t%s\n' 0007019c 'compositor-volatile surface state'
        printf 'E\t%s\t%s\n' 000701ac 'compositor-volatile surface state'
        printf 'E\t%s\t%s\n' 00138070 'monotonic counters, not config'
        printf 'E\t%s\t%s\n' 00138074 'monotonic counters, not config'
        printf 'R\t%s\t%s\t%s\n' 00045264 00045308 'monotonic counters, not config'
    } > "$f"
}

# ------------------------------------------------------------------------------
# Parser: one dump arm -> rep TSV stream.
#   H <arm> <lo> <hi> <line>          section header
#   S <arm> <line> <DSI|PHY>          skip marker (DSI block or DSI PHY)
#   R <arm> <lo> <hi> <off> <val> <line>   record (offset normalized 8-hex)
#   W <arm> <line> <snippet>          parse warning (non-record line in section)
# Lines inside a range section that do not match the record regex are counted
# warnings, never data (threat T-47-06). Overlay rows are never data.
# ------------------------------------------------------------------------------
parse_arm() {
    local file="$1" arm="$2"
    awk -v arm="$arm" -v skiptxt="$SKIP_MARKER" -v pskiptxt="$PHY_SKIP_MARKER" '
        BEGIN {
            # no {8} interval: old mawk lacks interval expressions
            valre = "^0x[0-9a-f]+=[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$"
        }
        {
            if ($0 == skiptxt)  { print "S\t" arm "\t" NR "\tDSI"; insec = 0; inov = 0; next }
            if ($0 == pskiptxt) { print "S\t" arm "\t" NR "\tPHY"; insec = 0; inov = 0; next }
            if ($0 ~ /^# RANGE 0x[0-9a-f]+-0x[0-9a-f]+ /) {
                split($3, a, "-")
                lo = a[1]; hi = a[2]
                sub(/^0x/, "", lo); sub(/^0x/, "", hi)
                lo = tolower(lo); hi = tolower(hi)
                cur_lo = lo; cur_hi = hi; insec = 1; inov = 0
                print "H\t" arm "\t" lo "\t" hi "\t" NR
                next
            }
            if ($0 ~ /^# NAMED OVERLAY/) { inov = 1; insec = 0; next }
            if ($0 ~ /^#/) { next }
            if ($0 ~ /^[ \t]*$/) { next }
            if (inov) { next }
            if (insec) {
                if ($0 ~ valre) {
                    off = $0; sub(/=.*/, "", off); sub(/^0x/, "", off)
                    val = $0; sub(/^[^=]*=/, "", val)
                    off = tolower(off)
                    while (length(off) < 8) off = "0" off
                    val = tolower(val)
                    print "R\t" arm "\t" cur_lo "\t" cur_hi "\t" off "\t" val "\t" NR
                } else {
                    snip = $0
                    if (length(snip) > 60) snip = substr(snip, 1, 60)
                    print "W\t" arm "\t" NR "\t" snip
                }
                next
            }
            snip = $0
            if (length(snip) > 60) snip = substr(snip, 1, 60)
            print "W\t" arm "\t" NR "\t" snip
        }
    ' "$file"
}

# ------------------------------------------------------------------------------
# Engine: join two dumps -> cited markdown diff. Writes to $3 (outfile).
# Pipeline: parse both arms -> per-(arm,range) state classification -> state
# rows / joinable ranges -> record join on offset -> exclusion lookup ->
# deterministic sorted emission. Same inputs -> byte-identical output.
# ------------------------------------------------------------------------------
run_diff() {
    local boot="$1" resume="$2" out="$3" names="${4:-}"
    local bootname resumename tmp rboot rresume wboot wresume excl scount
    bootname="$(basename "$boot")"
    resumename="$(basename "$resume")"
    tmp="$(mktemp -d)"

    build_exclusions "$tmp/pat.tsv"
    parse_arm "$boot"   boot   > "$tmp/boot.rep"
    parse_arm "$resume" resume > "$tmp/resume.rep"
    cat "$tmp/boot.rep" "$tmp/resume.rep" > "$tmp/all.rep"

    # --- per-(arm,range) state classification (hardened) ---
    awk -F'\t' -v dsi_lo="$DSI_LO" -v dsi_hi="$DSI_HI" \
            -v phy_lo="$PHY_LO" -v phy_hi="$PHY_HI" '
        BEGIN { narms = split("boot resume", ARMS, " ") }
        $1 == "H" { seen[$3 FS $4] = 1; hdr[$2 FS $3 FS $4] = $5; next }
        $1 == "S" {
            if ($4 == "PHY") {
                skipphy[$2] = 1; skipphyline[$2] = $3
                seen[phy_lo FS phy_hi] = 1   # marker replaces the PHY section header
            } else {
                skip[$2] = 1; skipline[$2] = $3
                seen[dsi_lo FS dsi_hi] = 1   # marker replaces the DSI section header
            }
            next
        }
        $1 == "R" {
            seen[$3 FS $4] = 1
            rec[$2 FS $3 FS $4]++
            if ($6 == "ffffffff") ff[$2 FS $3 FS $4]++
            next
        }
        $1 == "W" { warn[$2]++; next }
        END {
            for (k in seen) {
                split(k, p, FS)
                for (a = 1; a <= narms; a++) {
                    arm = ARMS[a]
                    n = rec[arm FS k] + 0
                    f = ff[arm FS k] + 0
                    # WR-01 hardening: honor a marker only for the exact
                    # range it gates, so a corrupted non-gated section on a
                    # marker arm classifies parse-warning, never the benign
                    # skipped-pll-off.
                    sk  = (skip[arm] == 1 && p[1] == dsi_lo && p[2] == dsi_hi) ? 1 : 0
                    skp = (skipphy[arm] == 1 && p[1] == phy_lo && p[2] == phy_hi) ? 1 : 0
                    if ((sk || skp) && n == 0) st = "skipped-pll-off"
                    else if (n == 0)           st = "parse-warning"
                    else if (sk || skp)        st = "parse-warning"
                    else if (f * 10 > n * 9)   st = "unreadable-0xffffffff"
                    else                       st = "readable"
                    sl = sk ? (skipline[arm] + 0) : 0
                    if (skp) sl = skipphyline[arm] + 0
                    print "ST\t" p[1] "\t" p[2] "\t" arm "\t" st "\t" n "\t" f "\t" (hdr[arm FS k] + 0) "\t" sl
                }
            }
            print "WR\tboot\t" (warn["boot"] + 0)
            print "WR\tresume\t" (warn["resume"] + 0)
        }
    ' "$tmp/all.rep" > "$tmp/state.tsv"

    # --- combine: one state row per non-joinable range, JOIN for the rest ---
    awk -F'\t' -v OFS='\t' -v bootname="$bootname" -v resumename="$resumename" \
        -v dsi_lo="$DSI_LO" -v dsi_hi="$DSI_HI" -v phy_lo="$PHY_LO" -v phy_hi="$PHY_HI" '
        function pad8(s,  t) { t = s; while (length(t) < 8) t = "0" t; return t }
        $1 == "ST" {
            key = $2 FS $3
            st_[$4 FS key] = $5
            n_[$4 FS key] = $6
            hdr_[$4 FS key] = $8
            skl_[$4 FS key] = $9
            lop[key] = $2; hip[key] = $3
            next
        }
        END {
            nstate = 0
            for (key in lop) {
                lo = lop[key]; hi = hip[key]
                b = st_["boot" FS key];   if (b == "") b = "missing"
                r = st_["resume" FS key]; if (r == "") r = "missing"
                if (b == "readable" && r == "readable") {
                    print "JOIN\t" lo "\t" hi
                    continue
                }
                nstate++
                verdict = "state"
                if (b == "skipped-pll-off" || r == "skipped-pll-off")
                    interp = (lo == phy_lo && hi == phy_hi) ? "DSI PHY block skipped: PLL off" : "DSI block skipped: PLL off"
                else if (b == "unreadable-0xffffffff" || r == "unreadable-0xffffffff")
                    interp = "0xffffffff (powered/not decoded)"
                else {
                    interp = "malformed dump: section empty/missing without skip marker"
                    verdict = "parse-warning"
                }
                bc = b; rc = r
                if (b == "readable") bc = "readable (" n_["boot" FS key] " regs)"
                if (r == "readable") rc = "readable (" n_["resume" FS key] " regs)"
                bl = hdr_["boot" FS key] + 0;   if (bl == 0) bl = skl_["boot" FS key] + 0
                rl = hdr_["resume" FS key] + 0; if (rl == 0) rl = skl_["resume" FS key] + 0
                bcite = (bl > 0) ? bootname ":" bl : "-"
                rcite = (rl > 0) ? resumename ":" rl : "-"
                print "ROW\t" pad8(lo) "#0\t0x" lo "-0x" hi "\t" bc "\t" rc "\t" interp "\t" verdict "\t" bcite "\t" rcite
            }
            print "SC\t" nstate
        }
    ' "$tmp/state.tsv" > "$tmp/combine.tsv"

    grep '^JOIN' "$tmp/combine.tsv" | LC_ALL=C sort -t"$TAB" -k2,2 > "$tmp/joinable.txt" || true
    grep '^ROW'  "$tmp/combine.tsv" > "$tmp/state.rows" || true

    # --- join records on offset for readable/readable ranges ---
    : > "$tmp/reg.rows"
    : > "$tmp/ident.meta"
    while IFS="$TAB" read -r _ lo hi; do
        [ -n "$lo" ] || continue
        awk -F'\t' -v lo="$lo" -v hi="$hi" \
            '$1 == "R" && $3 == lo && $4 == hi { print $5 "\t" $6 "\t" $7 "\t" $2 }' \
            "$tmp/all.rep" | LC_ALL=C sort -t"$TAB" -k1,1 > "$tmp/pairs"
        awk -F'\t' '$4 == "boot"'   "$tmp/pairs" > "$tmp/pb"
        awk -F'\t' '$4 == "resume"' "$tmp/pairs" > "$tmp/pr"
        join -t "$TAB" -a 1 -a 2 -e '' -o '0,1.2,1.3,2.2,2.3' "$tmp/pb" "$tmp/pr" > "$tmp/joined" || true
        awk -F'\t' -v OFS='\t' -v lo="$lo" -v hi="$hi" -v identf="$tmp/ident.meta" \
            -v bootname="$bootname" -v resumename="$resumename" '
            function pad8(s,  t) { t = s; while (length(t) < 8) t = "0" t; return t }
            function unp(s) { sub(/^0+/, "", s); if (s == "") s = "0"; return s }
            {
                off = $1; bv = $2; bl = $3; rv = $4; rl = $5
                key = pad8(off) "#1"
                ocell = "0x" unp(off)
                if (bv == "" || rv == "") {
                    if (bv == "") { bv = "-"; bl = "" }
                    if (rv == "") { rv = "-"; rl = "" }
                    bcite = (bl != "") ? bootname ":" bl : "-"
                    rcite = (rl != "") ? resumename ":" rl : "-"
                    print "ROW\t" key "\t" ocell "\t" bv "\t" rv "\tmalformed dump: offset missing on one arm\tparse-warning\t" bcite "\t" rcite
                    next
                }
                if (bv == rv) { ident++; next }
                print "ROW\t" key "\t" ocell "\t" bv "\t" rv "\t-\tdiffers\t" bootname ":" bl "\t" resumename ":" rl
            }
            END { print "IDENT\t" lo "\t" hi "\t" (ident + 0) >> identf; close(identf) }
        ' "$tmp/joined" >> "$tmp/reg.rows"
    done < "$tmp/joinable.txt"

    # --- exclusion lookup: differs rows may flip to excluded-volatile ---
    awk -F'\t' -v OFS='\t' -v patf="$tmp/pat.tsv" '
        BEGIN {
            while ((getline line < patf) > 0) {
                split(line, a, "\t")
                if (a[1] == "E") { exact[a[2]] = a[3] }
                else { nr++; lor[nr] = a[2]; hir[nr] = a[3]; why[nr] = a[4] }
            }
            close(patf)
        }
        {
            if ($7 == "differs") {
                off = substr($2, 1, 8)
                r = exact[off]
                if (r == "") {
                    for (i = 1; i <= nr; i++)
                        if (off >= lor[i] && off <= hir[i]) { r = why[i]; break }
                }
                if (r != "") { $6 = r; $7 = "excluded-volatile" }
            }
            print
        }
    ' "$tmp/reg.rows" > "$tmp/reg.rows.x"

    # --- counts for the machine-readable parse summary ---
    rboot=$(awk -F'\t' '$1 == "R" && $2 == "boot"   { n++ } END { print n + 0 }' "$tmp/all.rep")
    rresume=$(awk -F'\t' '$1 == "R" && $2 == "resume" { n++ } END { print n + 0 }' "$tmp/all.rep")
    wboot=$(awk -F'\t' '$1 == "WR" && $2 == "boot"   { print $3 }' "$tmp/state.tsv")
    wresume=$(awk -F'\t' '$1 == "WR" && $2 == "resume" { print $3 }' "$tmp/state.tsv")
    excl=$(grep -c 'excluded-volatile' "$tmp/reg.rows.x" || true)
    scount=$(awk -F'\t' '$1 == "SC" { print $2 }' "$tmp/combine.tsv")

    cat "$tmp/state.rows" "$tmp/reg.rows.x" | LC_ALL=C sort -t"$TAB" -k2,2 > "$tmp/rows.sorted"

    {
        printf 'META recs boot %s\n'    "$rboot"
        printf 'META recs resume %s\n'  "$rresume"
        printf 'META warns boot %s\n'   "$wboot"
        printf 'META warns resume %s\n' "$wresume"
        printf 'META excl %s\n'         "$excl"
        printf 'META state %s\n'        "$scount"
    } > "$tmp/meta.tsv"
    LC_ALL=C sort -t"$TAB" -k2,2 -k3,3 "$tmp/ident.meta" >> "$tmp/meta.tsv"

    # --- emission (single stream: rows, sentinel, meta) ---
    {
        cat "$tmp/rows.sorted"
        echo "@@META@@"
        cat "$tmp/meta.tsv"
    } | awk -F'\t' -v bootname="$bootname" -v resumename="$resumename" \
            -v recb="$rboot" -v recr="$rresume" -v warnb="$wboot" -v warnr="$wresume" \
            -v excl="$excl" -v scount="$scount" -v namesf="$names" '
        BEGIN {
            if (namesf != "") {
                while ((getline nline < namesf) > 0) {
                    if (nline !~ /^0x/) continue
                    no = nline; sub(/[ \t].*$/, "", no); sub(/^0x/, "", no); no = tolower(no)
                    while (length(no) < 8) no = "0" no
                    nname = nline; sub(/^[^ \t]+[ \t]+/, "", nname)
                    nm[no] = nname
                }
                close(namesf)
            }
            print "# DSI MMIO dump diff"
            print ""
            print "# parse summary"
            print "records " bootname "=" recb " warnings=" warnb
            print "records " resumename "=" recr " warnings=" warnr
            print ""
            print "| offset | boot | resume | interpretation | verdict | citation |"
            print "|---|---|---|---|---|---|"
            seen_meta = 0
        }
        !seen_meta && $1 == "ROW" {
            ocell = $3
            if ($2 ~ /#1$/) {
                o = substr($2, 1, 8)
                if (nm[o] != "") ocell = ocell " " nm[o]
            }
            print "| " ocell " | " $4 " | " $5 " | " $6 " | " $7 " | " $8 "; " $9 " |"
            next
        }
        $1 == "@@META@@" { seen_meta = 1; next }
        $1 == "META" { next }
        $1 == "IDENT" {
            ni++
            il[ni] = "0x" $2 "-0x" $3
            ic[ni] = $4
            next
        }
        END {
            print ""
            print "## summary"
            for (i = 1; i <= ni; i++)
                print "- identical " il[i] ": " ic[i] " register(s) matching"
            print "- excluded-volatile rows: " excl
            print "- state rows: " scount
            print "- parse warnings: boot=" warnb " resume=" warnr
        }
    ' > "$out"

    rm -rf "$tmp"
    return 0
}

# ------------------------------------------------------------------------------
# Selftest: embedded fixtures covering every classification branch of the
# <behavior> contract. Exits non-zero if any assertion fails.
# ------------------------------------------------------------------------------
selftest() {
    local passed=0 failed=0
    local d
    d="$(mktemp -d)"
    trap 'rm -rf "$d"' EXIT

    ok()   { echo "  [OK] $1";   passed=$((passed + 1)); }
    bad()  { echo "  [FAIL] $1" >&2; failed=$((failed + 1)); }
    # expect_eq <name> <got> <want>
    expect_eq() {
        if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2, want: $3)"; fi
    }
    # expect_has <name> <file> <pattern>
    expect_has() {
        if grep -qE -- "$3" "$2"; then ok "$1"; else bad "$1 (pattern missing: $3)"; fi
    }
    # expect_count <name> <file> <pattern> <want>
    expect_count() {
        local got
        got="$(grep -cE -- "$3" "$2" || true)"
        if [ "$got" = "$4" ]; then ok "$1"; else bad "$1 (count: $got, want: $4)"; fi
    }

    local bootf="$d/boot_dsi_regs.txt" resumef="$d/broken_dsi_regs.txt"

    echo "dsi_mmio_diff selftest"

    # --- fixture A: excluded volatile interrupt-status row + identical count ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=0000000a"
        echo "0x6b004=00000000"
    } > "$bootf"
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=0000000a"
        echo "0x6b004=40200000"
    } > "$resumef"
    run_diff "$bootf" "$resumef" "$d/a.md"
    expect_count "A: exactly one differing row (0x6b004)" "$d/a.md" '^\| 0x6b004 ' 1
    expect_count "A: no row for the identical 0x6b000" "$d/a.md" '^\| 0x6b000 ' 0
    expect_has "A: 0x6b004 verdict excluded-volatile" "$d/a.md" \
        '^\| 0x6b004 .*excluded-volatile'
    expect_has "A: citation names boot capture with line" "$d/a.md" \
        'boot_dsi_regs\.txt:3'
    expect_has "A: citation names resume capture with line" "$d/a.md" \
        'broken_dsi_regs\.txt:3'
    expect_has "A: identical count reflects 0x6b000" "$d/a.md" \
        'identical 0x6b000-0x6c000: 1 register'
    expect_has "A: W1C reason string" "$d/a.md" \
        'write-1-to-clear'

    # --- fixture B: PLL-off skip marker on resume arm ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=00000001"
    } > "$bootf"
    printf '%s\n' "$SKIP_MARKER" > "$resumef"
    run_diff "$bootf" "$resumef" "$d/b.md"
    expect_count "B: exactly one state row for the DSI range" "$d/b.md" \
        '^\| 0x6b000-0x6c000 ' 1
    expect_has "B: state row says PLL off" "$d/b.md" 'DSI block skipped: PLL off'
    expect_has "B: state row verdict is state" "$d/b.md" \
        '^\| 0x6b000-0x6c000 .* \| state \|'
    expect_count "B: zero per-register rows" "$d/b.md" '^\| 0x6b000 [0-9a-f]' 0
    expect_has "B: state row cites both arms with lines" "$d/b.md" \
        'boot_dsi_regs\.txt:1; broken_dsi_regs\.txt:1'

    # --- fixture B2: marker + present-but-empty section still skipped ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
    } > "$bootf"
    {
        printf '%s\n' "$SKIP_MARKER"
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
    } > "$resumef"
    run_diff "$bootf" "$resumef" "$d/b2.md"
    expect_has "B2: empty section + marker classifies skipped-pll-off" "$d/b2.md" \
        'DSI block skipped: PLL off'
    expect_count "B2: never classified readable (no register rows)" "$d/b2.md" \
        '^\| 0x6b000 [0-9a-f]' 0

    # --- fixture C: all-ones range -> one unreadable state row ---
    {
        echo "# RANGE 0x160000-0x164000 (4096 words)"
        echo "0x160018=00000115"
        echo "0x160020=00000003"
        echo "0x160054=00000001"
        echo "0x162000=00010000"
        echo "0x162024=8080e480"
        echo "0x162070=33cb0443"
        echo "0x16218c=00400000"
        echo "0x163198=00ffffff"
        echo "0x1631a0=30008003"
        echo "0x160100=00000011"
    } > "$bootf"
    {
        echo "# RANGE 0x160000-0x164000 (4096 words)"
        echo "0x160018=ffffffff"
        echo "0x160020=ffffffff"
        echo "0x160054=ffffffff"
        echo "0x162000=ffffffff"
        echo "0x162024=ffffffff"
        echo "0x162070=ffffffff"
        echo "0x16218c=ffffffff"
        echo "0x163198=ffffffff"
        echo "0x1631a0=ffffffff"
        echo "0x160100=ffffffff"
    } > "$resumef"
    run_diff "$bootf" "$resumef" "$d/c.md"
    expect_count "C: exactly one unreadable state row for the PHY range" "$d/c.md" \
        '^\| 0x160000-0x164000 ' 1
    expect_has "C: unreadable wording" "$d/c.md" '0xffffffff \(powered/not decoded\)'
    expect_has "C: state row verdict is state" "$d/c.md" \
        '^\| 0x160000-0x164000 .* \| state \|'
    expect_count "C: zero per-register rows for the range" "$d/c.md" '^\| 0x16[0-9a-f]{4} ' 0

    # --- fixture D: identical dumps -> zero rows, counts only, exit 0 ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=00000001"
        echo "0x6b004=00000002"
    } > "$bootf"
    cp "$bootf" "$resumef"
    rc=0
    run_diff "$bootf" "$resumef" "$d/d.md" || rc=$?
    expect_eq "D: exit 0 on identical dumps" "$rc" "0"
    expect_count "D: zero differing/state rows" "$d/d.md" '^\| 0x' 0
    expect_has "D: per-range identical count emitted" "$d/d.md" \
        'identical 0x6b000-0x6c000: 2 register'

    # --- fixture E: determinism - same inputs twice -> byte-identical output ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=0000000a"
        echo "0x6b004=00000000"
        echo "0x6b094=00000001"
    } > "$bootf"
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=0000000a"
        echo "0x6b004=40200000"
        echo "0x6b094=00000000"
    } > "$resumef"
    run_diff "$bootf" "$resumef" "$d/e1.md"
    run_diff "$bootf" "$resumef" "$d/e2.md"
    if cmp -s "$d/e1.md" "$d/e2.md"; then
        ok "E: same inputs twice -> byte-identical output"
    else
        bad "E: output not deterministic"
    fi

    # --- fixture F: malformed line -> parse warning, never data ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "not-a-record"
        echo "0x6b000=00000001"
    } > "$bootf"
    cp "$bootf" "$resumef"
    run_diff "$bootf" "$resumef" "$d/f.md"
    expect_has "F: parse warning counted for boot arm" "$d/f.md" \
        'warnings=1'
    expect_count "F: garbage line never parsed as data" "$d/f.md" 'not-a-record' 0
    expect_count "F: no table row carries the garbage line" "$d/f.md" '^\| .*not-a-record' 0

    # --- fixture G: --names mapping shows register names on rows ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b004=00000000"
    } > "$bootf"
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b004=40200000"
    } > "$resumef"
    printf '0x6b004 MIPI_INTR_STAT\n' > "$d/names.txt"
    run_diff "$bootf" "$resumef" "$d/g.md" "$d/names.txt"
    expect_has "G: named row shows the mapping name" "$d/g.md" \
        '^\| 0x6b004 MIPI_INTR_STAT '

    # --- fixture H (WR-01): marker keys to the DSI range ONLY - a corrupted
    # --- non-DSI section on the marker arm is parse-warning, never
    # --- skipped-pll-off (the benign skip must never mask a corruption
    # --- signal on the arm where a capture is most fragile) ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=00000001"
        echo "# RANGE 0x46000-0x47000 (1024 words)"
        echo "0x46000=00000002"
    } > "$bootf"
    printf '%s\n' "$SKIP_MARKER" > "$resumef"
    run_diff "$bootf" "$resumef" "$d/h.md"
    expect_count "H: DSI range still classifies skipped-pll-off" "$d/h.md" \
        '^\| 0x6b000-0x6c000 .*DSI block skipped: PLL off.*\| state \|' 1
    expect_has "H: corrupt 0x46000 section is parse-warning, NOT skipped-pll-off" \
        "$d/h.md" \
        '^\| 0x46000-0x47000 .*malformed dump.* \| parse-warning \|'
    expect_count "H: 0x46000 never inherits the PLL-off interpretation" "$d/h.md" \
        '0x46000-0x47000.*PLL off' 0
    expect_has "H: DSI state row cites the marker line on the resume arm" "$d/h.md" \
        'boot_dsi_regs\.txt:1; broken_dsi_regs\.txt:1'

    # --- fixture I (WR-02): the PHY skip marker keys to the PHY range only;
    # --- both markers gated, both state rows emitted with their own wording,
    # --- marker-free joinable range unaffected, per-range marker line cited ---
    {
        echo "# RANGE 0x6b000-0x6c000 (1024 words)"
        echo "0x6b000=00000001"
        echo "# RANGE 0x160000-0x164000 (4096 words)"
        echo "0x160018=00000115"
        echo "# RANGE 0x46000-0x47000 (1024 words)"
        echo "0x46000=00000002"
    } > "$bootf"
    {
        printf '%s\n' "$SKIP_MARKER"
        printf '%s\n' "$PHY_SKIP_MARKER"
        echo "# RANGE 0x46000-0x47000 (1024 words)"
        echo "0x46000=00000002"
    } > "$resumef"
    run_diff "$bootf" "$resumef" "$d/i.md"
    expect_has "I: PHY range classifies skipped-pll-off with PHY wording" "$d/i.md" \
        '^\| 0x160000-0x164000 .*DSI PHY block skipped: PLL off.* \| state \|'
    expect_has "I: DSI range keeps its own wording" "$d/i.md" \
        '^\| 0x6b000-0x6c000 .*DSI block skipped: PLL off.* \| state \|'
    expect_has "I: PHY row cites the PHY marker line on the resume arm" "$d/i.md" \
        'boot_dsi_regs\.txt:3; broken_dsi_regs\.txt:2'
    expect_has "I: joinable 0x46000 range unaffected by the markers" "$d/i.md" \
        'identical 0x46000-0x47000: 1 register'
    expect_count "I: zero per-register rows for the gated ranges" "$d/i.md" \
        '(^\| 0x6b000 [0-9a-f]|^\| 0x160018 )' 0

    rm -rf "$d"
    trap - EXIT

    echo "selftest summary: passed=$passed failed=$failed"
    [ "$failed" -eq 0 ]
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
main() {
    local boot="" resume="" out="" names="" selftest_only=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --selftest) selftest_only=1 ;;
            -o)   [ $# -ge 2 ] || die "-o requires a value";   out="$2";   shift ;;
            --names) [ $# -ge 2 ] || die "--names requires a value"; names="$2"; shift ;;
            -h|--help) usage; exit 0 ;;
            -*) usage >&2; exit 2 ;;
            *)
                if [ -z "$boot" ]; then boot="$1"
                elif [ -z "$resume" ]; then resume="$1"
                else usage >&2; exit 2
                fi
                ;;
        esac
        shift
    done

    if [ "$selftest_only" -eq 1 ]; then
        selftest
        return
    fi

    [ -n "$boot" ] && [ -n "$resume" ] || { usage >&2; exit 2; }
    [ -f "$boot" ] || die "boot dump not found: $boot"
    [ -f "$resume" ] || die "resume dump not found: $resume"

    if [ -n "$out" ]; then
        run_diff "$boot" "$resume" "$out" "$names"
    else
        local tmp
        tmp="$(mktemp)"
        run_diff "$boot" "$resume" "$tmp" "$names"
        cat "$tmp"
        rm -f "$tmp"
    fi
}

main "$@"
