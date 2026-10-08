#!/usr/bin/env bash
# ==============================================================================
# d330-microsd-setup.sh
# Automated MicroSD storage expansion tool for Lenovo IdeaPad D330 (64GB eMMC)
# Inspired by community prior art (lucasgabmoreno/linuxmint_lenovod330)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}  $*"; }

show_help() {
    cat <<EOF
Usage: sudo $0 [OPTIONS]

Expands Lenovo D330 64GB eMMC storage using internal MicroSD card slot (/dev/mmcblk1).

Options:
    --probe         Detect MicroSD card and print partition details (Default)
    --format        Initialize MicroSD with GPT partition table and flash-optimized ext4
    --mount-data    Mount MicroSD to /data with flash-friendly fstab options
    --mount-home    Migrate and mount MicroSD as /home expansion (unsupported: not implemented)
    --device DEV    Target block device (e.g. /dev/mmcblk1). Required for destructive
                    actions (--format, --mount-data, --mount-home); the default
                    /dev/mmcblk1 applies only to --probe.
    --dry-run       Preview commands without modifying disk
    --help          Show this message
EOF
}

# ------------------------------------------------------------------------------
# require_device_for_action: destructive actions need an explicit --device.
# Runs immediately after parsing, before any guard, prompt, or banner work.
# ------------------------------------------------------------------------------
require_device_for_action() {
    case "$ACTION" in
        format|mount-data|mount-home)
            if [ "$DEVICE_SET" -ne 1 ]; then
                log_err "Action '$ACTION' requires an explicit --device /dev/... argument."
                show_help
                exit 1
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# validate_device_path: ASVS V5 input validation. Destructive actions reject
# anything that is not an absolute /dev/... path without '..' segments.
# ------------------------------------------------------------------------------
validate_device_path() {
    local bad=0
    case "$TARGET_DEV" in
        /dev/*) ;;
        *) bad=1 ;;
    esac
    case "$TARGET_DEV" in
        *..*) bad=1 ;;
    esac
    if [ "$bad" -eq 1 ]; then
        case "$ACTION" in
            probe)
                log_warn "Ignoring invalid --device value '$TARGET_DEV'; using default /dev/mmcblk1."
                TARGET_DEV="/dev/mmcblk1"
                ;;
            *)
                log_err "Invalid --device value: '$TARGET_DEV'. Must be an absolute /dev/... path with no '..' segments."
                exit 1
                ;;
        esac
    fi
}

# ------------------------------------------------------------------------------
# Guard (a): no partition of the target may be mounted (device-scoped lsblk).
# Prints exactly one [GUARD] mountpoints: PASS|FAIL line; returns 0/1.
# Explicit rc capture so lsblk exit 32 (device not found) is a FAIL, not an
# abort under set -e and not a vacuous PASS.
# ------------------------------------------------------------------------------
guard_mountpoint_empty() {
    local rc=0
    local out=""
    local line
    out=$(lsblk -nr -o MOUNTPOINT "$TARGET_DEV" 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        log_err "[GUARD] mountpoints: FAIL (lsblk rc=$rc while reading mountpoints of $TARGET_DEV)"
        return 1
    fi
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            log_err "[GUARD] mountpoints: FAIL (mounted at: $line)"
            return 1
        fi
    done <<< "$out"
    log_ok "[GUARD] mountpoints: PASS (no mounted partitions on $TARGET_DEV)"
}

# ------------------------------------------------------------------------------
# Guard (b): the target must not be the root device or related to it, checked in
# BOTH directions (root source longer than target AND root source shorter than
# target). Root source resolution uses an explicit rc capture so a failing or
# missing findmnt fails closed with its own message instead of aborting under
# set -e before [GUARD] root-device: prints.
# ------------------------------------------------------------------------------
guard_not_root_device() {
    local rc=0
    local ROOT_SRC=""
    ROOT_SRC=$(findmnt -n -o SOURCE / 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$ROOT_SRC" ]; then
        log_err "[GUARD] root-device: FAIL (root source could not be resolved; findmnt rc=$rc)"
        return 1
    fi
    case "$ROOT_SRC" in
        "$TARGET_DEV"|"$TARGET_DEV"*)
            log_err "[GUARD] root-device: FAIL (target is the root device or an ancestor of it: root=$ROOT_SRC target=$TARGET_DEV)"
            return 1
            ;;
    esac
    case "$TARGET_DEV" in
        "$ROOT_SRC"*)
            log_err "[GUARD] root-device: FAIL (target is a descendant of the root device: root=$ROOT_SRC target=$TARGET_DEV)"
            return 1
            ;;
    esac
    log_ok "[GUARD] root-device: PASS (root=$ROOT_SRC target=$TARGET_DEV)"
}

# ------------------------------------------------------------------------------
# Guard (c): typed 'yes' confirmation. In dry-run it reports PASS (no prompt)
# so all three [GUARD] lines always appear; in real mode EOF/piped stdin and
# wrong answers both abort.
# ------------------------------------------------------------------------------
confirm_destructive() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log_ok "[GUARD] confirm: PASS (dry-run: no confirmation required)"
        return 0
    fi
    log_info "Type 'yes' to confirm the destructive write to $TARGET_DEV:"
    local reply=""
    if ! read -r reply || [ "$reply" != "yes" ]; then
        log_err "[GUARD] confirm: FAIL"
        log_err "Confirmation not given; aborting."
        exit 1
    fi
    log_ok "[GUARD] confirm: PASS"
}

# ------------------------------------------------------------------------------
# Preflight: the write path hard-requires these binaries. Real mode exits with
# an actionable install hint; dry-run only warns.
# ------------------------------------------------------------------------------
preflight_tools() {
    local missing=()
    local bin
    local bins=("$@")
    if [ ${#bins[@]} -eq 0 ]; then
        bins=(parted partprobe udevadm lsblk findmnt mkfs.ext4)
    fi
    for bin in "${bins[@]}"; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing+=("$bin")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log_warn "Missing required tools (continuing dry-run): ${missing[*]}"
        else
            log_err "Missing required tools: ${missing[*]}"
            log_err "On Debian/Ubuntu/Mint: sudo apt install parted util-linux e2fsprogs systemd"
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# build_fstab_line: single source of truth for the boot-safe fstab entry
# (locked option string: nofail + systemd device timeout close audit C2's
# boot-hang path). Dump/pass fields stay 0 2.
# ------------------------------------------------------------------------------
build_fstab_line() {
    local uuid="$1"
    echo "UUID=$uuid $MOUNT_POINT ext4 noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2"
}

# ------------------------------------------------------------------------------
# rollback_fstab_line: idempotent EXIT-trap payload. Removes exactly the line
# that was appended, so a second call is a no-op; never aborts the trap itself.
# ------------------------------------------------------------------------------
rollback_fstab_line() {
    if [ -f "${FSTAB_FILE:-/etc/fstab}" ] && [ -n "${LINE:-}" ] && grep -qxF "$LINE" "$FSTAB_FILE" 2>/dev/null; then
        grep -vxF "$LINE" "$FSTAB_FILE" > "$FSTAB_FILE.gsdtmp" || true
        mv -f "$FSTAB_FILE.gsdtmp" "$FSTAB_FILE" || true
        log_warn "Rolled back fstab entry after failed mount."
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Argument parsing (while/shift: supports the value-consuming --device option).
# ------------------------------------------------------------------------------
TARGET_DEV="/dev/mmcblk1"
ACTION="probe"
DRY_RUN=0
DEVICE_SET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe) ACTION="probe"; shift ;;
        --format) ACTION="format"; shift ;;
        --mount-data) ACTION="mount-data"; shift ;;
        --mount-home) ACTION="mount-home"; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --device)
            if [ "$#" -lt 2 ]; then
                log_err "--device requires a value"
                show_help
                exit 1
            fi
            TARGET_DEV="$2"
            DEVICE_SET=1
            shift 2
            ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

require_device_for_action

# ------------------------------------------------------------------------------
# --mount-home stub (locked decision): the flag stays in --help marked
# unsupported, and this action always fails fast. The branch fires immediately
# after the device requirement — before the existence precondition, guards,
# preflight, and any prompt — because the stub performs no disk work at all,
# so it can never reach the trailing success line.
# ------------------------------------------------------------------------------
if [ "$ACTION" = "mount-home" ]; then
    log_err "--mount-home is not implemented in this release; see --help (flag marked unsupported)."
    exit 1
fi

validate_device_path

log_info "=== Lenovo D330 MicroSD Storage Expansion Harness ==="

# ------------------------------------------------------------------------------
# probe: read-only display, exits 0 with or without a card, no --device needed.
# The sysfs scan is informational only — it NEVER reassigns TARGET_DEV.
# ------------------------------------------------------------------------------
if [ "$ACTION" = "probe" ]; then
    log_info "Probing storage configuration..."
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL "$TARGET_DEV" 2>/dev/null || true
    if [ -b "$TARGET_DEV" ]; then
        SIZE=$(lsblk -b -n -o SIZE "$TARGET_DEV" 2>/dev/null | head -n 1 || echo 0)
        SIZE_GB=$(awk "BEGIN {printf \"%.1f\", $SIZE / 1073741824}")
        log_ok "Detected MicroSD: $TARGET_DEV ($SIZE_GB GB)"
    else
        log_warn "No MicroSD inserted in physical tablet slot."
    fi
    log_info "Scanning sysfs for alternative MMC/SD slots..."
    for dev in /sys/block/mmcblk*; do
        if [ ! -d "$dev" ]; then
            continue
        fi
        NAME=$(basename "$dev")
        if [ "$NAME" != "mmcblk0" ]; then
            log_info "Candidate MMC/SD slot: /dev/$NAME (informational only; pass --device to select it)"
        fi
    done
    exit 0
fi

# ------------------------------------------------------------------------------
# Existence precondition for destructive actions (Pitfall 4/10): real mode fails
# fast; dry-run warns and still runs the guard report.
# ------------------------------------------------------------------------------
if [ ! -b "$TARGET_DEV" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log_warn "Target device $TARGET_DEV is not a block device (absent here); guards still report below."
    else
        log_err "Target device $TARGET_DEV is not a block device."
        exit 1
    fi
fi

if [ "$ACTION" = "format" ]; then
    log_info "Formatting MicroSD $TARGET_DEV with GPT and flash-optimized ext4..."
    if [ "$DRY_RUN" -eq 1 ]; then
        # Report mode: evaluate every guard without aborting, print PASS/FAIL
        # per guard, then abort before any planned command if any guard failed.
        guard_failures=0
        guard_mountpoint_empty || guard_failures=$((guard_failures + 1))
        guard_not_root_device || guard_failures=$((guard_failures + 1))
        confirm_destructive || guard_failures=$((guard_failures + 1))
        if [ "$guard_failures" -gt 0 ]; then
            log_err "Dry-run aborted: $guard_failures guard(s) FAILED."
            exit 1
        fi
        preflight_tools
        PART_DEV=$(lsblk -lnpo NAME,TYPE "$TARGET_DEV" 2>/dev/null | awk '$2=="part"{print $1; exit}' || true)
        if [ -z "$PART_DEV" ]; then
            PART_DEV="<first partition of $TARGET_DEV>"
        fi
        log_info "[DRY-RUN] parted -s $TARGET_DEV mklabel gpt mkpart primary ext4 1MiB 100%"
        log_info "[DRY-RUN] partprobe $TARGET_DEV"
        log_info "[DRY-RUN] udevadm settle"
        log_info "[DRY-RUN] mkfs.ext4 -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE $PART_DEV"
        log_info "Dry-run complete: no changes were made."
        exit 0
    fi

    # Real mode: read-only guards fail fast, in locked order (a) mountpoints,
    # (b) root-device — before the root gate so guard diagnostics reach the
    # user first, and all before the first parted write.
    guard_mountpoint_empty || exit 1
    guard_not_root_device || exit 1

    if [ "$EUID" -ne 0 ]; then
        log_err "Root privileges required for disk operations. Run with sudo."
        exit 1
    fi

    preflight_tools
    confirm_destructive

    parted -s "$TARGET_DEV" mklabel gpt mkpart primary ext4 1MiB 100%
    partprobe "$TARGET_DEV"
    udevadm settle
    PART_DEV=$(lsblk -lnpo NAME,TYPE "$TARGET_DEV" | awk '$2=="part"{print $1; exit}' || true)
    if [ -z "$PART_DEV" ]; then
        log_err "Could not derive the new partition node for $TARGET_DEV after repartitioning."
        exit 1
    fi
    mkfs.ext4 -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE "$PART_DEV"
    log_ok "MicroSD formatted successfully with volume label 'D330_STORAGE'."
fi

if [ "$ACTION" = "mount-data" ]; then
    MOUNT_POINT="/data"
    FSTAB_FILE="${D330_FSTAB:-/etc/fstab}"
    log_info "Configuring permanent mount at $MOUNT_POINT..."

    # Read-only guard first. guard_mountpoint_empty is deliberately NOT run
    # here: a re-run against an already-mounted /data must still reach the
    # duplicate check (that guard is the pre-parted/mkfs guard).
    if [ "$DRY_RUN" -eq 1 ]; then
        guard_failures=0
        guard_not_root_device || guard_failures=$((guard_failures + 1))
        confirm_destructive || guard_failures=$((guard_failures + 1))
        if [ "$guard_failures" -gt 0 ]; then
            log_err "Dry-run aborted: $guard_failures guard(s) FAILED."
            exit 1
        fi
        PART_DEV=$(lsblk -lnpo NAME,TYPE "$TARGET_DEV" 2>/dev/null | awk '$2=="part"{print $1; exit}' || true)
        UUID=""
        if [ -n "$PART_DEV" ]; then
            UUID=$(blkid -s UUID -o value "$PART_DEV" 2>/dev/null || true)
        fi
        if [ -z "$UUID" ]; then
            UUID="<uuid resolved by blkid>"
        fi
        log_info "[DRY-RUN] mkdir -p $MOUNT_POINT"
        log_info "[DRY-RUN] Append to $FSTAB_FILE: $(build_fstab_line "$UUID")"
        log_info "Dry-run complete: no changes were made."
        exit 0
    fi

    guard_not_root_device || exit 1

    # Test seam: D330_FSTAB redirects fstab writes into a user-owned path, so
    # the root gate is skipped ONLY for ACTION=mount-data with that seam set.
    # The format path's root gate above stays unconditional.
    if [ "$ACTION" = "mount-data" ] && [ -n "${D330_FSTAB:-}" ] && [ "$EUID" -ne 0 ]; then
        log_info "Root gate skipped: D330_FSTAB seam writes a user-owned fstab path."
    elif [ "$EUID" -ne 0 ]; then
        log_err "Root privileges required for fstab writes. Run with sudo."
        exit 1
    fi

    preflight_tools blkid findmnt mount lsblk

    PART_DEV=$(lsblk -lnpo NAME,TYPE "$TARGET_DEV" | awk '$2=="part"{print $1; exit}' || true)
    UUID=$(blkid -s UUID -o value "$PART_DEV" 2>/dev/null || true)
    if [ -z "$UUID" ]; then
        log_err "Could not resolve UUID for $PART_DEV. Format card first."
        exit 1
    fi

    # Duplicate detection must use the SAME exact first-field match as the
    # options lookup below: a substring grep matched commented-out or embedded
    # "UUID=$UUID" text, then refused with a sed hint anchored on ^UUID= that
    # could never fix the comment it matched (WR-01).
    EXISTING_LINE=$(awk -v u="UUID=$UUID" '$1==u {print; exit}' "$FSTAB_FILE") || {
        log_err "Could not read $FSTAB_FILE while checking for an existing UUID=$UUID entry."
        exit 1
    }
    if [ -n "$EXISTING_LINE" ]; then
        EXISTING_OPTS=$(awk -v u="UUID=$UUID" '$1==u {print $4; exit}' "$FSTAB_FILE")
        case "$EXISTING_OPTS" in
            *nofail*)
                log_info "Entry already present in $FSTAB_FILE with boot-safe options."
                exit 0
                ;;
        esac
        log_err "Existing $FSTAB_FILE entry for UUID=$UUID is missing: nofail,x-systemd.device-timeout=10s"
        log_err "No automatic migration was performed. Fix it manually with:"
        log_err "  sed -i 's|^UUID=$UUID $MOUNT_POINT ext4 [^ ]* 0 2\$|UUID=$UUID $MOUNT_POINT ext4 noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2|' $FSTAB_FILE"
        exit 1
    fi

    confirm_destructive

    mkdir -p "$MOUNT_POINT"

    LINE=$(build_fstab_line "$UUID")
    CAND=$(mktemp)
    printf '%s\n' "$LINE" > "$CAND"
    if ! findmnt --verify --tab-file "$CAND" >/dev/null 2>&1; then
        rm -f "$CAND"
        log_err "fstab entry failed verification; $FSTAB_FILE not modified."
        exit 1
    fi
    rm -f "$CAND"

    printf '%s\n' "$LINE" >> "$FSTAB_FILE"
    trap 'rollback_fstab_line' EXIT

    mount_rc=0
    mount "$MOUNT_POINT" || mount_rc=$?
    if [ "$mount_rc" -ne 0 ]; then
        log_err "Mount of $MOUNT_POINT failed; fstab entry rolled back."
        exit "$mount_rc"
    fi

    log_ok "Mounted $PART_DEV to $MOUNT_POINT with boot-safe nofail options."
    trap - EXIT
fi

log_ok "Storage expansion task complete."
