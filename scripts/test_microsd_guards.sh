#!/usr/bin/env bash
# ==============================================================================
# scripts/test_microsd_guards.sh
#
# PATH-shim guard suite for tools/d330-microsd-setup.sh (Phase 32, audit C1).
#
# A temp-dir PATH prefix shadows lsblk/findmnt/parted/mkfs.ext4/blkid/mount/
# mkdir/udevadm/partprobe so no real block device is ever written. The parted/
# mkfs canary file proves abort-before-write: if it exists after a must-abort
# case, a guard failed open.
#
# Cases (26): missing-device hard errors, mounted-target abort, bidirectional
# root refusal, guards-pass-but-write-blocked, dry-run PASS/FAIL guard report,
# both parser orders, probe regression, nine mount-data cases (append, rollback,
# duplicates, confirmation, verify failure, empty UUID), the fstab parse
# proof against the real findmnt/systemd-analyze, and the Plan 32-03 honesty
# cases (mount-home-missing-device, mount-home-not-implemented,
# help-marked-unsupported, completion-honesty).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TOOL="tools/d330-microsd-setup.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 32 microsd guard suite (26 cases, PATH shims, no real disk IO).

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
echo " Lenovo D330 MicroSD Guard Suite (PATH-shim harness)      "
echo "=========================================================="

passed=0
failed=0

# ------------------------------------------------------------------------------
# Block-device discovery: the tool's existence precondition is a real [ -b ]
# test that shims cannot fake, so the suite needs a genuine block device.
# ------------------------------------------------------------------------------
TEST_DEV=""
for cand in /dev/loop0 /dev/loop1 /dev/sda /dev/sdb /dev/vda; do
    if [ -b "$cand" ]; then
        TEST_DEV="$cand"
        break
    fi
done
if [ -z "$TEST_DEV" ]; then
    echo "  [FAIL] no block device available for guard harness"
    exit 1
fi
echo "[*] Block-device test target: $TEST_DEV"

# ------------------------------------------------------------------------------
# Shim fixture (built once per run)
# ------------------------------------------------------------------------------
SHIM_DIR=$(mktemp -d /tmp/d330_shim_XXXXXX)
TAB_DIR=$(mktemp -d /tmp/d330_tab_XXXXXX)
CANARY="$SHIM_DIR/parted-canary"
SHIM_LOG="$SHIM_DIR/invocations.log"
CASE_OUT="$SHIM_DIR/case.out"
trap 'rm -rf "$SHIM_DIR" "$TAB_DIR"' EXIT
: > "$SHIM_LOG"

# lsblk: log args; canned rows per query shape (MOUNTPOINT > NAME,TYPE > SIZE)
cat > "$SHIM_DIR/lsblk" <<'EOF'
#!/usr/bin/env bash
printf 'lsblk %s\n' "$*" >> "${D330_SHIM_LOG:-/dev/null}"
case " $* " in
    *" MOUNTPOINT "*)
        printf '%s\n' "${D330_SHIM_LSBLK_MOUNTPOINTS:-}"
        exit 0
        ;;
esac
case " $* " in
    *" NAME,TYPE "*)
        printf '%s\n' "${D330_SHIM_TEST_DEV:-/dev/mmcblk1} disk"
        printf '%s\n' "${D330_SHIM_TEST_DEV:-/dev/mmcblk1}1 part"
        exit 0
        ;;
esac
case " $* " in
    *" SIZE "*)
        printf '%s\n' "68719476736"
        exit 0
        ;;
esac
exit 0
EOF

# findmnt: --verify uses D330_SHIM_VERIFY_RC; otherwise resolve the root source
cat > "$SHIM_DIR/findmnt" <<'EOF'
#!/usr/bin/env bash
printf 'findmnt %s\n' "$*" >> "${D330_SHIM_LOG:-/dev/null}"
case " $* " in
    *" --verify "*)
        exit "${D330_SHIM_VERIFY_RC:-0}"
        ;;
