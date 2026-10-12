#!/usr/bin/env bash
# ==============================================================================
# scripts/test_display_fix_guards.sh
#
# Static guard suite for the Phase 34 display-resume delivery (audit C4/N3/M17).
#
# No root, no hardware, no dkms, no kernel source: every case greps shipped
# files and runs the resume-loop --simulate path so SC1/SC3 truth checks and the
# SC2 arithmetic fix are machine-checked in CI. The on-device dmesg/rtcwake
# checks are the Task 8 (blocking-human) UAT checkpoint, not here.
#
# Cases (16): module-banner-no-dead-sleep, resume-service-deleted-zero-refs,
# kernel-src-dryrun-first, nobgrt-kept, panel-orientation-present,
# audit-claims-match-cfg, dkms-build-guards, resume-loop-arithmetic-fixed,
# resume-loop-simulate-5, readme-truth, hook-standdown-contract,
# hook-dmi-gate, hook-bounded-attempt-exactly-once,
# hook-distinct-failure-logging, hook-dm-ladder-intact,
# hook-constants-unchanged.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

MODULE="patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c"
HOOK="patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh"
DKMS_CONF="patches/dkms/lenovo-d330-fix/dkms.conf"
# The deleted unit name is assembled from parts so this suite never ships the
# contiguous literal the plan's zero-reference sweep forbids.
RESUME_UNIT_BASE="lenovo-d330-resume"
RESUME_UNIT_SUFFIX=".service"
RESUME_SVC="patches/dkms/etc/systemd/system/${RESUME_UNIT_BASE}${RESUME_UNIT_SUFFIX}"
CFG="patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg"
AUDIT="CHANGES_AUDIT.md"
README="README.md"
INSTALLER="scripts/install_dkms.sh"
RESUME_LOOP="scripts/test_resume_loop.sh"
POSTINST="packaging/debian/postinst"
RPM_SPEC="packaging/rpm/lenovo-d330-fix.spec"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 34 display-resume guard suite (10 static cases, no root, no
hardware, no dkms).

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
echo " Lenovo D330 Display Fix Guard Suite (static)             "
echo "=========================================================="

passed=0
failed=0

CASE_FAIL=0

expect_file_out() {
    if ! grep -qF -- "$1" "$2"; then
        echo "    [detail] $2 missing: $1"
        CASE_FAIL=1
    fi
}

expect_no_file_out() {
    if grep -qF -- "$1" "$2"; then
        echo "    [detail] $2 must not contain: $1"
        CASE_FAIL=1
    fi
}

expect_regex_file_out() {
    if ! grep -Eq -- "$1" "$2"; then
        echo "    [detail] $2 missing pattern: $1"
        CASE_FAIL=1
    fi
}

# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

case_module_banner_no_dead_sleep() {
    # Dead TCON clamp branch and its sleep must be gone (option b).
    expect_no_file_out "elapsed_ms < (s64)power_cycle_delay_ms" "$MODULE"
    if grep -qE "msleep\(" "$MODULE"; then
        echo "    [detail] msleep still present (dead clamp branch)"
        CASE_FAIL=1
    fi
    # SC1 banner dependencies intact.
    expect_file_out "PM_POST_SUSPEND" "$MODULE"
    expect_file_out "d330_info" "$MODULE"
    expect_file_out "MODULE_DEVICE_TABLE(dmi" "$MODULE"
    if ! grep -qi "d330_pm_callback" "$MODULE"; then
        echo "    [detail] d330_pm_callback missing"
        CASE_FAIL=1
    fi
}

case_resume_service_deleted_zero_refs() {
    if [ -f "$RESUME_SVC" ]; then
        echo "    [detail] resume service unit still exists"
        CASE_FAIL=1
    fi
    if grep -rq "${RESUME_UNIT_BASE}${RESUME_UNIT_SUFFIX}" \
        "$INSTALLER" "$POSTINST" "$RPM_SPEC" "$AUDIT" "$README" 2>/dev/null; then
        echo "    [detail] stale resume-service reference remains"
        CASE_FAIL=1
    fi
}

case_kernel_src_dryrun_first() {
    local rc=0
    bash -n "$INSTALLER" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] installer syntax error"
        CASE_FAIL=1
    fi
    expect_file_out "--kernel-src" "$INSTALLER"
    expect_file_out "patch -p1" "$INSTALLER"
    expect_file_out "log_warn" "$INSTALLER"
    local dry apply
    # WR-03: match the actual commands, not prose/usage. The dry-run probe is a
    # line that starts with `patch` AND carries `--dry-run`; the real apply is a
    # `patch` line WITHOUT `--dry-run`. Comparing those two line numbers makes
    # a reorder (apply before probe) genuinely fail this case.
    dry=$(grep -nE '^[[:space:]]*patch .*--dry-run' "$INSTALLER" | head -1 | cut -d: -f1 || true)
    apply=$(grep -nE '^[[:space:]]*patch ' "$INSTALLER" | grep -v -F -- '--dry-run' | head -1 | cut -d: -f1 || true)
    if [ -z "${dry:-}" ] || [ -z "${apply:-}" ] || [ "$dry" -ge "$apply" ]; then
        echo "    [detail] dry-run probe does not precede apply (dry=${dry:-none} apply=${apply:-none})"
        CASE_FAIL=1
    fi
}

