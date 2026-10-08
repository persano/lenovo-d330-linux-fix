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
# Cases (17): manifest-single-source, manifest-deploy-consistency,
# verify-drift-detected, verify-clean-passes, verify-conditional-absent,
# verify-removed-direction, grub-regen-both-paths, uninstall-rescue-bypass,
# enable-parity-9, user-unit-packaged, dropin-narrow-removal,
# warn-named-packages, uninstall-gaps, uninstall-nonroot-warn, no-broad-rm-rf,
# no-broad-ucm-rm-rf, bash-n-all.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

S="scripts/install_dkms.sh"
DEBIAN_POSTINST="packaging/debian/postinst"
DEBIAN_RULES="packaging/debian/rules"
RPM_SPEC="packaging/rpm/lenovo-d330-fix.spec"
ARCH_PKGBUILD="packaging/arch/PKGBUILD"
SUITE="scripts/test_installer_symmetry.sh"
STORAGE="scripts/test_storage_cellular.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 35 installer symmetry guard suite (17 cases, static greps +
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

# Substring test safe under `set -o pipefail`: grep -q exits on first match,
# SIGPIPEs a pipe writer (e.g. printf) and the pipeline then reads as failure
# even though the match succeeded. case pattern matching has no such race.
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

# Emit only the machine-readable manifest lines from --dump-manifest. The
# installer prints a human [INFO] skip line to stdout first; it has no TAB and
# is filtered out by the NF==2 + known-kind guard.
dump_manifest() {
    bash "$S" --dump-manifest 2>/dev/null | \
        awk -F'\t' 'NF==2 && $2 ~ /^(dir|dir-optional|file|exec|unit|unit-user|unit-enabled|unit-user-enabled|grub-snippet|fstab-line|state|file-optional|exec-optional|grub-snippet-optional)$/ {print}'
}

# The install_dkms.sh body with the deploy_manifest() heredoc removed, so a
# basename/pattern match against it can NOT be satisfied by the manifest's own
# listing (the WR-03 vacuity: basenames matched the manifest they came from).
strip_manifest() {
    awk '/^deploy_manifest\(\)/{skip=1} skip && /^}$/{skip=0; next} skip{next} {print}' "$S"
}

# Create every manifest entry in a fixture root (runtime-only kinds skipped).
populate_root() {
    local R="$1" p k
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        case "$k" in
            unit-enabled|unit-user-enabled|fstab-line) continue ;;
            dir|dir-optional) mkdir -p "${R}${p}" ;;
            exec|exec-optional) mkdir -p "$(dirname "${R}${p}")"; : > "${R}${p}"; chmod +x "${R}${p}" ;;
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
    # Every installed artifact basename appears in the installer BODY (with the
    # deploy_manifest heredoc stripped, so the manifest line itself cannot
    # satisfy the check -- WR-03).
    local n=0 p k b body
    body="$(strip_manifest)"
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        n=$((n + 1))
        case "$k" in
            unit-enabled|unit-user-enabled|fstab-line) continue ;;
        esac
        # The DKMS staging dir is variable-expanded (DEST_SRC) everywhere; assert
        # the variable, not the literal path.
        case "$p" in
            /usr/src/*)
                case "$body" in
                    *DEST_SRC*) ;;
                    *) echo "    [detail] DEST_SRC staging path absent from installer body"; CASE_FAIL=1 ;;
                esac
                continue ;;
        esac
        b="${p##*/}"
        # case (not `printf | grep -q`): under `set -o pipefail`, grep -q's
        # early exit SIGPIPEs the printf writer and the pipeline reads as a
        # failure even on a match.
        case "$body" in
            *"$b"*) ;;
            *) echo "    [detail] manifest basename not present in installer body: $p"; CASE_FAIL=1 ;;
        esac
    done < <(dump_manifest)
    if [ "$n" -eq 0 ]; then
        echo "    [detail] manifest is empty"
        CASE_FAIL=1
    fi
}

