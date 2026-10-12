#!/usr/bin/env bash
# ==============================================================================
# scripts/test_safety_kit.sh
#
# Fixture guard suite for the off-device safety-kit pipeline (Phase 43,
# GUARD-03): scripts/prepare_safety_kit.sh register/verify round trip against a
# mktemp kit dir, plus the capture-protocol doc completeness check.
#
# No root, no hardware: every case runs the kit utility inside a fixture dir or
# greps shipped files. Pristine-first ordering (SC1 rule): the verify-passes
# case runs BEFORE any tamper case, so tamper detection cannot pass vacuously.
#
# Cases (6): prep-script-syntax, register-creates-manifest,
# verify-passes-pristine, verify-fails-on-tamper,
# manifest-format-rejects-junk, protocol-doc-complete.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

KIT_SCRIPT="scripts/prepare_safety_kit.sh"
PROTOCOL_DOC="docs/research/RESUME_CAPTURE_PROTOCOL.md"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 43 safety-kit guard suite (6 fixture/static cases, no root, no
hardware).

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
echo " Lenovo D330 Safety Kit Guard Suite                       "
echo "=========================================================="

passed=0
failed=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
CASE_OUT="$FIX/case.out"

CASE_FAIL=0

expect_rc_eq() {
    if [ "$1" -ne "$2" ]; then
        echo "    [detail] expected rc=$2, got rc=$1"
        CASE_FAIL=1
    fi
}

expect_out() {
    if ! grep -Fq -- "$1" "$CASE_OUT"; then
        echo "    [detail] output missing: $1"
        CASE_FAIL=1
    fi
}

expect_file_out() {
    if ! grep -qF -- "$1" "$2"; then
        echo "    [detail] $2 missing: $1"
        CASE_FAIL=1
    fi
}

# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

case_prep_script_syntax() {
    local rc=0
    bash -n "$KIT_SCRIPT" || rc=$?
    expect_rc_eq "$rc" 0
}

case_register_creates_manifest() {
    local R
    R="$(mktemp -d "$FIX/kit_reg_XXXXXX")"
    printf 'golden-module-bytes-v1\n' > "$R/golden_i915.ko.zst"
    printf 'live-iso-bytes-v1\n' > "$R/live_iso.img"
    local rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --register golden_i915.ko.zst --register live_iso.img || rc=$?
    expect_rc_eq "$rc" 0
    if [ ! -f "$R/MANIFEST.sha256" ]; then
        echo "    [detail] MANIFEST.sha256 not created"
        CASE_FAIL=1
        return 0
    fi
    # Strict format: 64 hex chars, exactly two spaces, kit-relative path that
    # stays inside the kit dir (no leading slash, no .. segments).
    if grep -qvE '^[0-9a-f]{64}  [A-Za-z0-9._/-]+$' "$R/MANIFEST.sha256"; then
        echo "    [detail] manifest line outside the strict <hash>  <relative-path> format:"
        grep -vE '^[0-9a-f]{64}  [A-Za-z0-9._/-]+$' "$R/MANIFEST.sha256" || true
        CASE_FAIL=1
    fi
    if grep -qE '(^|[[:space:]])/' "$R/MANIFEST.sha256" || grep -qF -- '..' "$R/MANIFEST.sha256"; then
        echo "    [detail] manifest path escapes the kit dir"
        CASE_FAIL=1
    fi
    # Idempotent re-register: line count must not grow.
    local before after
    before="$(wc -l < "$R/MANIFEST.sha256")"
    bash "$KIT_SCRIPT" --kit-dir "$R" --register golden_i915.ko.zst || { echo "    [detail] re-register failed"; CASE_FAIL=1; }
    after="$(wc -l < "$R/MANIFEST.sha256")"
    if [ "$before" -ne "$after" ]; then
        echo "    [detail] re-register grew the manifest ($before -> $after lines)"
        CASE_FAIL=1
    fi
    # The refreshed line must carry the SAME hash (artifact unchanged).
    local h1 h2
    h1="$(awk '{print $1}' "$R/MANIFEST.sha256")"
    h2="$(sha256sum "$R/golden_i915.ko.zst" | awk '{print $1}')"
    if ! grep -qF "$h2" "$R/MANIFEST.sha256"; then
        echo "    [detail] manifest hash does not match the artifact after re-register"
        CASE_FAIL=1
    fi
}