esac
printf '%s\n' "${D330_SHIM_ROOT_SOURCE:-/dev/mmcblk0p3}"
exit 0
EOF

# parted / mkfs.ext4: touch the canary — proves the guard failed if it ever runs
for destructive in parted mkfs.ext4; do
    cat > "$SHIM_DIR/$destructive" <<EOF
#!/usr/bin/env bash
printf '$destructive %s\n' "\$*" >> "\${D330_SHIM_LOG:-/dev/null}"
if [ -n "\${D330_SHIM_CANARY:-}" ]; then
    touch "\$D330_SHIM_CANARY"
fi
exit 0
EOF
done

# Remaining tool dependencies: log invocation, env-driven behavior (32-02 reuse)
# blkid: log args; honors an explicitly EMPTY D330_SHIM_UUID (unset-only
# default expansion, so D330_SHIM_UUID="" really yields an empty UUID).
cat > "$SHIM_DIR/blkid" <<'EOF'
#!/usr/bin/env bash
printf 'blkid %s\n' "$*" >> "${D330_SHIM_LOG:-/dev/null}"
printf '%s\n' "${D330_SHIM_UUID-1111-2222}"
exit 0
EOF

cat > "$SHIM_DIR/mount" <<'EOF'
#!/usr/bin/env bash
printf 'mount %s\n' "$*" >> "${D330_SHIM_LOG:-/dev/null}"
exit "${D330_SHIM_MOUNT_RC:-0}"
EOF

for simple in mkdir udevadm partprobe; do
    cat > "$SHIM_DIR/$simple" <<EOF
#!/usr/bin/env bash
printf '$simple %s\n' "\$*" >> "\${D330_SHIM_LOG:-/dev/null}"
exit 0
EOF
done

