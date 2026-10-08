#!/usr/bin/env bash
# ==============================================================================
# scripts/test_hibernate_guards.sh
#
# Fixture-driven guard suite for tools/d330-auto-hibernate.py (Phase 33,
# audit C3 false safety net).
#
# Five env seams (D330_PROC_SWAPS, D330_SYS_POWER, D330_PROC_CMDLINE,
# D330_POWER_SUPPLY_DIR, D330_SYSTEMCTL) point the daemon at fixture files
# and a stub systemctl, so every daemon case runs with no root, no battery,
# no systemd. Only daemon-produced markers and exit codes are asserted --
# systemd/kernel refusal strings are version-dependent (33-RESEARCH R9) and
# are never matched. No case invokes the real systemctl, swapon, or filefrag.
#
# Cases (21): zram-only-refuse, swapfile-ready-proceed, safe-battery-report,
# resume-not-configured, hibernation-unavailable, empty-swaps-refuse,
# malformed-swaps-tolerated, no-battery-report-first,
# execstart-matches-install-path, type-oneshot-kept, udev-glob-comment,
# daemon-syntax-gates, enable-site-install-dkms, enable-site-debian-postinst,
# enable-site-rpm-spec, swapfile-unit-static, resume-snippet-template,
# installer-activation-step, uninstall-symmetry, readme-docs-anchors,
# rc-propagates.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DAEMON="tools/d330-auto-hibernate.py"
SERVICE="patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service"
SWAPFILE_UNIT="patches/power_hibernate/etc/systemd/system/d330-swapfile.service"
RESUME_SNIPPET="patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg"
UDEV_RULE="patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules"
INSTALLER="scripts/install_dkms.sh"
DEBIAN_POSTINST="packaging/debian/postinst"
DEBIAN_RULES="packaging/debian/rules"
RPM_SPEC="packaging/rpm/lenovo-d330-fix.spec"
PKGBUILD="packaging/arch/PKGBUILD"
README="patches/power_hibernate/README.md"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 33 hibernate guard suite (21 cases, env-seam fixtures, no root,
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
    # Packaging must install the suffix-free daemon name ExecStart= needs, mode
    # 755. Each packager renames via a loop that lists d330-auto-hibernate.py and
    # chmods the whole /usr/local/bin dir (review CR-01; parity with installer).
    if ! grep -qF 'd330-auto-hibernate.py' "$RPM_SPEC" \
       || ! grep -qF 'chmod 755 %{buildroot}/usr/local/bin/*' "$RPM_SPEC"; then
        echo "    [detail] rpm spec does not install the suffix-free daemon name / chmod 755"
        CASE_FAIL=1
    fi
    if ! grep -qF 'd330-auto-hibernate.py' "$DEBIAN_RULES" \
       || ! grep -qF 'chmod 755 debian/lenovo-d330-fix/usr/local/bin/*' "$DEBIAN_RULES"; then
        echo "    [detail] debian rules do not install the suffix-free daemon name / chmod 755"
        CASE_FAIL=1
    fi
    if ! grep -qF 'd330-auto-hibernate.py' "$PKGBUILD" \
       || ! grep -qF 'chmod 755 "${pkgdir}"/usr/local/bin/*' "$PKGBUILD"; then
        echo "    [detail] PKGBUILD does not install the suffix-free daemon name / chmod 755"
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

# --- Plan 33-02 static guards (SC3 enable sites, assets, installer, symmetry) ---

# Both enable lines present in $1 installer file, in one helper.
expect_enable_sites() {
    if ! grep -q "systemctl enable d330-auto-hibernate.service" "$1"; then
        echo "    [detail] $1 missing: systemctl enable d330-auto-hibernate.service"
        CASE_FAIL=1
    fi
    if ! grep -q "systemctl enable d330-swapfile.service" "$1"; then
        echo "    [detail] $1 missing: systemctl enable d330-swapfile.service"
        CASE_FAIL=1
    fi
}

case_enable_site_install_dkms() {
    expect_enable_sites "$INSTALLER"
    # Both must land in the enable block, before the block's success message.
    local line_enable line_ok
    line_enable=$(grep -n "systemctl enable d330-swapfile.service" "$INSTALLER" | head -1 | cut -d: -f1 || true)
    line_ok=$(grep -n 'log_ok "Enabled systemd background units."' "$INSTALLER" | head -1 | cut -d: -f1 || true)
    if [ -z "${line_enable:-}" ] || [ -z "${line_ok:-}" ] || [ "$line_enable" -ge "$line_ok" ]; then
        echo "    [detail] swapfile enable not before the enable-block log_ok line"
        CASE_FAIL=1
    fi
}

case_enable_site_debian_postinst() {
    expect_enable_sites "$DEBIAN_POSTINST"
    # Placement: after the existing six enables, before update-initramfs.
    local line_enable line_init
    line_enable=$(grep -n "systemctl enable d330-swapfile.service" "$DEBIAN_POSTINST" | head -1 | cut -d: -f1 || true)
    line_init=$(grep -n "update-initramfs" "$DEBIAN_POSTINST" | head -1 | cut -d: -f1 || true)
    if [ -z "${line_enable:-}" ] || [ -z "${line_init:-}" ] || [ "$line_enable" -ge "$line_init" ]; then
        echo "    [detail] swapfile enable not before update-initramfs in postinst"
        CASE_FAIL=1
    fi
}

case_enable_site_rpm_spec() {
    # Inside %post: enable lines must come after the %post header.
    local line_post line_enable
    line_post=$(grep -n "^%post" "$RPM_SPEC" | head -1 | cut -d: -f1 || true)
    line_enable=$(grep -n "systemctl enable d330-swapfile.service" "$RPM_SPEC" | head -1 | cut -d: -f1 || true)
    if [ -z "${line_post:-}" ] || [ -z "${line_enable:-}" ] || [ "$line_enable" -le "$line_post" ]; then
        echo "    [detail] enable lines not inside rpm %post"
        CASE_FAIL=1
    fi
    expect_enable_sites "$RPM_SPEC"
    # Enable-only this phase (R8): no %preun invented; gap recorded for Phase 35.
    if grep -q "%preun" "$RPM_SPEC"; then
        echo "    [detail] %preun was invented (Phase 35 owns uninstall symmetry)"
        CASE_FAIL=1
    fi
}

case_swapfile_unit_static() {
    expect_file_out "Type=oneshot" "$SWAPFILE_UNIT"
    expect_file_out "WantedBy=multi-user.target" "$SWAPFILE_UNIT"
    # Existence guard: creation only when absent (never recreate, R4).
    expect_file_out "[ -e /var/swapfile ]" "$SWAPFILE_UNIT"
    expect_file_out "dd if=/dev/zero" "$SWAPFILE_UNIT"
    expect_file_out "chmod 600" "$SWAPFILE_UNIT"
    expect_file_out "mkswap" "$SWAPFILE_UNIT"
    expect_file_out "4096" "$SWAPFILE_UNIT"
    expect_file_out "8192" "$SWAPFILE_UNIT"
    expect_file_out "df --output=avail" "$SWAPFILE_UNIT"
    expect_file_out "[WARN]" "$SWAPFILE_UNIT"
    # systemd expands ${...} inside ExecStart (undefined -> empty), so the WARN
    # numbers must be doubled for /bin/sh to see them (review WR-01).
    expect_file_out '$${NEED}' "$SWAPFILE_UNIT"
    expect_file_out '$${AVAIL}' "$SWAPFILE_UNIT"
    # Creation sequence appears exactly once, only in the file-absent branch.
    local dd_count
    dd_count=$(grep -c "dd if=/dev/zero" "$SWAPFILE_UNIT" || true)
    if [ "$dd_count" -ne 1 ]; then
        echo "    [detail] expected exactly 1 dd creation line, got $dd_count"
        CASE_FAIL=1
    fi
}

case_resume_snippet_template() {
    expect_file_out 'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} resume=UUID=__D330_RESUME_UUID__ resume_offset=__D330_RESUME_OFFSET__"' "$RESUME_SNIPPET"
    # No machine-derived values ship in the template.
    if grep -Eq "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" "$RESUME_SNIPPET"; then
        echo "    [detail] real UUID shipped in template"
        CASE_FAIL=1
    fi
    if grep -Eq "resume_offset=[0-9]+" "$RESUME_SNIPPET"; then
        echo "    [detail] numeric offset shipped in template"
        CASE_FAIL=1
    fi
    if ! grep -qi "install" "$RESUME_SNIPPET"; then
        echo "    [detail] install-time render comment missing"
        CASE_FAIL=1
    fi
}

case_installer_activation_step() {
    # Positive static greps only (daemon-marker style, no real binaries run).
    # Clamp/free-space guard are asserted against the unit by swapfile-unit-static.
    expect_file_out "filefrag -v" "$INSTALLER"
    expect_file_out "update-grub" "$INSTALLER"
    expect_file_out "grub2-mkconfig" "$INSTALLER"
    expect_file_out "grub-mkconfig" "$INSTALLER"
    expect_file_out "resume_offset=" "$INSTALLER"
    expect_file_out "update-initramfs" "$INSTALLER"
    expect_file_out "/var/swapfile none swap sw 0 0" "$INSTALLER"
    expect_file_out "resume=UUID=" "$INSTALLER"
    expect_file_out "systemctl start d330-swapfile.service" "$INSTALLER"
    expect_file_out "stat -f -c %S" "$INSTALLER"
    expect_file_out "getconf PAGESIZE" "$INSTALLER"
    # Fail-closed positive-number check on both values (review IN-03):
    # 0=0 from two failed commands must not satisfy the guard.
    expect_file_out '^[1-9][0-9]*$' "$INSTALLER"
    # The invalid swapon OFFSET-column variant must never appear (Q1.4).
    if grep -q "show=OFFSET" "$INSTALLER"; then
        echo "    [detail] invalid offset column referenced"
        CASE_FAIL=1
    fi
    # Manual-step honesty: non-zero exit in the verify-failure branch.
    if ! grep -q "exit 1" "$INSTALLER"; then
        echo "    [detail] manual-step non-zero exit missing"
        CASE_FAIL=1
    fi
}

case_uninstall_symmetry() {
    # Six coverage points: snippet rm, unit disable, unit rm, swapoff,
    # fstab-line removal, and the pre-existing daemon coverage still present.
    expect_file_out "rm -f /etc/default/grub.d/53-lenovo-d330-resume.cfg" "$INSTALLER"
    expect_file_out "systemctl disable --now d330-swapfile.service" "$INSTALLER"
    expect_file_out "rm -f /etc/systemd/system/d330-swapfile.service" "$INSTALLER"
    expect_file_out "swapoff /var/swapfile" "$INSTALLER"
    if ! grep -E -q "sed .*/var/swapfile none swap|grep -v .*/var/swapfile none swap" "$INSTALLER"; then
        echo "    [detail] fstab swap-line removal missing"
        CASE_FAIL=1
    fi
    # Removal must be exact-match anchored (review IN-01), install-side style.
    expect_file_out 'grep -v -xF "/var/swapfile none swap sw 0 0"' "$INSTALLER"
    expect_file_out 'grep -qxF "/var/swapfile none swap sw 0 0" /etc/fstab' "$INSTALLER"
    expect_file_out "rm -f /usr/local/bin/d330-auto-hibernate" "$INSTALLER"
    expect_file_out "systemctl disable --now d330-auto-hibernate.service" "$INSTALLER"
    expect_file_out "rm -f /etc/systemd/system/d330-auto-hibernate.service" "$INSTALLER"
}

# --- Plan 33-03 docs guard (README claims cannot drift from shipped artifacts) ---
case_readme_docs_anchors() {
    # Every anchor the plan's acceptance criteria require the README to document.
    local anchor
    for anchor in "d330-swapfile.service" "53-lenovo-d330-resume.cfg" \
                  "resume_offset" "filefrag" "initramfs" "Secure Boot" \
                  "unencrypted" "d330-auto-hibernate.service"; do
        expect_file_out "$anchor" "$README"
    done
}

# --- Audit N5 coverage: run_power_action's rc must reach the process exit ---
# The D330_SYSTEMCTL seam points at a stub that records its verb and exits 7;
# the daemon runs WITHOUT --dry-run so run_power_action is really called, but
# the real systemctl never runs.
case_rc_propagates() {
    local stub="$FIX/systemctl_stub" verb_file="$FIX/stub_verb"
    printf '#!/usr/bin/env bash\necho "$1" > "%s"\nexit 7\n' "$verb_file" > "$stub"
    chmod +x "$stub"
    set_battery 3 Discharging
    rc=0
    D330_PROC_SWAPS="$FIX/sw_mixed" D330_SYS_POWER="$FIX/sys_ready" \
    D330_PROC_CMDLINE="$FIX/cmd_resume_set" D330_POWER_SUPPLY_DIR="$FIX/power" \
    D330_SYSTEMCTL="$stub" \
        python3 "$DAEMON" > "$CASE_OUT" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "    [detail] expected non-zero daemon rc from stubbed systemctl, got 0"
        CASE_FAIL=1
    fi
    expect_out "[CRITICAL] Battery at 3%!"
    expect_out "[ERROR] systemctl hibernate failed (rc=7)"
    expect_no_out "Traceback"
    if [ "$(cat "$verb_file" 2>/dev/null)" != "hibernate" ]; then
        echo "    [detail] stub expected verb 'hibernate', got: $(cat "$verb_file" 2>/dev/null || echo none)"
        CASE_FAIL=1
    fi
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
    case_enable_site_install_dkms
    case_enable_site_debian_postinst
    case_enable_site_rpm_spec
    case_swapfile_unit_static
    case_resume_snippet_template
    case_installer_activation_step
    case_uninstall_symmetry
    case_readme_docs_anchors
    case_rc_propagates
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