# WR-02/WR-03: the manifest must not drift from the hand-written install and
# uninstall lists. For every deployed artifact, assert a matching do_install
# deploy action (its basename in the install body) AND a matching do_uninstall
# removal action (its full destination path in the uninstall body). Both bodies
# have the manifest heredoc stripped, so a manifest-only entry fails this case.
case_manifest_deploy_consistency() {
    local body install_body uninstall_body p k b
    body="$(strip_manifest)"
    install_body="$(printf '%s\n' "$body" | awk '/^do_install\(\)/{f=1} f&&/^}$/{f=0;next} f{print}')"
    uninstall_body="$(printf '%s\n' "$body" | awk '/^do_uninstall\(\)/{f=1} f&&/^}$/{f=0;next} f{print}')"
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        case "$k" in
            unit-enabled|unit-user-enabled|fstab-line|state) continue ;;
        esac
        b="${p##*/}"
        # install deploy action
        if ! contains "$install_body" "$b"; then
            case "$p" in
                /usr/src/*)
                    contains "$install_body" "DEST_SRC" || {
                        echo "    [detail] no install action for $p (DEST_SRC missing)"
                        CASE_FAIL=1
                    } ;;
                */earlyoom.service.d/d330-override.conf)
                    contains "$install_body" "earlyoom.service.d" || {
                        echo "    [detail] no install action for $p"
                        CASE_FAIL=1
                    } ;;
                *)
                    echo "    [detail] no do_install cp/install action for $p"
                    CASE_FAIL=1 ;;
            esac
        fi
        # uninstall removal action
        if ! contains "$uninstall_body" "$p"; then
            case "$p" in
                /usr/src/*)
                    contains "$uninstall_body" "DEST_SRC" || {
                        echo "    [detail] no uninstall removal for $p (DEST_SRC missing)"
                        CASE_FAIL=1
                    } ;;
                *)
                    echo "    [detail] no do_uninstall rm/disable action for $p"
                    CASE_FAIL=1 ;;
            esac
        fi
    done < <(dump_manifest)
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

# CR-01 regression: a root containing ONLY the required (non-conditional)
# manifest entries must still verify clean -- absent optional/state artifacts
# (missing target dir, failed hibernate activation) are SKIP, never DRIFT.
case_verify_conditional_absent() {
    local R rc=0 p k
    R="$(mktemp -d "$FIX/cond_XXXXXX")"
    while IFS=$'\t' read -r p k; do
        [ -n "$p" ] || continue
        case "$k" in
            unit-enabled|unit-user-enabled|fstab-line|state|file-optional|exec-optional|dir-optional|grub-snippet-optional) continue ;;
        esac
        case "$k" in
            dir) mkdir -p "${R}${p}" ;;
            exec) mkdir -p "$(dirname "${R}${p}")"; : > "${R}${p}"; chmod +x "${R}${p}" ;;
            *) mkdir -p "$(dirname "${R}${p}")"; : > "${R}${p}" ;;
        esac
    done < <(dump_manifest)
    bash "$S" --verify --root "$R" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    # Non-vacuous: prove an optional entry really was skipped as conditional.
    expect_out "conditional/runtime artifact absent"
}

# WR-01: --verify --removed asserts every manifest path is ABSENT, so an
# install-then-uninstall (SC1) is machine-checked in the removal direction.
case_verify_removed_direction() {
    local R rc=0
    R="$(mktemp -d "$FIX/removed_XXXXXX")"
    # Empty root: nothing present -> removed-mode exits 0.
    bash "$S" --verify --removed --root "$R" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    # Populated root: present artifacts -> removed-mode non-zero + DRIFT.
    populate_root "$R"
    rc=0
    bash "$S" --verify --removed --root "$R" > "$CASE_OUT" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "    [detail] removed-mode passed a populated root (expected non-zero)"
        CASE_FAIL=1
    fi
    expect_out "DRIFT"
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
        n="$(grep -oE "systemctl (--global )?enable [a-zA-Z0-9._-]+\.service" "$f" | awk '{print $NF}' | sort -u | wc -l)"
        if [ "$n" -lt 9 ]; then
            echo "    [detail] $f enables only $n units"
            CASE_FAIL=1
        fi
    done
}

# CR-01 (Phase 36): the tablet daemon is a systemd USER unit, so every packager
# must copy patches/*/usr/lib/systemd/user/*.service into its package tree --
# otherwise the existing `systemctl --global enable d330-tablet-daemon.service`
# in deb postinst / RPM %post finds no unit and silently enables nothing.
case_user_unit_packaged() {
    local f
    for f in "$DEBIAN_RULES" "$RPM_SPEC" "$ARCH_PKGBUILD"; do
        if [ ! -f "$f" ]; then
            echo "    [detail] packager missing: $f"
            CASE_FAIL=1
            continue
        fi
        if ! grep -q "usr/lib/systemd/user" "$f"; then
            echo "    [detail] user unit not installed by $f"
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

# WR-04: non-root --uninstall must not claim a restore it did not perform.
case_uninstall_nonroot_warn() {
    local U
    U="$(awk '/do_uninstall\(\)/,/^}/' "$S")"
    case "$U" in
        *UNINSTALL_SKIPPED_NONROOT*) ;;
        *) echo "    [detail] non-root uninstall guard missing"; CASE_FAIL=1 ;;
    esac
    if ! grep -q "not root - removals were skipped" "$S"; then
        echo "    [detail] honest non-root uninstall warning missing"
        CASE_FAIL=1
    fi
}

# IN-02: the installer-owned ALSA UCM2 subtree must not be removed by a broad
# rm -rf (foreign files placed there must survive).
case_no_broad_ucm_rm_rf() {
    if grep -qE "rm -rf /usr/share/alsa/ucm2/sof-essx8336" "$S"; then
        echo "    [detail] broad rm -rf on the installer-owned UCM2 subtree remains"
        CASE_FAIL=1
    fi
    local U
    U="$(awk '/do_uninstall\(\)/,/^}/' "$S")"
    case "$U" in
        *"rmdir /usr/share/alsa/ucm2/sof-essx8336"*) ;;
        *) echo "    [detail] empty-only rmdir of the UCM2 subtree missing"; CASE_FAIL=1 ;;
    esac
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
    case_manifest_deploy_consistency
    case_verify_drift_detected
    case_verify_clean_passes
    case_verify_conditional_absent
    case_verify_removed_direction
    case_grub_regen_both_paths
    case_uninstall_rescue_bypass
    case_enable_parity_9
    case_user_unit_packaged
    case_dropin_narrow_removal
    case_warn_named_packages
    case_uninstall_gaps
    case_uninstall_nonroot_warn
    case_no_broad_rm_rf
    case_no_broad_ucm_rm_rf
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