chmod +x "$SHIM_DIR"/* 2>/dev/null || true

# Canary + log are visible to every tool invocation below
export D330_SHIM_CANARY="$CANARY"
export D330_SHIM_LOG
export D330_SHIM_TEST_DEV="$TEST_DEV"

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

expect_rc_ne_zero() {
    if [ "$1" -eq 0 ]; then
        echo "    [detail] expected non-zero rc, got 0"
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

expect_out_re() {
    if ! grep -Eq -- "$1" "$CASE_OUT"; then
        echo "    [detail] output must match regex: $1"
        CASE_FAIL=1
    fi
}

expect_no_canary() {
    if [ -e "$CANARY" ]; then
        echo "    [detail] parted/mkfs canary was created - guard failed open!"
        CASE_FAIL=1
    fi
}

# Count lines matching UUID=1111-2222 in a temp fstab ($1 = file, $2 = expected)
expect_fstab_count() {
    local n
    n=$(grep -c "UUID=1111-2222" "$1" 2>/dev/null || true)
    if [ "${n:-0}" -ne "$2" ]; then
        echo "    [detail] expected $2 fstab line(s) matching UUID=1111-2222, got ${n:-0}"
        CASE_FAIL=1
    fi
}

# Assert the exact locked fstab line is present ($1 = exact line, $2 = file)
expect_fstab_line() {
    if ! grep -Fq -- "$1" "$2"; then
        echo "    [detail] fstab missing exact line: $1"
        CASE_FAIL=1
    fi
}

# ------------------------------------------------------------------------------
# Cases
# ------------------------------------------------------------------------------

case_missing_device_format() {
    local rc=0
    bash "$TOOL" --format > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 1
    expect_out "requires an explicit --device"
    expect_out "Usage:"
}

case_missing_device_value() {
    local rc=0
    bash "$TOOL" --format --device > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 1
    expect_out "--device requires a value"
}

case_mounted_target_abort() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS=/mnt/data \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] mountpoints: FAIL"
    expect_no_canary
}

case_root_refusal_target_is_prefix() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE="${TEST_DEV}p1" \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] root-device: FAIL"
    expect_no_canary
}

case_root_refusal_source_is_prefix() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE="${TEST_DEV%?}" \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] root-device: FAIL"
    expect_no_canary
}

case_root_refusal_equal() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE="$TEST_DEV" \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] root-device: FAIL"
    expect_no_canary
}

case_guards_pass_then_write_blocked() {
    local rc=0
    rm -f "$CANARY"
    printf 'no\n' | {
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out_re 'Root privileges|Confirmation not given'
    expect_no_canary
}

case_dry_run_guard_fail_report() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS=/mnt/data \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --dry-run --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] mountpoints:"
    expect_out "[GUARD] root-device:"
    expect_out "[GUARD] confirm:"
    expect_no_out "[DRY-RUN] parted"
    expect_no_canary
}

case_dry_run_guard_pass_report() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --dry-run --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "[GUARD] mountpoints: PASS"
    expect_out "[GUARD] root-device: PASS"
    expect_out "[GUARD] confirm: PASS"
    expect_out "[DRY-RUN] parted -s $TEST_DEV"
    expect_out "[DRY-RUN] partprobe"
    expect_out "[DRY-RUN] mkfs.ext4"
    expect_no_out "mkfs.ext4 -F"
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_parser_order_device_first() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --device "$TEST_DEV" --format --dry-run > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "[DRY-RUN] parted"
    expect_no_canary
}

case_parser_order_action_first() {
    local rc=0
    rm -f "$CANARY"
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --dry-run --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "[DRY-RUN] parted"
    expect_no_canary
}

case_probe_regression() {
    local rc=0
    bash "$TOOL" --probe > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
}

# ------------------------------------------------------------------------------
# mount-data cases (Plan 32-02): locked options, verify-before-append,
# rollback trap, duplicate/legacy refusal, confirmation, UUID-empty.
# Every case writes through D330_FSTAB into TAB_DIR - never /etc/fstab.
# ------------------------------------------------------------------------------
fresh_fstab() {
    CASE_FSTAB=$(mktemp "$TAB_DIR/fstab_XXXXXX")
    printf '# d330 guard-suite temp fstab\n' > "$CASE_FSTAB"
}

case_mount_data_missing_device() {
    local rc=0
    bash "$TOOL" --mount-data > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 1
    expect_out "requires an explicit --device"
}

case_mount_data_dry_run_options() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    D330_SHIM_UUID=1111-2222 \
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
    D330_FSTAB="$CASE_FSTAB" \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV" --dry-run > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "[DRY-RUN] mkdir -p /data"
    expect_out "[DRY-RUN] Append to $CASE_FSTAB: UUID=1111-2222 /data ext4 noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2"
    expect_no_out "Storage expansion task complete."
    expect_fstab_count "$CASE_FSTAB" 0
    expect_no_canary
}

case_mount_data_append_success() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'yes\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_fstab_line "UUID=1111-2222 /data ext4 noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2" "$CASE_FSTAB"
    expect_fstab_count "$CASE_FSTAB" 1
    expect_out "Storage expansion task complete."
    expect_no_canary
}

case_mount_data_mount_fail_rollback() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'yes\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_SHIM_MOUNT_RC=32 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_fstab_count "$CASE_FSTAB" 0
    expect_out "Mount of /data failed; fstab entry rolled back."
    expect_out "Rolled back fstab entry after failed mount."
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_mount_data_duplicate_legacy_refuses() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'UUID=1111-2222 /data ext4 noatime,lazytime,commit=60 0 2\n' >> "$CASE_FSTAB"
    printf 'yes\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_fstab_count "$CASE_FSTAB" 1
    expect_out "nofail,x-systemd.device-timeout=10s"
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_mount_data_duplicate_good_noop() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'UUID=1111-2222 /data ext4 noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2\n' >> "$CASE_FSTAB"
    printf 'yes\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_fstab_count "$CASE_FSTAB" 1
    expect_out "already present"
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_mount_data_confirm_refusal() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'no\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "Confirmation not given; aborting."
    expect_fstab_count "$CASE_FSTAB" 0
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_mount_data_verify_fails_aborts() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'yes\n' | {
        D330_SHIM_UUID=1111-2222 \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_SHIM_VERIFY_RC=1 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "failed verification"
    expect_fstab_count "$CASE_FSTAB" 0
    expect_no_canary
}

case_mount_data_uuid_empty() {
    local rc=0
    rm -f "$CANARY"
    fresh_fstab
    printf 'yes\n' | {
        D330_SHIM_UUID="" \
        D330_SHIM_LSBLK_MOUNTPOINTS= \
        D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        D330_FSTAB="$CASE_FSTAB" \
            PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV"
    } > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "Could not resolve UUID"
    expect_fstab_count "$CASE_FSTAB" 0
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

# ------------------------------------------------------------------------------
# fstab-parse-proof: runs WITHOUT the shim PATH so the REAL findmnt and
# systemd-analyze exercise the locked-options line and a generated .mount unit.
# ------------------------------------------------------------------------------
case_fstab_parse_proof() {
    local LOCKED="noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s"
    local CASE_DIR rc
    CASE_DIR=$(mktemp -d "$TAB_DIR/proof_XXXXXX")

    if ! grep -Fq -- "$LOCKED" "$TOOL"; then
        echo "    [detail] tool source no longer carries the locked options string"
        CASE_FAIL=1
        rm -rf "$CASE_DIR"
        return 0
    fi

    if command -v findmnt >/dev/null 2>&1; then
        printf 'UUID=1111-2222 /data ext4 %s 0 2\n' "$LOCKED" > "$CASE_DIR/candidate.fstab"
        rc=0
        findmnt --verify --tab-file "$CASE_DIR/candidate.fstab" > "$CASE_DIR/verify.out" 2>&1 || rc=$?
        if ! grep -Fq "0 parse errors" "$CASE_DIR/verify.out"; then
            echo "    [detail] findmnt reported parse errors:"
            sed 's/^/      /' "$CASE_DIR/verify.out"
            CASE_FAIL=1
        fi
        if grep -E "\[E\]" "$CASE_DIR/verify.out" | grep -vE "unreachable on boot required (source|target)" | grep -q .; then
            echo "    [detail] non-environmental [E] line in findmnt verify:"
            grep -E "\[E\]" "$CASE_DIR/verify.out" | sed 's/^/      /'
            CASE_FAIL=1
        elif ! grep -qE "\[E\]" "$CASE_DIR/verify.out"; then
            if [ "$rc" -ne 0 ]; then
                echo "    [detail] findmnt --verify rc=$rc with zero [E] lines"
                CASE_FAIL=1
            fi
        else
            echo "    [WARN] fstab-parse-proof: environmental - unreachable source/target on this machine"
            sed 's/^/      /' "$CASE_DIR/verify.out"
        fi
        printf '%s %s ext4 defaults 0 2\n' "$TEST_DEV" "$CASE_DIR" > "$CASE_DIR/resolved.fstab"
        rc=0
        findmnt --verify --tab-file "$CASE_DIR/resolved.fstab" > "$CASE_DIR/resolved.out" 2>&1 || rc=$?
        if [ "$rc" -ne 0 ] || grep -qE "\[E\]" "$CASE_DIR/resolved.out"; then
            echo "    [detail] resolved-source findmnt verify failed rc=$rc:"
            sed 's/^/      /' "$CASE_DIR/resolved.out"
            CASE_FAIL=1
        fi
    else
        echo "  [SKIP] fstab-parse-proof: findmnt not available"
    fi

    {
        printf '[Unit]\n'
        printf 'Description=D330 storage expansion data mount\n'
        printf '[Mount]\n'
        printf 'What=UUID=1111-2222\n'
        printf 'Where=/data\n'
        printf 'Type=ext4\n'
        printf 'Options=%s\n' "$LOCKED"
    } > "$CASE_DIR/data.mount"
    chmod 644 "$CASE_DIR/data.mount"
    if command -v systemd-analyze >/dev/null 2>&1; then
        rc=0
        if systemd-analyze --help 2>/dev/null | grep -q -- "--recursive-errors"; then
            (cd "$CASE_DIR" && systemd-analyze verify ./data.mount --recursive-errors=yes > "$CASE_DIR/sa.out" 2>&1) || rc=$?
        else
            (cd "$CASE_DIR" && systemd-analyze verify ./data.mount > "$CASE_DIR/sa.out" 2>&1) || rc=$?
        fi
        if [ "$rc" -ne 0 ] || grep -Eq "Unknown|Invalid|Failed to parse" "$CASE_DIR/sa.out"; then
            echo "    [detail] systemd-analyze verify failed rc=$rc:"
            sed 's/^/      /' "$CASE_DIR/sa.out"
            CASE_FAIL=1
        fi
    else
        echo "  [SKIP] fstab-parse-proof: systemd-analyze not available"
    fi
    rm -rf "$CASE_DIR"
}

# ------------------------------------------------------------------------------
# Plan 32-03 honesty cases: mount-home stub behavior, help text, and the
# single-trigger completion message (locked CONTEXT.md decisions).
# ------------------------------------------------------------------------------
case_mount_home_missing_device() {
    local rc=0
    bash "$TOOL" --mount-home > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 1
    expect_out "requires an explicit --device"
}

case_mount_home_not_implemented() {
    local rc=0
    rm -f "$CANARY"
    # Device string is arbitrary: the stub branch fires before any existence
    # check, so no real block device is required for this case.
    bash "$TOOL" --mount-home --device /dev/loop0 > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "not implemented"
    expect_no_out "Storage expansion task complete."
    expect_no_canary
}

case_help_marked_unsupported() {
    local rc=0
    bash "$TOOL" --help > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_out "--device"
    expect_out_re "mount-home.*unsupported|unsupported.*mount-home"
}

case_completion_honesty() {
    local rc=0
    rm -f "$CANARY"

    # Negative path 1: format dry-run with guard-passing shims (exits 0 in its
    # own branch) must not claim completion.
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --dry-run --device "$TEST_DEV" > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_no_out "Storage expansion task complete."

    # Negative path 2: mount-data dry-run with guard-passing shims.
    rc=0
    fresh_fstab
    D330_SHIM_UUID=1111-2222 \
    D330_SHIM_LSBLK_MOUNTPOINTS= \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
    D330_FSTAB="$CASE_FSTAB" \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --mount-data --device "$TEST_DEV" --dry-run > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_eq "$rc" 0
    expect_no_out "Storage expansion task complete."

    # Negative path 3: the mount-home stub itself.
    rc=0
    bash "$TOOL" --mount-home --device /dev/loop0 > "$CASE_OUT" 2>&1 || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "not implemented"
    expect_no_out "Storage expansion task complete."

    # Positive direction stays covered by mount-data-append-success above,
    # which still asserts the closing message IS printed on genuine completion.
    expect_no_canary
}

CASE_NAMES=(
    case_missing_device_format
    case_missing_device_value
    case_mounted_target_abort
    case_root_refusal_target_is_prefix
    case_root_refusal_source_is_prefix
    case_root_refusal_equal
    case_guards_pass_then_write_blocked
    case_dry_run_guard_fail_report
    case_dry_run_guard_pass_report
    case_parser_order_device_first
    case_parser_order_action_first
    case_probe_regression
    case_mount_data_missing_device
    case_mount_data_dry_run_options
    case_mount_data_append_success
    case_mount_data_mount_fail_rollback
    case_mount_data_duplicate_legacy_refuses
    case_mount_data_duplicate_good_noop
    case_mount_data_confirm_refusal
    case_mount_data_verify_fails_aborts
    case_mount_data_uuid_empty
    case_fstab_parse_proof
    case_mount_home_missing_device
    case_mount_home_not_implemented
    case_help_marked_unsupported
    case_completion_honesty
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
