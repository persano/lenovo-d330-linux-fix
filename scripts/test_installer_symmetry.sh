#!/usr/bin/env bash
# ==============================================================================
# scripts/test_installer_symmetry.sh
#
# Static + fixture guard suite for scripts/install_dkms.sh installer/uninstaller
# symmetry (Phase 35: audit M1/M2/M11/N6).
#
# No case runs the real systemctl/dkms/grub/dracut. Behavioural cases use the
# installer's own read-only modes (`--dump-manifest`, `--verify --root <fixture>`)
# so the deploy manifest drives a fixture round trip; everything else is a
# static grep against the installer and the two packaging enable sites.
#
# Cases (11): manifest-single-source, verify-drift-detected, verify-clean-passes,
# grub-regen-both-paths, uninstall-rescue-bypass, enable-parity-9,
# dropin-narrow-removal, warn-named-packages, uninstall-gaps, no-broad-rm-rf,
# bash-n-all.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

S="scripts/install_dkms.sh"
DEBIAN_POSTINST="packaging/debian/postinst"
RPM_SPEC="packaging/rpm/lenovo-d330-fix.spec"
SUITE="scripts/test_installer_symmetry.sh"
STORAGE="scripts/test_storage_cellular.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 35 installer symmetry guard suite (11 cases, static greps +
manifest-driven --verify fixture, no real systemctl/dkms/grub).

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
echo " Lenovo D330 Installer Symmetry Guard Suite               "
echo "=========================================================="

passed=0
failed=0

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
CASE_OUT="$FIX/case.out"

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

# Emit only the machine-readable manifest lines from --dump-manifest. The
# installer prints a human [INFO] skip line to stdout first; it has no TAB and
# is filtered out by the NF==2 + known-kind guard.
dump_manifest() {
    bash "$S" --dump-manifest 2>/dev/null | \
        awk -F'\t' 'NF==2 && $2 ~ /^(dir|file|exec|unit|unit-enabled|grub-snippet|fstab-line|state)$/ {print}'
}

# Create every manifest entry in a fixture root (runtime-only kinds skipped).
populate_root() {
    local R="$1" p k
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        case "$k" in
            unit-enabled|fstab-line) continue ;;
            dir) mkdir -p "${R}${p}" ;;
            exec) mkdir -p "$(dirname "${R}${p}")"; : > "${R}${p}"; chmod +x "${R}${p}" ;;
            *) mkdir -p "$(dirname "${R}${p}")"; : > "${R}${p}" ;;
        esac
    done < <(dump_manifest)
}

# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

case_manifest_single_source() {
    # deploy_manifest is defined and consumed by do_verify.
    if ! grep -q "deploy_manifest" "$S"; then
        echo "    [detail] deploy_manifest missing"
        CASE_FAIL=1
    fi
    local vbody
    vbody="$(awk '/do_verify\(\)/,/^}/' "$S")"
    case "$vbody" in
        *deploy_manifest*) ;;
        *) echo "    [detail] do_verify does not consume deploy_manifest"; CASE_FAIL=1 ;;
    esac
    # Every installed artifact basename appears in the installer (drift guard).
    local n=0 p k b
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        n=$((n + 1))
        case "$k" in
            dir|unit-enabled|fstab-line) continue ;;
        esac
        b="${p##*/}"
        if ! grep -qF -- "$b" "$S"; then
            echo "    [detail] manifest basename not present in installer: $p"
            CASE_FAIL=1
        fi
    done < <(dump_manifest)
    if [ "$n" -eq 0 ]; then
        echo "    [detail] manifest is empty"
        CASE_FAIL=1
    fi
}

case_verify_drift_detected() {
    local R rc
    R="$(mktemp -d "$FIX/drift_XXXXXX")"
    if bash "$S" --verify --root "$R" > "$CASE_OUT" 2>&1; then
        echo "    [detail] empty root verified clean (expected non-zero)"
        CASE_FAIL=1
    fi
    expect_out "DRIFT"

    # Tampered populated root: drop one entry -> non-zero + DRIFT.
    populate_root "$R"
    local first
    first="$(dump_manifest | awk -F'\t' '$2 ~ /^(file|exec|unit|grub-snippet|state)$/ {print $1}')"
    first="${first%%$'\n'*}"
    if [ -n "$first" ]; then
        rm -f "${R}${first}"
        rc=0
        bash "$S" --verify --root "$R" > "$CASE_OUT" 2>&1 || rc=$?
        if [ "$rc" -eq 0 ]; then
            echo "    [detail] tampered root verified clean (expected non-zero)"
            CASE_FAIL=1
        fi
        expect_out "DRIFT"
    fi
}

case_verify_clean_passes() {
    local R rc=0
    R="$(mktemp -d "$FIX/clean_XXXXXX")"
    populate_root "$R"
    bash "$S" --verify --root "$R" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
}