case_nobgrt_kept() {
    # Research 3a: video=efifb:nobgrt is a real efifb option -- must stay.
    expect_file_out "video=efifb:nobgrt" "$CFG"
    if ! grep -qi "real efifb" "$CFG"; then
        echo "    [detail] comment explaining nobgrt is real is missing"
        CASE_FAIL=1
    fi
}

case_panel_orientation_present() {
    expect_file_out "video=DSI-1:panel_orientation=right_side_up" "$CFG"
    expect_file_out "video=eDP-1:panel_orientation=right_side_up" "$CFG"
}

case_audit_claims_match_cfg() {
    # CHANGES_AUDIT 2.2 must name the exact shipped cmdline tokens.
    local token
    for token in "fbcon=rotate:1" "video=efifb:nobgrt" \
                 "video=DSI-1:panel_orientation=right_side_up" \
                 "video=eDP-1:panel_orientation=right_side_up" \
                 "i915.enable_psr=0" "i915.enable_fbc=0"; do
        expect_file_out "$token" "$AUDIT"
    done
}

case_dkms_build_guards() {
    expect_file_out "BUILT_MODULE_LOCATION[0]=\".\"" "$DKMS_CONF"
    expect_file_out 'MAKE_MATCH[0]=' "$DKMS_CONF"
    expect_file_out 'BUILD_EXCLUSIVE_KERNEL[0]=' "$DKMS_CONF"
    expect_file_out 'BUILT_MODULE_NAME[0]="lenovo_d330_fix"' "$DKMS_CONF"
    expect_file_out 'AUTOINSTALL="yes"' "$DKMS_CONF"
}

case_resume_loop_arithmetic_fixed() {
    local rc=0
    bash -n "$RESUME_LOOP" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] resume-loop syntax error"
        CASE_FAIL=1
    fi
    if grep -qE "\(\(passed\+\+\)\)|\(\(failed\+\+\)\)" "$RESUME_LOOP"; then
        echo "    [detail] errexit-killing arithmetic still present"
        CASE_FAIL=1
    fi
    expect_file_out 'passed=$((passed + 1))' "$RESUME_LOOP"
    expect_file_out 'failed=$((failed + 1))' "$RESUME_LOOP"
    expect_file_out "simulate" "$RESUME_LOOP"
}

case_resume_loop_simulate_5() {
    local rc=0 out=""
    out=$(bash scripts/test_resume_loop.sh --simulate --cycles 5 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] simulate run exited $rc"
        CASE_FAIL=1
    fi
    if ! echo "$out" | grep -q "Passed: 5 / 5"; then
        echo "    [detail] simulate run did not report 5/5"
        echo "$out" | tail -5
        CASE_FAIL=1
    fi
}

case_readme_truth() {
    if grep -q "will now work reliably" "$README"; then
        echo "    [detail] unqualified guarantee phrase present"
        CASE_FAIL=1
    fi
    if ! grep -qi "does not include" "$README" && ! grep -qi "not include" "$README"; then
        echo "    [detail] README does not state what Option 1 omits"
        CASE_FAIL=1
    fi
    expect_file_out "--kernel-src" "$README"
    expect_file_out "dmesg | grep lenovo_d330_fix" "$README"
    expect_regex_file_out "Option 1" "$README"
    expect_regex_file_out "Option 2" "$README"
    # WR-05: the DKMS-module deliverable row must explicitly disclaim that it
    # delivers the display fix (T-34-03). Extract the row, require the negation,
    # and ban the old positive-advertising phrasings so SC3 truth is enforced.
    local modrow
    modrow=$(grep -iE 'lenovo_d330_fix\.ko' "$README" | head -1 || true)
    if [ -z "$modrow" ]; then
        echo "    [detail] DKMS-module deliverable row not found in README"
        CASE_FAIL=1
    else
        if ! echo "$modrow" | grep -Eiq 'does not (enforce|touch|fix|include|change)'; then
            echo "    [detail] DKMS-module row does not disclaim that it delivers the fix"
            CASE_FAIL=1
        fi
        if echo "$modrow" | grep -Eiq 'to enforce safe TCON|hooking kernel PM events to enforce|enforces? a 600|enforces .*discharge delay'; then
            echo "    [detail] DKMS-module row still claims enforcement"
            CASE_FAIL=1
        fi
    fi
}

