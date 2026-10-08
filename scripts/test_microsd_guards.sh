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
# Cases (12): missing-device hard errors, mounted-target abort, bidirectional
# root refusal, guards-pass-but-write-blocked, dry-run PASS/FAIL guard report,
# both parser orders, probe regression.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TOOL="tools/d330-microsd-setup.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs the Phase 32 microsd guard suite (12 cases, PATH shims, no real disk IO).

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
cat > "$SHIM_DIR/blkid" <<'EOF'
#!/usr/bin/env bash
printf 'blkid %s\n' "$*" >> "${D330_SHIM_LOG:-/dev/null}"
printf '%s\n' "${D330_SHIM_UUID:-11111111-2222-3333-4444-555555555555}"
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
