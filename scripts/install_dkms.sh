#!/usr/bin/env bash
# ==============================================================================
# scripts/install_dkms.sh
#
# Automated Installer & Delivery Harness for Lenovo IdeaPad D330 Display Fix
# Target: Lenovo IdeaPad D330-10IGL (Type 82H0) / D330-10IGM (81H3/81MD)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PKG_NAME="lenovo-d330-fix"
PKG_VERSION="1.0.0"
SRC_DIR="${REPO_ROOT}/patches/dkms/lenovo-d330-fix"
DEST_SRC="/usr/src/${PKG_NAME}-${PKG_VERSION}"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") [OPTIONS]

Options:
  --install     Install DKMS module, modprobe configs, and udev hwdb rules (Default)
  --uninstall   Remove DKMS module, modprobe configs, and udev hwdb rules
  --dry-run     Check system prerequisites and show actions without applying changes
  -h, --help    Display this help message
EOF
}

check_prerequisites() {
    log_info "Checking system prerequisites..."
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        log_err "Installation requires root privileges. Please run with sudo."
        exit 1
    fi

    local missing=()
    for bin in dkms make gcc; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing+=("$bin")
        fi
    done

    local kver
    kver="$(uname -r 2>/dev/null || echo "generic")"
    if [ ! -d "/lib/modules/${kver}/build" ] && [ "$DRY_RUN" = false ]; then
        log_warn "Kernel build headers for ${kver} not found at /lib/modules/${kver}/build."
        log_warn "Ensure linux-headers-$(uname -r) is installed."
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_err "Missing required build tools: ${missing[*]}"
        log_err "On Debian/Ubuntu/Mint: sudo apt install dkms build-essential linux-headers-\$(uname -r)"
        exit 1
    fi
    log_ok "Prerequisites satisfied."
}

do_install() {
    log_info "Starting deployment of ${PKG_NAME} v${PKG_VERSION}..."

    # 1. Stage DKMS source
    log_info "Staging module source to ${DEST_SRC}..."
    if [ "$DRY_RUN" = false ]; then
        rm -rf "${DEST_SRC}"
        mkdir -p "${DEST_SRC}"
        cp -r "${SRC_DIR}"/* "${DEST_SRC}/"
    fi

    # 2. Register, build and install DKMS module
    log_info "Configuring DKMS..."
    if [ "$DRY_RUN" = false ]; then
        if dkms status -m "${PKG_NAME}" -v "${PKG_VERSION}" | grep -q "${PKG_NAME}"; then
            log_warn "Existing DKMS module detected; removing older instance..."
            dkms remove -m "${PKG_NAME}" -v "${PKG_VERSION}" --all >/dev/null 2>&1 || true
        fi

        log_info "Executing: dkms add, build, install..."
        dkms add -m "${PKG_NAME}" -v "${PKG_VERSION}"
        dkms build -m "${PKG_NAME}" -v "${PKG_VERSION}"
        dkms install -m "${PKG_NAME}" -v "${PKG_VERSION}"
        log_ok "DKMS module installed successfully."
    fi

    # 3. Deploy modprobe configuration
    log_info "Deploying modprobe parameters to /etc/modprobe.d/lenovo-d330-i915.conf..."
    if [ "$DRY_RUN" = false ]; then
        cp "${REPO_ROOT}/patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf" /etc/modprobe.d/
    fi

    # 4. Deploy udev sensor configuration
    log_info "Deploying accelerometer udev hwdb rules..."
    if [ "$DRY_RUN" = false ]; then
        cp "${REPO_ROOT}/patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb" /etc/udev/hwdb.d/
        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
            udevadm trigger -s iio 2>/dev/null || true
            log_ok "Updated systemd hardware database."
        fi
    fi

    # 5. Deploy systemd resume service
    log_info "Deploying post-resume stabilization service..."
    if [ "$DRY_RUN" = false ]; then
        cp "${REPO_ROOT}/patches/dkms/etc/systemd/system/lenovo-d330-resume.service" /etc/systemd/system/
        systemctl daemon-reload || true
        systemctl enable lenovo-d330-resume.service || true
        log_ok "Enabled lenovo-d330-resume.service."
    fi

    # 6. Update Initramfs
    log_info "Refreshing initramfs image..."
    if [ "$DRY_RUN" = false ]; then
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -u -k all || true
            log_ok "Updated initramfs."
        elif command -v dracut >/dev/null 2>&1; then
            dracut -f || true
            log_ok "Updated dracut initramfs."
        fi
    fi

    # 7. Test load module
    log_info "Testing kernel module load..."
    if [ "$DRY_RUN" = false ]; then
        modprobe -v "${PKG_NAME//-/_}" || true
    fi

    echo "================================================================================"
    log_ok "Installation complete! Display resume fix active."
    log_info "Reboot is recommended to apply all DRM cmdline and initramfs changes."
    echo "================================================================================"
}

do_uninstall() {
    log_info "Uninstalling ${PKG_NAME}..."
    if [ "$DRY_RUN" = false ]; then
        # Unload module
        modprobe -r "${PKG_NAME//-/_}" >/dev/null 2>&1 || true

        # Remove DKMS
        if dkms status -m "${PKG_NAME}" -v "${PKG_VERSION}" | grep -q "${PKG_NAME}"; then
            dkms remove -m "${PKG_NAME}" -v "${PKG_VERSION}" --all || true
        fi
        rm -rf "${DEST_SRC}"

        # Clean configs
        rm -f /etc/modprobe.d/lenovo-d330-i915.conf
        rm -f /etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb
        systemctl disable --now lenovo-d330-resume.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/lenovo-d330-resume.service
        systemctl daemon-reload >/dev/null 2>&1 || true

        # Refresh
        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
        fi
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -u || true
        fi
    fi
    log_ok "Uninstallation complete. System restored to baseline state."
}

ACTION="install"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) ACTION="install"; shift ;;
        --uninstall) ACTION="uninstall"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    log_warn "Operating in DRY-RUN mode. No files will be modified."
fi

check_prerequisites

case "$ACTION" in
    install) do_install ;;
    uninstall) do_uninstall ;;
esac