case_verify_passes_pristine() {
    local R rc=0
    R="$(mktemp -d "$FIX/kit_pristine_XXXXXX")"
    printf 'pristine-artifact\n' > "$R/artifact.bin"
    bash "$KIT_SCRIPT" --kit-dir "$R" --register artifact.bin >/dev/null 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --verify > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "artifact.bin: OK"
}

case_verify_fails_on_tamper() {
    local R rc=0
    R="$(mktemp -d "$FIX/kit_tamper_XXXXXX")"
    printf 'tamper-target-bytes\n' > "$R/restore_candidate.img"
    cp "$R/restore_candidate.img" "$R/.restore_copy"
    bash "$KIT_SCRIPT" --kit-dir "$R" --register restore_candidate.img >/dev/null 2>&1
    # Pristine verify is green (baseline before mutation).
    rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --verify >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] pristine kit failed verify before any tamper (rc=$rc)"
        CASE_FAIL=1
    fi
    # Tamper: one appended byte flips verify to non-zero.
    printf 'x' >> "$R/restore_candidate.img"
    rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --verify > "$CASE_OUT" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "    [detail] tampered kit verified clean"
        CASE_FAIL=1
    fi
    expect_out "FAILED"
    # Restore: verify is green again.
    mv "$R/.restore_copy" "$R/restore_candidate.img"
    rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --verify >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] restored kit still fails verify (rc=$rc)"
        CASE_FAIL=1
    fi
}

case_manifest_format_rejects_junk() {
    local R rc=0
    R="$(mktemp -d "$FIX/kit_junk_XXXXXX")"
    printf 'junk-format-probe\n' > "$R/junk.bin"
    bash "$KIT_SCRIPT" --kit-dir "$R" --register junk.bin >/dev/null 2>&1
    # Malformed manifest: a truncated hash (3 hex chars, two spaces). GNU
    # sha256sum -c happens to tolerate a one-space separator for simple names,
    # so the fail-closed proof uses a form it always rejects; the strict
    # two-space registered format is separately enforced by the regex check in
    # register-creates-manifest.
    printf 'abc123  junk.bin\n' > "$R/MANIFEST.sha256"
    rc=0
    bash "$KIT_SCRIPT" --kit-dir "$R" --verify > "$CASE_OUT" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "    [detail] malformed (truncated-hash) manifest line verified clean"
        CASE_FAIL=1
    fi
    expect_out "no properly formatted checksum lines"
}

case_protocol_doc_complete() {
    if [ ! -f "$PROTOCOL_DOC" ]; then
        echo "    [detail] protocol doc missing: $PROTOCOL_DOC"
        CASE_FAIL=1
        return 0
    fi
    expect_file_out 'systemd-inhibit --what=idle' "$PROTOCOL_DOC"
    expect_file_out '18' "$PROTOCOL_DOC"
    expect_file_out 'rtcwake -m mem' "$PROTOCOL_DOC"
    expect_file_out 'cold boot' "$PROTOCOL_DOC"
    expect_file_out 'unbind' "$PROTOCOL_DOC"
    expect_file_out 'strip --strip-debug' "$PROTOCOL_DOC"
    expect_file_out 'zstd -19' "$PROTOCOL_DOC"
    expect_file_out 'depmod -a' "$PROTOCOL_DOC"
    expect_file_out 'update-initramfs -u' "$PROTOCOL_DOC"
    expect_file_out '--register' "$PROTOCOL_DOC"
    expect_file_out '--verify' "$PROTOCOL_DOC"
    expect_file_out 'D330' "$PROTOCOL_DOC"
    expect_file_out 'pr_err' "$PROTOCOL_DOC"
    expect_file_out 'DSI_RESUME_TRACE_ANALYSIS.md' "$PROTOCOL_DOC"
    expect_file_out 'DISPLAY_RESUME_CCS_MODIFIER.md' "$PROTOCOL_DOC"
    expect_file_out 'build_live_iso.sh' "$PROTOCOL_DOC"
    expect_file_out 'prepare_safety_kit.sh' "$PROTOCOL_DOC"
    expect_file_out 'D330_REAL_FIX' "$PROTOCOL_DOC"
}

# ------------------------------------------------------------------------------
# Runner
# ------------------------------------------------------------------------------
CASE_NAMES=(
    case_prep_script_syntax
    case_register_creates_manifest
    case_verify_passes_pristine
    case_verify_fails_on_tamper
    case_manifest_format_rejects_junk
    case_protocol_doc_complete
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
echo " Safety kit suite summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
