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
# Cases (10): module-banner-no-dead-sleep, resume-service-deleted-zero-refs,
# kernel-src-dryrun-first, nobgrt-kept, panel-orientation-present,
# audit-claims-match-cfg, dkms-build-guards, resume-loop-arithmetic-fixed,
# resume-loop-simulate-5, readme-truth.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

MODULE="patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c"
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
    dry=$(grep -n -- "--dry-run" "$INSTALLER" | head -1 | cut -d: -f1 || true)
    apply=$(grep -n "patch -p1 -d .* <" "$INSTALLER" | head -1 | cut -d: -f1 || true)
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
