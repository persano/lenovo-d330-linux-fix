#!/usr/bin/env bash
# ==============================================================================
# build_live_iso.sh
# Automated Live ISO Remaster Build Harness for Lenovo IdeaPad D330-10IGL
# Supports: Ubuntu 24.04 LTS, Linux Mint LMDE 6, Linux Mint 21/22
# ==============================================================================

set -euo pipefail

BASE_ISO=""
OUTPUT_ISO="lenovo-d330-linux-remastered.iso"
DRY_RUN=false
WORK_DIR="/tmp/d330_iso_build"

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK]   $*"; }
log_warn() { echo "[WARN] $*"; }
log_err()  { echo "[ERR]  $*"; }

show_help() {
    cat << 'EOF'
Usage: sudo scripts/build_live_iso.sh [OPTIONS]

Options:
  --base-iso <path>    Path to upstream Ubuntu/Mint/LMDE live ISO image (required)
  --output <path>      Output path for remastered bootable ISO (default: lenovo-d330-linux-remastered.iso)
  --dry-run            Validate build prerequisites and injection pipeline without modifying disks
  --help               Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-iso)
            BASE_ISO="$2"
            shift 2
            ;;
        --output)
            OUTPUT_ISO="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_err "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330 Live ISO Remastering Build Harness          "
echo "=========================================================="

if [[ "$DRY_RUN" = true ]]; then
    log_info "[DRY-RUN] Validating remastering pipeline prerequisites..."
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    dry_failed=0

    # 1. Required build tools must be present on PATH.
    for tool in xorriso unsquashfs mksquashfs; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_ok "tool present: $tool"
        else
            log_err "missing required ISO tool: $tool (install: apt install xorriso squashfs-tools)"
            dry_failed=$((dry_failed + 1))
        fi
    done

    # 2. Base ISO: optional in a dry-run, but if given it must exist.
    if [[ -n "$BASE_ISO" ]]; then
        if [[ -f "$BASE_ISO" ]]; then
            log_ok "base ISO present: $BASE_ISO ($(stat -c%s "$BASE_ISO") bytes)"
        else
            log_err "base ISO not found: $BASE_ISO"
            dry_failed=$((dry_failed + 1))
        fi
    else
        log_warn "no --base-iso supplied; skipping base-ISO file check (required for a real build)"
    fi

    # 3. Output path: the parent directory must exist and be writable.
    out_parent="$(dirname "$OUTPUT_ISO")"
    if [[ ! -d "$out_parent" ]]; then
        log_err "output parent directory missing: $out_parent"
        dry_failed=$((dry_failed + 1))
    elif [[ ! -w "$out_parent" ]]; then
        log_err "output parent directory exists but is not writable: $out_parent"
        dry_failed=$((dry_failed + 1))
    else
        log_ok "output directory present and writable: $out_parent"
    fi

    # 4. Source paths the injection pipeline copies from.
    for src in tools patches patches/dkms patches/touchscreen patches/audio/ucm2 \
               patches/audio_dsp patches/storage_memory patches/boot_orientation \
               patches/acpi_override; do
        if [[ -e "$REPO_ROOT/$src" ]]; then
            log_ok "source path present: $src"
        else
            log_err "missing source path: $src"
            dry_failed=$((dry_failed + 1))
        fi
    done

    # 5. Required source files: the pipeline's `cp tools/d330-*` glob needs at
    #    least one match, otherwise the injected live image is silently empty.
    tool_payload=0
    for f in "$REPO_ROOT"/tools/d330-*; do
        if [[ -e "$f" ]]; then
            tool_payload=$((tool_payload + 1))
        fi
    done
    if [[ "$tool_payload" -gt 0 ]]; then
        log_ok "tool payload present: $tool_payload tools/d330-* file(s)"
    else
        log_err "no tools/d330-* files found under $REPO_ROOT/tools"
        dry_failed=$((dry_failed + 1))
    fi

    if [[ "$dry_failed" -gt 0 ]]; then
        log_err "[DRY-RUN] $dry_failed prerequisite check(s) failed; remaster build cannot proceed."
        exit 1
    fi
    log_ok "[DRY-RUN] Remaster prerequisites validated (tools, source tree, output path)."
    exit 0
fi

if [[ -z "$BASE_ISO" ]]; then
    log_err "--base-iso <path> is required."
    exit 1
fi

if [[ ! -f "$BASE_ISO" ]]; then
    log_err "Base ISO file not found: $BASE_ISO"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    log_err "Root privileges required for ISO loopback mount and chroot operations."
    exit 1
fi

for tool in xorriso unsquashfs mksquashfs; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_err "Missing required ISO tool: $tool. Install with: apt install xorriso squashfs-tools"
        exit 1
    fi
done

log_info "Staging workspace in $WORK_DIR..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/iso" "$WORK_DIR/squashfs"

log_info "Extracting base ISO files..."
xorriso -osirx_check off -osirx on -indev "$BASE_ISO" -extract / "$WORK_DIR/iso" >/dev/null 2>&1

log_info "Unpacking live squashfs filesystem..."
unsquashfs -d "$WORK_DIR/squashfs" "$WORK_DIR/iso/casper/filesystem.squashfs" >/dev/null 2>&1

log_info "Injecting Lenovo D330 hardware parity components into squashfs..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

# Copy tools
cp "$REPO_ROOT"/tools/d330-* "$WORK_DIR/squashfs/usr/local/bin/"
chmod +x "$WORK_DIR"/squashfs/usr/local/bin/d330-*

# Copy modprobe, udev, sysctl, systemd configs
cp "$REPO_ROOT"/patches/*/etc/modprobe.d/*.conf "$WORK_DIR/squashfs/etc/modprobe.d/" 2>/dev/null || true
cp "$REPO_ROOT"/patches/*/etc/udev/rules.d/*.rules "$WORK_DIR/squashfs/etc/udev/rules.d/" 2>/dev/null || true
cp "$REPO_ROOT"/patches/*/etc/udev/hwdb.d/*.hwdb "$WORK_DIR/squashfs/etc/udev/hwdb.d/" 2>/dev/null || true
cp "$REPO_ROOT"/patches/*/etc/systemd/system/*.service "$WORK_DIR/squashfs/etc/systemd/system/" 2>/dev/null || true

# Update initramfs within squashfs
chroot "$WORK_DIR/squashfs" update-initramfs -u || true

log_info "Repacking filesystem.squashfs with high compression..."
rm -f "$WORK_DIR/iso/casper/filesystem.squashfs"
mksquashfs "$WORK_DIR/squashfs" "$WORK_DIR/iso/casper/filesystem.squashfs" -comp zstd -Xcompression-level 19 >/dev/null 2>&1

log_info "Generating hybrid bootable UEFI ISO image..."
xorriso -as mkisofs -r \
    -V "D330_LINUX_LIVE" \
    -o "$OUTPUT_ISO" \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    "$WORK_DIR/iso" >/dev/null 2>&1

log_ok "Successfully generated bootable live ISO: $OUTPUT_ISO ($(stat -c%s "$OUTPUT_ISO") bytes)"
rm -rf "$WORK_DIR"
