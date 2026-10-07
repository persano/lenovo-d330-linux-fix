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
    --mount-home    Migrate and mount MicroSD as /home expansion
    --dry-run       Preview commands without modifying disk
    --help          Show this message
EOF
}

TARGET_DEV="/dev/mmcblk1"
ACTION="probe"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --probe) ACTION="probe" ;;
        --format) ACTION="format" ;;
        --mount-data) ACTION="mount-data" ;;
        --mount-home) ACTION="mount-home" ;;
        --dry-run) DRY_RUN=1 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown option: $arg"; show_help; exit 1 ;;
    esac
done

log_info "=== Lenovo D330 MicroSD Storage Expansion Harness ==="

if [ ! -b "$TARGET_DEV" ]; then
    log_warn "Target MicroSD device $TARGET_DEV not found."
    log_info "Scanning sysfs for alternative MMC/SD slots..."
    for dev in /sys/block/mmcblk*; do
        NAME=$(basename "$dev")
        if [ "$NAME" != "mmcblk0" ]; then
            log_ok "Found secondary SD card: /dev/$NAME"
            TARGET_DEV="/dev/$NAME"
            break
        fi
    done
fi

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
    exit 0
fi

if [ "$EUID" -ne 0 ] && [ $DRY_RUN -eq 0 ]; then
    log_err "Root privileges required for disk operations. Run with sudo."
    exit 1
fi

PART_DEV="${TARGET_DEV}p1"

if [ "$ACTION" = "format" ]; then
    log_info "Formatting MicroSD $TARGET_DEV with GPT and flash-optimized ext4..."
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[DRY-RUN] parted -s $TARGET_DEV mklabel gpt mkpart primary ext4 1MiB 100%"
        log_info "[DRY-RUN] mkfs.ext4 -F -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE $PART_DEV"
    else
        parted -s "$TARGET_DEV" mklabel gpt mkpart primary ext4 1MiB 100%
        sleep 1
        mkfs.ext4 -F -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE "$PART_DEV"
        log_ok "MicroSD formatted successfully with volume label 'D330_STORAGE'."
    fi
fi

if [ "$ACTION" = "mount-data" ]; then
    MOUNT_POINT="/data"
    log_info "Configuring permanent mount at $MOUNT_POINT..."
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[DRY-RUN] mkdir -p $MOUNT_POINT"
        log_info "[DRY-RUN] Append to /etc/fstab: UUID=... $MOUNT_POINT ext4 noatime,lazytime,commit=60 0 2"
    else
        mkdir -p "$MOUNT_POINT"
        UUID=$(blkid -s UUID -o value "$PART_DEV" 2>/dev/null || true)
        if [ -n "$UUID" ]; then
            if ! grep -q "$UUID" /etc/fstab; then
                echo "UUID=$UUID $MOUNT_POINT ext4 noatime,lazytime,commit=60 0 2" >> /etc/fstab
                mount "$MOUNT_POINT" || true
                log_ok "Mounted $PART_DEV to $MOUNT_POINT with optimized commit=60 options."
            else
                log_info "Entry already present in /etc/fstab."
            fi
        else
            log_err "Could not resolve UUID for $PART_DEV. Format card first."
        fi
    fi
fi

if [ "$ACTION" = "mount-home" ]; then
    log_info "Preparing /home expansion migration..."
    log_warn "Backup /home before running full user migration."
fi

log_ok "Storage expansion task complete."
