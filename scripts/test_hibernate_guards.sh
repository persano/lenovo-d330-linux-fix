#!/usr/bin/env bash
# ==============================================================================
# scripts/test_hibernate_guards.sh
#
# Fixture-driven guard suite for tools/d330-auto-hibernate.py (Phase 33,
# audit C3 false safety net).
#
# Four env seams (D330_PROC_SWAPS, D330_SYS_POWER, D330_PROC_CMDLINE,
# D330_POWER_SUPPLY_DIR) point the daemon at fixture files, so every daemon
# case runs with no root, no battery, no systemd. Only daemon-produced markers
# and exit codes are asserted -- systemd/kernel refusal strings are
# version-dependent (33-RESEARCH R9) and are never matched. No case invokes
# the real systemctl, swapon, or filefrag.
#
# Cases (12): zram-only-refuse, swapfile-ready-proceed, safe-battery-report,
# resume-not-configured, hibernation-unavailable, empty-swaps-refuse,
# malformed-swaps-tolerated, no-battery-report-first,
# execstart-matches-install-path, type-oneshot-kept, udev-glob-comment,
# daemon-syntax-gates.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DAEMON="tools/d330-auto-hibernate.py"
SERVICE="patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service"
UDEV_RULE="patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules"
INSTALLER="scripts/install_dkms.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 33 hibernate guard suite (12 cases, env-seam fixtures, no root,
no battery, no systemd).

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
echo " Lenovo D330 Hibernate Guard Suite (env-seam fixtures)    "
echo "=========================================================="

passed=0
failed=0

# ------------------------------------------------------------------------------
# Fixtures (built once per run)
# ------------------------------------------------------------------------------
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
CASE_OUT="$FIX/case.out"

mkdir -p "$FIX/power/BAT0" "$FIX/power_none" \
         "$FIX/sys_ready" "$FIX/sys_noresume" "$FIX/sys_nodisk"

HDR="Filename				Type		Size		Used		Priority"
printf "%s\n/dev/zram0			partition	3145728		0		100\n" "$HDR" > "$FIX/sw_zram"
printf "%s\n/var/swapfile			file		4194304		0		-2\n/dev/zram0			partition	3145728		0		100\n" "$HDR" > "$FIX/sw_mixed"
printf "%s\n" "$HDR" > "$FIX/sw_empty"
printf "%s\nbroken-row-without-integers\n" "$HDR" > "$FIX/sw_bad"

echo disk > "$FIX/sys_ready/state";      echo "253:0" > "$FIX/sys_ready/resume"
echo disk > "$FIX/sys_noresume/state";   echo "0:0"   > "$FIX/sys_noresume/resume"
echo "freeze suspend" > "$FIX/sys_nodisk/state"; echo "0:0" > "$FIX/sys_nodisk/resume"

echo "BOOT_IMAGE=/vmlinuz root=UUID=x" > "$FIX/cmd_resume"
echo "BOOT_IMAGE=/vmlinuz root=UUID=x resume=UUID=x resume_offset=12345" > "$FIX/cmd_resume_set"

set_battery() {
    echo "$1" > "$FIX/power/BAT0/capacity"
    echo "$2" > "$FIX/power/BAT0/status"
}

# run_daemon <swaps> <sys_power> <cmdline> <power_supply_dir>
# Writes combined output to $CASE_OUT; sets $rc.
run_daemon() {
    rc=0
    D330_PROC_SWAPS="$1" D330_SYS_POWER="$2" D330_PROC_CMDLINE="$3" \
    D330_POWER_SUPPLY_DIR="$4" \
        python3 "$DAEMON" --dry-run > "$CASE_OUT" 2>&1 || rc=$?
}

# ------------------------------------------------------------------------------
# Assertion helpers (per-case failure accumulation; safe under set -e)
# ------------------------------------------------------------------------------
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

expect_no_out() {
    if grep -Fq -- "$1" "$CASE_OUT"; then
        echo "    [detail] output must not contain: $1"
        CASE_FAIL=1
    fi
}

# Assert $1 appears in output before $2 (report-first ordering proof)
expect_line_before() {
    local l1 l2
    l1=$(grep -nF -- "$1" "$CASE_OUT" | head -1 | cut -d: -f1 || true)
    l2=$(grep -nF -- "$2" "$CASE_OUT" | head -1 | cut -d: -f1 || true)
    if [ -z "${l1:-}" ] || [ -z "${l2:-}" ] || [ "$l1" -ge "$l2" ]; then
        echo "    [detail] expected '$1' before '$2' (got lines: '${l1:-none}' / '${l2:-none}')"
        CASE_FAIL=1
    fi
}

# Expect an exact line present in file $2 matching pattern $1 (static cases)
expect_file_out() {
    if ! grep -qF -- "$1" "$2"; then
        echo "    [detail] $2 missing: $1"
        CASE_FAIL=1
    fi
}

# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

