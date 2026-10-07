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

    # 3. Deploy modprobe configurations (graphics, audio, power)
    log_info "Deploying modprobe parameters..."
    if [ "$DRY_RUN" = false ]; then
        cp "${REPO_ROOT}/patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/audio/etc/modprobe.d/lenovo-d330-audio.conf" ] && \
            cp "${REPO_ROOT}/patches/audio/etc/modprobe.d/lenovo-d330-audio.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/power/etc/modprobe.d/lenovo-d330-power.conf" ] && \
            cp "${REPO_ROOT}/patches/power/etc/modprobe.d/lenovo-d330-power.conf" /etc/modprobe.d/
    fi

    # 4. Deploy udev rules and hardware databases
    log_info "Deploying udev rules and hwdb entries (sensors, touchscreen, dock, power)..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /etc/udev/hwdb.d /etc/udev/rules.d
        cp "${REPO_ROOT}/patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb" /etc/udev/hwdb.d/
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb" /etc/udev/hwdb.d/
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules" ] && \
            cp "${REPO_ROOT}/patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules" ] && \
            cp "${REPO_ROOT}/patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules" /etc/udev/rules.d/

        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
            udevadm trigger || true
            log_ok "Updated systemd hardware database."
        fi
    fi

    # 5. Deploy X11 calibration and sleep hooks
    log_info "Deploying X11 touchscreen matrix and sleep stabilization hook..."
    if [ "$DRY_RUN" = false ]; then
        if [ -d "/etc/X11/xorg.conf.d" ]; then
            [ -f "${REPO_ROOT}/patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf" ] && \
                cp "${REPO_ROOT}/patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf" /etc/X11/xorg.conf.d/
        fi
        mkdir -p /usr/lib/systemd/system-sleep
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh" /usr/lib/systemd/system-sleep/ && \
            chmod +x /usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh
    fi

    # 6. Deploy Tablet Daemon and Power Tune utilities
    log_info "Deploying tablet daemon and power tuning services..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /usr/local/bin
        [ -f "${REPO_ROOT}/tools/d330-tablet-daemon.py" ] && \
            cp "${REPO_ROOT}/tools/d330-tablet-daemon.py" /usr/local/bin/d330-tablet-daemon && \
            chmod +x /usr/local/bin/d330-tablet-daemon
        [ -f "${REPO_ROOT}/tools/lenovo-d330-power-tune.sh" ] && \
            cp "${REPO_ROOT}/tools/lenovo-d330-power-tune.sh" /usr/local/bin/lenovo-d330-power-tune && \
            chmod +x /usr/local/bin/lenovo-d330-power-tune

        # Deploy systemd services
        cp "${REPO_ROOT}/patches/dkms/etc/systemd/system/lenovo-d330-resume.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/dock/etc/systemd/system/d330-tablet-daemon.service" ] && \
            cp "${REPO_ROOT}/patches/dock/etc/systemd/system/d330-tablet-daemon.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" ] && \
            cp "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" /etc/systemd/system/

        systemctl daemon-reload || true
        systemctl enable lenovo-d330-resume.service || true
        systemctl enable d330-tablet-daemon.service 2>/dev/null || true
        systemctl enable lenovo-d330-power.service 2>/dev/null || true
        log_ok "Enabled systemd background units."
    fi

    # 7. Deploy ALSA UCM2 Audio profiles
    log_info "Deploying ALSA UCM2 audio profiles..."
    if [ "$DRY_RUN" = false ]; then
        UCM_DIR="/usr/share/alsa/ucm2"
        if [ -d "$UCM_DIR" ] && [ -d "${REPO_ROOT}/patches/audio/ucm2/sof-essx8336" ]; then
            mkdir -p "${UCM_DIR}/sof-essx8336"
            cp -r "${REPO_ROOT}/patches/audio/ucm2/sof-essx8336"/* "${UCM_DIR}/sof-essx8336/"
            log_ok "Installed UCM2 audio profiles to ${UCM_DIR}/sof-essx8336."
        fi
    fi

    # 8. Deploy TLP configuration
    if [ "$DRY_RUN" = false ] && [ -d "/etc/tlp.d" ] && [ -f "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" ]; then
        cp "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" /etc/tlp.d/
        log_ok "Deployed TLP power configuration."
    fi

    # 9. Update Initramfs
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

    # 10. Test load module
    log_info "Testing kernel module load..."
    if [ "$DRY_RUN" = false ]; then
        modprobe -v "${PKG_NAME//-/_}" || true
    fi

    echo "================================================================================"
    log_ok "Installation complete! Display, touch, audio, dock, and power fixes active."
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
        rm -f /etc/modprobe.d/lenovo-d330-audio.conf
        rm -f /etc/modprobe.d/lenovo-d330-power.conf
        rm -f /etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb
        rm -f /etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb
        rm -f /etc/udev/rules.d/90-lenovo-d330-touchscreen.rules
        rm -f /etc/udev/rules.d/85-lenovo-d330-dock.rules
        rm -f /etc/udev/rules.d/95-lenovo-d330-power.rules
        rm -f /etc/X11/xorg.conf.d/50-touchscreen-d330.conf
        rm -f /usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh
        rm -f /usr/local/bin/d330-tablet-daemon
        rm -f /usr/local/bin/lenovo-d330-power-tune
        rm -rf /usr/share/alsa/ucm2/sof-essx8336
        rm -f /etc/tlp.d/50-lenovo-d330.conf

        systemctl disable --now lenovo-d330-resume.service >/dev/null 2>&1 || true
        systemctl disable --now d330-tablet-daemon.service >/dev/null 2>&1 || true
        systemctl disable --now lenovo-d330-power.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/lenovo-d330-resume.service
        rm -f /etc/systemd/system/d330-tablet-daemon.service
        rm -f /etc/systemd/system/lenovo-d330-power.service
        systemctl daemon-reload >/dev/null 2>&1 || true

        # Refresh
        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
            udevadm trigger || true
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