case_grub_regen_both_paths() {
    if ! grep -q "run_grub_regen" "$S"; then
        echo "    [detail] run_grub_regen helper missing"
        CASE_FAIL=1
    fi
    local dbody ubody n
    dbody="$(awk '/do_install\(\)/,/^}/' "$S")"
    case "$dbody" in
        *run_grub_regen*) ;;
        *) echo "    [detail] do_install does not regenerate GRUB"; CASE_FAIL=1 ;;
    esac
    ubody="$(awk '/do_uninstall\(\)/,/^}/' "$S")"
    case "$ubody" in
        *run_grub_regen*) ;;
        *) echo "    [detail] do_uninstall does not regenerate GRUB"; CASE_FAIL=1 ;;
    esac
    n="$(grep -c "update-grub" "$S" || true)"
    if [ "$n" -lt 2 ]; then
        echo "    [detail] update-grub ladder references too few times ($n)"
        CASE_FAIL=1
    fi
}

case_uninstall_rescue_bypass() {
    # Prereq gate must be install-only, with an honest named skip for the rest.
    if ! grep -q "check_prerequisites runs only for install" "$S"; then
        echo "    [detail] install-only prereq gate comment/log missing"
        CASE_FAIL=1
    fi
    if ! grep -q "rescue-shell" "$S"; then
        echo "    [detail] rescue-shell skip log missing"
        CASE_FAIL=1
    fi
    # The EUID/build-tool gate lives in check_prerequisites, called only from
    # the install branch; uninstall/verify/dump-manifest bypass it.
    local gate
    gate="$(awk '/case "\$ACTION" in/,/^esac/' "$S")"
    case "$gate" in
        *check_prerequisites*) ;;
        *) echo "    [detail] check_prerequisites not gated in the dispatch preamble"; CASE_FAIL=1 ;;
    esac
}

case_enable_parity_9() {
    local f n
    for f in "$S" "$DEBIAN_POSTINST" "$RPM_SPEC"; do
        if ! grep -q "lenovo-d330-camera-loopback.service" "$f"; then
            echo "    [detail] camera-loopback not enabled in $f"
            CASE_FAIL=1
        fi
        n="$(grep -oE "systemctl enable [a-zA-Z0-9._-]+\.service" "$f" | awk '{print $3}' | sort -u | wc -l)"
        if [ "$n" -lt 9 ]; then
            echo "    [detail] $f enables only $n units"
            CASE_FAIL=1
        fi
    done
}

case_dropin_narrow_removal() {
    if ! grep -q "d330-override.conf" "$S"; then
        echo "    [detail] narrow drop-in removal target missing"
        CASE_FAIL=1
    fi
    if ! grep -q "rmdir" "$S"; then
        echo "    [detail] rmdir-only-empty drop-in cleanup missing"
        CASE_FAIL=1
    fi
}

case_warn_named_packages() {
    local needle n
    for needle in thermald tlp; do
        if ! grep -qi "$needle" "$S"; then
            echo "    [detail] named WARN for missing '$needle' absent"
            CASE_FAIL=1
        fi
    done
    if ! grep -qiE "color/icc|icc" "$S"; then
        echo "    [detail] named WARN for missing ICC/profile dir absent"
        CASE_FAIL=1
    fi
    n="$(grep -c "log_warn" "$S" || true)"
    if [ "$n" -lt 3 ]; then
        echo "    [detail] too few log_warn calls ($n)"
        CASE_FAIL=1
    fi
}

case_uninstall_gaps() {
    local U
    U="$(awk '/do_uninstall\(\)/,/^}/' "$S")"
    case "$U" in
        *d330-hardware-state.json*) ;;
        *) echo "    [detail] state json not removed in uninstall"; CASE_FAIL=1 ;;
    esac
    case "$U" in
        *"unmask systemd-networkd-wait-online.service"*) ;;
        *) echo "    [detail] networkd wait-online unmask missing"; CASE_FAIL=1 ;;
    esac
    case "$U" in
        *"unmask NetworkManager-wait-online.service"*) ;;
        *) echo "    [detail] NetworkManager wait-online unmask missing"; CASE_FAIL=1 ;;
    esac
    case "$U" in
        *dracut*) ;;
        *) echo "    [detail] dracut branch missing in uninstall"; CASE_FAIL=1 ;;
    esac
}

case_no_broad_rm_rf() {
    if grep -qE "rm -rf /etc/systemd/system/[a-zA-Z0-9._-]+\.service\.d" "$S"; then
        echo "    [detail] broad rm -rf on a systemd drop-in dir remains"
        CASE_FAIL=1
    fi
}

case_bash_n_all() {
    local f rc
    for f in "$S" "$DEBIAN_POSTINST" "$SUITE" "$STORAGE"; do
        rc=0
        bash -n "$f" || rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "    [detail] bash -n failed for $f"
            CASE_FAIL=1
        fi
    done
}

# ------------------------------------------------------------------------------
# Runner
# ------------------------------------------------------------------------------
CASE_NAMES=(
    case_manifest_single_source
    case_verify_drift_detected
    case_verify_clean_passes
    case_grub_regen_both_paths
    case_uninstall_rescue_bypass
    case_enable_parity_9
    case_dropin_narrow_removal
    case_warn_named_packages
    case_uninstall_gaps
    case_no_broad_rm_rf
    case_bash_n_all
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