case_zram_only_refuse() {
    set_battery 3 Discharging
    run_daemon "$FIX/sw_zram" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "type=zram"
    expect_out "hibernate readiness: NOT-READY (only zram swap present)"
    expect_out "[ERROR] hibernate skipped: only zram swap present"
    expect_out "[DRY-RUN] sync && systemctl suspend"
    expect_no_out "[DRY-RUN] sync && systemctl hibernate"
}

case_swapfile_ready_proceed() {
    set_battery 3 Discharging
    run_daemon "$FIX/sw_mixed" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "hibernate readiness: READY"
    expect_out "[DRY-RUN] sync && systemctl hibernate"
    expect_no_out "[ERROR]"
}

case_safe_battery_report() {
    set_battery 50 Discharging
    run_daemon "$FIX/sw_mixed" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "hibernate readiness: READY"
    expect_out "[OK] Battery level safe."
    expect_no_out "[DRY-RUN] sync"
}

case_resume_not_configured() {
    set_battery 3 Discharging
    run_daemon "$FIX/sw_mixed" "$FIX/sys_noresume" "$FIX/cmd_resume" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "hibernate readiness: NOT-READY (resume not configured)"
    expect_out "[ERROR] hibernate skipped: resume not configured"
    expect_out "[DRY-RUN] sync && systemctl suspend"
    expect_no_out "[DRY-RUN] sync && systemctl hibernate"
}

case_hibernation_unavailable() {
    set_battery 3 Discharging
    run_daemon "$FIX/sw_mixed" "$FIX/sys_nodisk" "$FIX/cmd_resume" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "hibernate readiness: NOT-READY (hibernation not offered by kernel)"
    expect_out "[ERROR] hibernate skipped: hibernation not offered by kernel"
    expect_out "[DRY-RUN] sync && systemctl suspend"
    expect_no_out "[DRY-RUN] sync && systemctl hibernate"
}

case_empty_swaps_refuse() {
    set_battery 3 Discharging
    run_daemon "$FIX/sw_empty" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "hibernate readiness: NOT-READY (no swap present)"
    expect_out "[ERROR] hibernate skipped: no swap present"
    expect_out "[DRY-RUN] sync && systemctl suspend"
    expect_no_out "[DRY-RUN] sync && systemctl hibernate"
}

case_malformed_swaps_tolerated() {
    set_battery 50 Discharging
    run_daemon "$FIX/sw_bad" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power"
    expect_rc_eq "$rc" 0
    expect_out "[OK] Battery level safe."
    expect_no_out "Traceback"
}

case_no_battery_report_first() {
    run_daemon "$FIX/sw_mixed" "$FIX/sys_ready" "$FIX/cmd_resume_set" "$FIX/power_none"
    expect_rc_eq "$rc" 0
    expect_out "[INFO] No battery power supply detected"
    expect_out "type="
    expect_line_before "type=" "[INFO] No battery power supply detected"
}

case_execstart_matches_install_path() {
    if ! grep -q "^ExecStart=/usr/local/bin/d330-auto-hibernate$" "$SERVICE"; then
        echo "    [detail] service ExecStart is not the installed path"
        CASE_FAIL=1
    fi
    if ! grep -qF 'cp "${REPO_ROOT}/tools/d330-auto-hibernate.py" /usr/local/bin/d330-auto-hibernate' "$INSTALLER"; then
        echo "    [detail] installer copy target missing"
        CASE_FAIL=1
    fi
}

case_type_oneshot_kept() {
    if ! grep -q "^Type=oneshot$" "$SERVICE"; then
        echo "    [detail] Type=oneshot missing"
        CASE_FAIL=1
    fi
    if ! grep -q "SYSTEMD_WANTS" "$SERVICE"; then
        echo "    [detail] SYSTEMD_WANTS rationale comment missing"
        CASE_FAIL=1
    fi
    if ! grep -q "re-fire" "$SERVICE"; then
        echo "    [detail] re-fire rationale comment missing"
        CASE_FAIL=1
    fi
}

case_udev_glob_comment() {
    if ! grep -q "udev glob" "$UDEV_RULE"; then
        echo "    [detail] udev glob comment missing"
        CASE_FAIL=1
    fi
    if ! grep -q "0-5" "$UDEV_RULE"; then
        echo "    [detail] 0-5 comment missing"
        CASE_FAIL=1
    fi
    expect_file_out 'SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", TAG+="systemd", ENV{SYSTEMD_WANTS}="d330-auto-hibernate.service"' "$UDEV_RULE"
}

case_daemon_syntax_gates() {
    local rc=0
    python3 -m py_compile "$DAEMON" || rc=$?
    expect_rc_eq "$rc" 0
}

# ------------------------------------------------------------------------------
# Runner
# ------------------------------------------------------------------------------
CASE_NAMES=(
    case_zram_only_refuse
    case_swapfile_ready_proceed
    case_safe_battery_report
    case_resume_not_configured
    case_hibernation_unavailable
    case_empty_swaps_refuse
    case_malformed_swaps_tolerated
    case_no_battery_report_first
    case_execstart_matches_install_path
    case_type_oneshot_kept
    case_udev_glob_comment
    case_daemon_syntax_gates
)

for fn in "${CASE_NAMES[@]}"; do
    CASE_FAIL=0
    rc=0
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