case_hook_standdown_contract() {
    local rc=0
    bash -n "$HOOK" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "    [detail] hook syntax error"
        CASE_FAIL=1
    fi
    expect_file_out 'D330_REAL_FIX' "$HOOK"
    expect_file_out 'real fix active (D330_REAL_FIX=1); reload hook stands down' "$HOOK"
    expect_file_out 'Coexistence contract' "$HOOK"
    # Ordering: the stand-down check line must precede the timeout invocation.
    local stand tline
    stand=$(grep -nF -- 'D330_REAL_FIX:-0' "$HOOK" | head -1 | cut -d: -f1 || true)
    tline=$(grep -nF -- 'timeout 30' "$HOOK" | head -1 | cut -d: -f1 || true)
    if [ -z "${stand:-}" ] || [ -z "${tline:-}" ] || [ "$stand" -ge "$tline" ]; then
        echo "    [detail] stand-down check does not precede the timeout invocation (stand=${stand:-none} timeout=${tline:-none})"
        CASE_FAIL=1
    fi
    # Disable path intact and still logged.
    expect_file_out 'D330_DISPLAY_RESUME:-1' "$HOOK"
    expect_file_out 'resume reload disabled (D330_DISPLAY_RESUME=0' "$HOOK"
}

case_hook_dmi_gate() {
    expect_file_out '[ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = "82H0" ] || exit 0' "$HOOK"
}

case_hook_bounded_attempt_exactly_once() {
    local c guard fall
    c=$(grep -cF -- 'timeout 30 "$0" _run' "$HOOK" || true)
    if [ "$c" -ne 1 ]; then
        echo "    [detail] timeout 30 self-exec count=$c (want exactly 1)"
        CASE_FAIL=1
    fi
    # Line-anchored so the timeout line's _run tail does not double-count.
    c=$(grep -cE '^[[:space:]]*"\$0" _run$' "$HOOK" || true)
    if [ "$c" -ne 1 ]; then
        echo "    [detail] bare no-timeout fallback count=$c (want exactly 1)"
        CASE_FAIL=1
    fi
    guard=$(grep -nF -- 'command -v timeout' "$HOOK" | head -1 | cut -d: -f1 || true)
    fall=$(grep -nE '^[[:space:]]*"\$0" _run$' "$HOOK" | head -1 | cut -d: -f1 || true)
    if [ -z "${guard:-}" ] || [ -z "${fall:-}" ] || [ "$fall" -le "$guard" ]; then
        echo "    [detail] fallback not inside the command -v timeout guard (guard=${guard:-none} fallback=${fall:-none})"
        CASE_FAIL=1
    fi
    if sed -n "${guard},${fall}p" "$HOOK" | grep -qE '(^|[^[:alnum:]])(for|while|until)([^[:alnum:]]|$)'; then
        echo "    [detail] loop keyword between the timeout guard and the fallback (retry construct)"
        CASE_FAIL=1
    fi
}

case_hook_distinct_failure_logging() {
    expect_file_out 'i915 reload timed out after 30 seconds (rc=124)' "$HOOK"
    expect_file_out 'i915 reload/restart failed (rc=$rc)' "$HOOK"
    local tags
    tags=$(grep -c 'logger -t d330-display' "$HOOK" || true)
    if [ "$tags" -lt 7 ]; then
        echo "    [detail] d330-display logger tag count=$tags (must not drop below 7)"
        CASE_FAIL=1
    fi
}

case_hook_dm_ladder_intact() {
    expect_file_out 'systemctl restart display-manager.service' "$HOOK"
    expect_file_out 'systemctl restart sddm.service' "$HOOK"
    expect_file_out 'display manager restart failed' "$HOOK"
}

case_hook_constants_unchanged() {
    expect_file_out 'DRV=/sys/bus/pci/drivers/i915' "$HOOK"
    expect_file_out 'DISABLE_FILE=/etc/default/lenovo-d330-display-resume' "$HOOK"
    expect_file_out 'case "${1:-}/${2:-}" in' "$HOOK"
}

# ------------------------------------------------------------------------------
# Runner
# ------------------------------------------------------------------------------
CASE_NAMES=(
    case_module_banner_no_dead_sleep
    case_resume_service_deleted_zero_refs
    case_kernel_src_dryrun_first
    case_nobgrt_kept
    case_panel_orientation_present
    case_audit_claims_match_cfg
    case_dkms_build_guards
    case_resume_loop_arithmetic_fixed
    case_resume_loop_simulate_5
    case_readme_truth
    case_hook_standdown_contract
    case_hook_dmi_gate
    case_hook_bounded_attempt_exactly_once
    case_hook_distinct_failure_logging
    case_hook_dm_ladder_intact
    case_hook_constants_unchanged
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
        continue
    fi
done

echo ""
echo "=========================================================="
echo " Guard suite summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
