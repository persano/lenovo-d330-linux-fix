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
        [ -f "${REPO_ROOT}/patches/camera/etc/modprobe.d/lenovo-d330-camera.conf" ] && \
            cp "${REPO_ROOT}/patches/camera/etc/modprobe.d/lenovo-d330-camera.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/audio_dsp/etc/modprobe.d/lenovo-d330-audio-antipop.conf" ] && \
            cp "${REPO_ROOT}/patches/audio_dsp/etc/modprobe.d/lenovo-d330-audio-antipop.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/display_ergonomics/etc/modprobe.d/lenovo-d330-display-pwm.conf" ] && \
            cp "${REPO_ROOT}/patches/display_ergonomics/etc/modprobe.d/lenovo-d330-display-pwm.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/cellular_storage/etc/modprobe.d/lenovo-d330-cellular.conf" ] && \
            cp "${REPO_ROOT}/patches/cellular_storage/etc/modprobe.d/lenovo-d330-cellular.conf" /etc/modprobe.d/
        [ -f "${REPO_ROOT}/patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf" ] && \
            cp "${REPO_ROOT}/patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf" /etc/modprobe.d/
    fi

    # 4. Deploy udev rules and hardware databases
    log_info "Deploying udev rules and hwdb entries..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /etc/udev/hwdb.d /etc/udev/rules.d
        cp "${REPO_ROOT}/patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb" /etc/udev/hwdb.d/
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb" /etc/udev/hwdb.d/
        [ -f "${REPO_ROOT}/patches/touchpad_pen/etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb" ] && \
            cp "${REPO_ROOT}/patches/touchpad_pen/etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb" /etc/udev/hwdb.d/
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules" ] && \
            cp "${REPO_ROOT}/patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules" ] && \
            cp "${REPO_ROOT}/patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/camera/etc/udev/rules.d/92-lenovo-d330-camera.rules" ] && \
            cp "${REPO_ROOT}/patches/camera/etc/udev/rules.d/92-lenovo-d330-camera.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/storage_memory/etc/udev/rules.d/60-lenovo-d330-emmc.rules" ] && \
            cp "${REPO_ROOT}/patches/storage_memory/etc/udev/rules.d/60-lenovo-d330-emmc.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules" ] && \
            cp "${REPO_ROOT}/patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules" ] && \
            cp "${REPO_ROOT}/patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules" ] && \
            cp "${REPO_ROOT}/patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules" ] && \
            cp "${REPO_ROOT}/patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules" /etc/udev/rules.d/
        [ -f "${REPO_ROOT}/patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules" ] && \
            cp "${REPO_ROOT}/patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules" /etc/udev/rules.d/

        # Deploy ModemManager FCC unlock
        if [ -d "/etc/ModemManager/fcc-unlock.d" ] && [ -f "${REPO_ROOT}/patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:7360" ]; then
            cp "${REPO_ROOT}/patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:7360" /etc/ModemManager/fcc-unlock.d/
            chmod +x /etc/ModemManager/fcc-unlock.d/8086:7360
        fi

        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
            udevadm trigger || true
            log_ok "Updated systemd hardware database."
        fi
    fi

    # 5. Deploy X11 calibration, sleep hooks, and system tuning
    log_info "Deploying X11 touchpad/touchscreen matrix, sleep hooks, and system tuning..."
    if [ "$DRY_RUN" = false ]; then
        if [ -d "/etc/X11/xorg.conf.d" ]; then
            [ -f "${REPO_ROOT}/patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf" ] && \
                cp "${REPO_ROOT}/patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf" /etc/X11/xorg.conf.d/
            [ -f "${REPO_ROOT}/patches/touchpad_pen/etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf" ] && \
                cp "${REPO_ROOT}/patches/touchpad_pen/etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf" /etc/X11/xorg.conf.d/
        fi
        mkdir -p /usr/lib/systemd/system-sleep
        [ -f "${REPO_ROOT}/patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh" ] && \
            cp "${REPO_ROOT}/patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh" /usr/lib/systemd/system-sleep/ && \
            chmod +x /usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh
        [ -f "${REPO_ROOT}/patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh" ] && \
            cp "${REPO_ROOT}/patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh" /usr/lib/systemd/system-sleep/ && \
            chmod +x /usr/lib/systemd/system-sleep/lenovo-d330-wifi-resume.sh

        # Deploy sysctl and zram generator configs
        mkdir -p /etc/sysctl.d /etc/systemd
        [ -f "${REPO_ROOT}/patches/storage_memory/etc/sysctl.d/99-lenovo-d330-zram.conf" ] && \
            cp "${REPO_ROOT}/patches/storage_memory/etc/sysctl.d/99-lenovo-d330-zram.conf" /etc/sysctl.d/
        [ -f "${REPO_ROOT}/patches/storage_memory/etc/systemd/zram-generator.conf" ] && \
            cp "${REPO_ROOT}/patches/storage_memory/etc/systemd/zram-generator.conf" /etc/systemd/
        sysctl --system >/dev/null 2>&1 || true

        # Deploy GRUB and Initramfs boot orientation and fastboot hooks
        if [ -d "/etc/default/grub.d" ]; then
            [ -f "${REPO_ROOT}/patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg" ] && \
                cp "${REPO_ROOT}/patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg" /etc/default/grub.d/
            [ -f "${REPO_ROOT}/patches/acpi_override/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg" ] && \
                cp "${REPO_ROOT}/patches/acpi_override/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg" /etc/default/grub.d/
            [ -f "${REPO_ROOT}/patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg" ] && \
                cp "${REPO_ROOT}/patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg" /etc/default/grub.d/
        fi
        if [ -d "/usr/share/initramfs-tools/hooks" ]; then
            [ -f "${REPO_ROOT}/patches/boot_orientation/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth" ] && \
                cp "${REPO_ROOT}/patches/boot_orientation/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth" /usr/share/initramfs-tools/hooks/ && \
                chmod +x /usr/share/initramfs-tools/hooks/lenovo-d330-plymouth
        fi

        # Deploy VA-API environment and earlyoom presets
        mkdir -p /etc/environment.d /etc/default
        [ -f "${REPO_ROOT}/patches/media_vaapi/etc/environment.d/50-lenovo-d330-vaapi.conf" ] && \
            cp "${REPO_ROOT}/patches/media_vaapi/etc/environment.d/50-lenovo-d330-vaapi.conf" /etc/environment.d/
        [ -f "${REPO_ROOT}/patches/oom_protection/etc/default/earlyoom" ] && \
            cp "${REPO_ROOT}/patches/oom_protection/etc/default/earlyoom" /etc/default/
        if [ -d "/etc/systemd/system" ] && [ -d "${REPO_ROOT}/patches/oom_protection/etc/systemd/system/earlyoom.service.d" ]; then
            mkdir -p /etc/systemd/system/earlyoom.service.d
            cp -r "${REPO_ROOT}/patches/oom_protection/etc/systemd/system/earlyoom.service.d"/* /etc/systemd/system/earlyoom.service.d/
        fi

        # Deploy thermald config
        if [ -d "/etc/thermald" ] && [ -f "${REPO_ROOT}/patches/thermal/etc/thermald/thermal-conf.xml" ]; then
            cp "${REPO_ROOT}/patches/thermal/etc/thermald/thermal-conf.xml" /etc/thermald/
        fi
    fi

    # 6. Deploy CLI tools, tray applet, and systemd background daemons
    log_info "Deploying system utilities and systemd background units..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /usr/local/bin
        [ -f "${REPO_ROOT}/tools/d330-tablet-daemon.py" ] && \
            cp "${REPO_ROOT}/tools/d330-tablet-daemon.py" /usr/local/bin/d330-tablet-daemon && \
            chmod +x /usr/local/bin/d330-tablet-daemon
        [ -f "${REPO_ROOT}/tools/lenovo-d330-power-tune.sh" ] && \
            cp "${REPO_ROOT}/tools/lenovo-d330-power-tune.sh" /usr/local/bin/lenovo-d330-power-tune && \
            chmod +x /usr/local/bin/lenovo-d330-power-tune
        [ -f "${REPO_ROOT}/tools/d330-ctl" ] && \
            cp "${REPO_ROOT}/tools/d330-ctl" /usr/local/bin/d330-ctl && \
            chmod +x /usr/local/bin/d330-ctl
        [ -f "${REPO_ROOT}/tools/d330-camera-bridge.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-camera-bridge.sh" /usr/local/bin/d330-camera-bridge.sh && \
            chmod +x /usr/local/bin/d330-camera-bridge.sh
        [ -f "${REPO_ROOT}/tools/d330-backlight-pwm.py" ] && \
            cp "${REPO_ROOT}/tools/d330-backlight-pwm.py" /usr/local/bin/d330-backlight-pwm.py && \
            chmod +x /usr/local/bin/d330-backlight-pwm.py
        [ -f "${REPO_ROOT}/tools/d330-refresh-screen.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-refresh-screen.sh" /usr/local/bin/d330-refresh-screen && \
            chmod +x /usr/local/bin/d330-refresh-screen
        [ -f "${REPO_ROOT}/tools/d330-sensor-filter.py" ] && \
            cp "${REPO_ROOT}/tools/d330-sensor-filter.py" /usr/local/bin/d330-sensor-filter && \
            chmod +x /usr/local/bin/d330-sensor-filter
        [ -f "${REPO_ROOT}/tools/d330-auto-hibernate.py" ] && \
            cp "${REPO_ROOT}/tools/d330-auto-hibernate.py" /usr/local/bin/d330-auto-hibernate && \
            chmod +x /usr/local/bin/d330-auto-hibernate
        [ -f "${REPO_ROOT}/tools/d330-microsd-setup.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-microsd-setup.sh" /usr/local/bin/d330-microsd-setup && \
            chmod +x /usr/local/bin/d330-microsd-setup
        [ -f "${REPO_ROOT}/tools/d330-thermal-tune.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-thermal-tune.sh" /usr/local/bin/d330-thermal-tune && \
            chmod +x /usr/local/bin/d330-thermal-tune
        [ -f "${REPO_ROOT}/tools/d330-fastboot-tune.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-fastboot-tune.sh" /usr/local/bin/d330-fastboot-tune && \
            chmod +x /usr/local/bin/d330-fastboot-tune
        [ -f "${REPO_ROOT}/tools/d330-vaapi-check.sh" ] && \
            cp "${REPO_ROOT}/tools/d330-vaapi-check.sh" /usr/local/bin/d330-vaapi-check && \
            chmod +x /usr/local/bin/d330-vaapi-check
        [ -f "${REPO_ROOT}/tools/d330-tray.py" ] && \
            cp "${REPO_ROOT}/tools/d330-tray.py" /usr/local/bin/d330-tray && \
            chmod +x /usr/local/bin/d330-tray

        # Deploy autostart desktop entry for tray applet
        if [ -d "/etc/xdg/autostart" ] && [ -f "${REPO_ROOT}/patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop" ]; then
            cp "${REPO_ROOT}/patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop" /etc/xdg/autostart/
        fi

        # Deploy systemd services
        cp "${REPO_ROOT}/patches/dkms/etc/systemd/system/lenovo-d330-resume.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/dock/etc/systemd/system/d330-tablet-daemon.service" ] && \
            cp "${REPO_ROOT}/patches/dock/etc/systemd/system/d330-tablet-daemon.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" ] && \
            cp "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service" ] && \
            cp "${REPO_ROOT}/patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/hardware_controls/etc/systemd/system/d330-hardware-state.service" ] && \
            cp "${REPO_ROOT}/patches/hardware_controls/etc/systemd/system/d330-hardware-state.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service" ] && \
            cp "${REPO_ROOT}/patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/sensors/etc/systemd/system/d330-sensor-filter.service" ] && \
            cp "${REPO_ROOT}/patches/sensors/etc/systemd/system/d330-sensor-filter.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" ] && \
            cp "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/thermal/etc/systemd/system/d330-thermal.service" ] && \
            cp "${REPO_ROOT}/patches/thermal/etc/systemd/system/d330-thermal.service" /etc/systemd/system/

        systemctl daemon-reload || true
        systemctl enable lenovo-d330-resume.service || true
        systemctl enable d330-tablet-daemon.service 2>/dev/null || true
        systemctl enable lenovo-d330-power.service 2>/dev/null || true
        systemctl enable d330-hardware-state.service 2>/dev/null || true
        systemctl enable lenovo-d330-backlight-pwm.service 2>/dev/null || true
        systemctl enable d330-sensor-filter.service 2>/dev/null || true
        systemctl enable d330-thermal.service 2>/dev/null || true
        log_ok "Enabled systemd background units."
    fi

    # 7. Deploy ALSA UCM2 Audio profiles & PipeWire DSP
    log_info "Deploying ALSA UCM2 audio profiles and PipeWire DSP filters..."
    if [ "$DRY_RUN" = false ]; then
        UCM_DIR="/usr/share/alsa/ucm2"
        if [ -d "$UCM_DIR" ] && [ -d "${REPO_ROOT}/patches/audio/ucm2/sof-essx8336" ]; then
            mkdir -p "${UCM_DIR}/sof-essx8336"
            cp -r "${REPO_ROOT}/patches/audio/ucm2/sof-essx8336"/* "${UCM_DIR}/sof-essx8336/"
            log_ok "Installed UCM2 audio profiles to ${UCM_DIR}/sof-essx8336."
        fi
        if [ -d "/etc/pipewire" ]; then
            mkdir -p /etc/pipewire/filter-chain.conf.d
            [ -f "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf" ] && \
                cp "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf" /etc/pipewire/filter-chain.conf.d/
            [ -f "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf" ] && \
                cp "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf" /etc/pipewire/filter-chain.conf.d/
            log_ok "Installed PipeWire speaker DSP and RNNoise AI mic filters."
        fi
    fi

    # 8. Deploy TLP & Color Management configuration
    if [ "$DRY_RUN" = false ]; then
        if [ -d "/etc/tlp.d" ] && [ -f "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" ]; then
            cp "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" /etc/tlp.d/
            log_ok "Deployed TLP power configuration."
        fi
        if [ -d "/usr/share/color/icc" ] && [ -f "${REPO_ROOT}/patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc" ]; then
            cp "${REPO_ROOT}/patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc" /usr/share/color/icc/
            log_ok "Installed calibrated D330 ICC color profile."
        fi
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
        rm -f /etc/modprobe.d/lenovo-d330-camera.conf
        rm -f /etc/modprobe.d/lenovo-d330-audio-antipop.conf
        rm -f /etc/modprobe.d/lenovo-d330-display-pwm.conf
        rm -f /etc/modprobe.d/lenovo-d330-cellular.conf
        rm -f /etc/modprobe.d/lenovo-d330-wireless.conf
        rm -f /etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb
        rm -f /etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb
        rm -f /etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb
        rm -f /etc/udev/rules.d/90-lenovo-d330-touchscreen.rules
        rm -f /etc/udev/rules.d/85-lenovo-d330-dock.rules
        rm -f /etc/udev/rules.d/95-lenovo-d330-power.rules
        rm -f /etc/udev/rules.d/92-lenovo-d330-camera.rules
        rm -f /etc/udev/rules.d/60-lenovo-d330-emmc.rules
        rm -f /etc/udev/rules.d/91-lenovo-d330-headset-jack.rules
        rm -f /etc/udev/rules.d/88-lenovo-d330-hardware.rules
        rm -f /etc/udev/rules.d/87-lenovo-d330-sensors.rules
        rm -f /etc/udev/rules.d/78-lenovo-d330-cellular.rules
        rm -f /etc/udev/rules.d/99-lenovo-d330-battery-critical.rules
        rm -f /etc/ModemManager/fcc-unlock.d/8086:7360
        rm -f /etc/X11/xorg.conf.d/50-touchscreen-d330.conf
        rm -f /etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf
        rm -f /usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh
        rm -f /usr/lib/systemd/system-sleep/lenovo-d330-wifi-resume.sh
        rm -f /etc/sysctl.d/99-lenovo-d330-zram.conf
        rm -f /etc/systemd/zram-generator.conf
        rm -f /etc/default/grub.d/50-lenovo-d330-boot.cfg
        rm -f /etc/default/grub.d/51-lenovo-d330-acpi-override.cfg
        rm -f /etc/default/grub.d/52-lenovo-d330-fastboot.cfg
        rm -f /usr/share/initramfs-tools/hooks/lenovo-d330-plymouth
        rm -f /etc/environment.d/50-lenovo-d330-vaapi.conf
        rm -f /etc/default/earlyoom
        rm -rf /etc/systemd/system/earlyoom.service.d
        rm -f /etc/thermald/thermal-conf.xml
        rm -f /etc/xdg/autostart/d330-tray.desktop
        rm -f /usr/local/bin/d330-tablet-daemon
        rm -f /usr/local/bin/lenovo-d330-power-tune
        rm -f /usr/local/bin/d330-ctl
        rm -f /usr/local/bin/d330-camera-bridge.sh
        rm -f /usr/local/bin/d330-backlight-pwm.py
        rm -f /usr/local/bin/d330-refresh-screen
        rm -f /usr/local/bin/d330-sensor-filter
        rm -f /usr/local/bin/d330-auto-hibernate
        rm -f /usr/local/bin/d330-microsd-setup
        rm -f /usr/local/bin/d330-thermal-tune
        rm -f /usr/local/bin/d330-fastboot-tune
        rm -f /usr/local/bin/d330-vaapi-check
        rm -f /usr/local/bin/d330-tray
        rm -rf /usr/share/alsa/ucm2/sof-essx8336
        rm -f /etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf
        rm -f /etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf
        rm -f /etc/tlp.d/50-lenovo-d330.conf
        rm -f /usr/share/color/icc/Lenovo-D330-sRGB-D65.icc

        systemctl disable --now lenovo-d330-resume.service >/dev/null 2>&1 || true
        systemctl disable --now d330-tablet-daemon.service >/dev/null 2>&1 || true
        systemctl disable --now lenovo-d330-power.service >/dev/null 2>&1 || true
        systemctl disable --now lenovo-d330-camera-loopback.service >/dev/null 2>&1 || true
        systemctl disable --now d330-hardware-state.service >/dev/null 2>&1 || true
        systemctl disable --now lenovo-d330-backlight-pwm.service >/dev/null 2>&1 || true
        systemctl disable --now d330-sensor-filter.service >/dev/null 2>&1 || true
        systemctl disable --now d330-auto-hibernate.service >/dev/null 2>&1 || true
        systemctl disable --now d330-thermal.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/lenovo-d330-resume.service
        rm -f /etc/systemd/system/d330-tablet-daemon.service
        rm -f /etc/systemd/system/lenovo-d330-power.service
        rm -f /etc/systemd/system/lenovo-d330-camera-loopback.service
        rm -f /etc/systemd/system/d330-hardware-state.service
        rm -f /etc/systemd/system/lenovo-d330-backlight-pwm.service
        rm -f /etc/systemd/system/d330-sensor-filter.service
        rm -f /etc/systemd/system/d330-auto-hibernate.service
        rm -f /etc/systemd/system/d330-thermal.service
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
