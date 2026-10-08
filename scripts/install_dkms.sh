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
  --verify [--root DIR] [--removed]
                Diff deployed paths against the installer's own deploy manifest and
                exit non-zero on drift. Read-only: needs neither build tools nor root.
                --root DIR checks a fixture tree instead of / (skips systemctl checks).
                --removed inverts the contract: assert every manifest path is ABSENT
                (exit non-zero if any is present) -- machine-checks that an
                install-then-uninstall leaves nothing behind (SC1).
  --dump-manifest
                Print the deploy manifest as path<TAB>kind lines and exit (read-only).
  --kernel-src PATH
                Option 2: apply patches/d330_display_resume_fix.patch to the
                kernel source tree at PATH. Gated by `patch -p1 --dry-run`;
                a context mismatch warns and never fails the install.
  -h, --help    Display this help message
EOF
}

# ------------------------------------------------------------------------------
# deploy_manifest: the SINGLE source of truth for the deployed artifact set.
#
# Emits `path<TAB>kind` for every artifact install/uninstall/--verify care about.
# Kinds:
#   dir          installer-owned directory removed wholesale on uninstall
#   file         deployed config/data file (existence + removal)
#   exec         deployed executable (existence + exec bit + removal)
#   unit         systemd unit file copied to /etc/systemd/system
#   unit-enabled runtime enablement target (is-enabled; skipped for --root != /,
#                and skipped unless systemd is actually PID 1)
#   unit-user    systemd USER unit file copied to /usr/lib/systemd/user
#   unit-user-enabled global user-unit enablement (symlink under
#                /etc/systemd/user/default.target.wants; skipped for --root != /
#                and unless systemd is actually PID 1)
#   grub-snippet /etc/default/grub.d snippet (GRUB must be regenerated both ways)
#   fstab-line   exact /etc/fstab line (skipped for --root != /)
#   state        runtime state file (written by a unit ExecStop, removed on
#                uninstall); verify reports SKIP when absent for --verify
#   *-optional   conditionally-deployed artifact (file-optional, exec-optional,
#                grub-snippet-optional): install only copies it when the target
#                dir already exists or hibernate activation succeeded, so --verify
#                reports SKIP (not DRIFT) when it is absent.
#
# Ordering, logged output and copy semantics of do_install()/do_uninstall() are
# intentionally preserved (the phase-33 hibernate guard suite greps their exact
# literal lines); this manifest is the authoritative inventory that --verify
# diffs against and that the symmetry guard suite cross-checks the script for.
# ------------------------------------------------------------------------------
deploy_manifest() {
    cat <<'MANIFEST'
/usr/src/lenovo-d330-fix-1.0.0	dir
/etc/modprobe.d/lenovo-d330-i915.conf	file
/etc/modprobe.d/lenovo-d330-audio.conf	file
/etc/modprobe.d/lenovo-d330-power.conf	file
/etc/modprobe.d/lenovo-d330-camera.conf	file
/etc/modprobe.d/lenovo-d330-audio-antipop.conf	file
/etc/modprobe.d/lenovo-d330-display-pwm.conf	file
/etc/modprobe.d/lenovo-d330-cellular.conf	file
/etc/modprobe.d/lenovo-d330-wireless.conf	file
/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb	file
/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb	file
/etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb	file
/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules	file
/etc/udev/rules.d/85-lenovo-d330-dock.rules	file
/etc/udev/rules.d/95-lenovo-d330-power.rules	file
/etc/udev/rules.d/92-lenovo-d330-camera.rules	file
/etc/udev/rules.d/60-lenovo-d330-emmc.rules	file
/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules	file
/etc/udev/rules.d/88-lenovo-d330-hardware.rules	file
/etc/udev/rules.d/87-lenovo-d330-sensors.rules	file
/etc/udev/rules.d/78-lenovo-d330-cellular.rules	file
/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules	file
/etc/ModemManager/fcc-unlock.d/8086:7360	exec-optional
/etc/X11/xorg.conf.d/50-touchscreen-d330.conf	file-optional
/etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf	file-optional
/usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh	exec
/usr/lib/systemd/system-sleep/lenovo-d330-wifi-resume.sh	exec
/etc/sysctl.d/99-lenovo-d330-zram.conf	file
/etc/systemd/zram-generator.conf	file
/etc/default/grub.d/50-lenovo-d330-boot.cfg	grub-snippet
/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg	grub-snippet
/etc/default/grub.d/52-lenovo-d330-fastboot.cfg	grub-snippet
/etc/default/grub.d/53-lenovo-d330-resume.cfg	grub-snippet-optional
/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth	exec-optional
/etc/environment.d/50-lenovo-d330-vaapi.conf	file
/etc/default/earlyoom	file
/etc/systemd/system/earlyoom.service.d/d330-override.conf	file
/etc/thermald/thermal-conf.xml	file-optional
/etc/xdg/autostart/d330-tray.desktop	file-optional
/usr/local/bin/d330-tablet-daemon	exec
/usr/local/bin/lenovo-d330-power-tune	exec
/usr/local/bin/d330-ctl	exec
/usr/local/bin/d330-camera-bridge.sh	exec
/usr/local/bin/d330-backlight-pwm.py	exec
/usr/local/bin/d330-refresh-screen	exec
/usr/local/bin/d330-sensor-filter	exec
/usr/local/bin/d330-auto-hibernate	exec
/usr/local/bin/d330-microsd-setup	exec
/usr/local/bin/d330-thermal-tune	exec
/usr/local/bin/d330-fastboot-tune	exec
/usr/local/bin/d330-vaapi-check	exec
/usr/local/bin/d330-tray	exec
/usr/lib/systemd/user/d330-tablet-daemon.service	unit-user
/etc/systemd/system/lenovo-d330-power.service	unit
/etc/systemd/system/lenovo-d330-camera-loopback.service	unit
/etc/systemd/system/d330-hardware-state.service	unit
/etc/systemd/system/d330-sensor-filter.service	unit
/etc/systemd/system/d330-auto-hibernate.service	unit
/etc/systemd/system/d330-thermal.service	unit
/etc/systemd/system/d330-swapfile.service	unit
/usr/share/alsa/ucm2/sof-essx8336	dir-optional
/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf	file-optional
/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf	file-optional
/etc/tlp.d/50-lenovo-d330.conf	file-optional
/usr/share/color/icc/Lenovo-D330-sRGB-D65.icc	file-optional
/etc/d330-hardware-state.json	state
d330-tablet-daemon.service	unit-user-enabled
lenovo-d330-power.service	unit-enabled
lenovo-d330-camera-loopback.service	unit-enabled
d330-hardware-state.service	unit-enabled
d330-sensor-filter.service	unit-enabled
d330-auto-hibernate.service	unit-enabled
d330-thermal.service	unit-enabled
d330-swapfile.service	unit-enabled
/var/swapfile none swap sw 0 0	fstab-line
MANIFEST
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

    # Optional RNNoise LADSPA dependency (Phase 38): the PipeWire mic filter-chain
    # (51-lenovo-d330-rnnoise-mic.conf) denoises via librnnoise_ladspa.so. The
    # module carries `flags = [ nofail ]`, so its absence is non-fatal, but a
    # missing plugin means the denoiser silently stays inactive -- surface it.
    # Search the same paths scripts/test_mic_rnnoise.sh uses.
    local rnnoise_dirs="/usr/lib/ladspa:/usr/lib/*/ladspa" rnnoise_d rnnoise_cand
    local rnnoise_found=false
    local IFS=':'
    # shellcheck disable=SC2086  # $rnnoise_d may intentionally hold a glob
    for rnnoise_d in $rnnoise_dirs; do
        # shellcheck disable=SC2086
        for rnnoise_cand in $rnnoise_d/librnnoise_ladspa.so; do
            if [ -f "$rnnoise_cand" ]; then
                rnnoise_found=true
            fi
        done
    done
    if [ "$rnnoise_found" != true ]; then
        log_warn "librnnoise_ladspa.so not found (/usr/lib/ladspa, /usr/lib/*/ladspa)."
        log_warn "RNNoise mic denoiser stays inactive; install it via: apt install librnnoise-ladspa"
    else
        log_ok "librnnoise_ladspa.so found; RNNoise mic denoiser available."
    fi

    log_ok "Prerequisites satisfied."
}

# ------------------------------------------------------------------------------
# run_kernel_src_step: optional Option 2 clamp-patch step (Phase 34).
#
# Applies patches/d330_display_resume_fix.patch to an operator-supplied kernel
# source tree. Gated behind `patch -p1 --dry-run`: on stock kernels the hunk
# context does not match, so the common path is a loud [WARN] + skip, never an
# install failure (research Q2). Every expansion is quoted; no eval; the patch
# runs only under the explicitly passed path.
# ------------------------------------------------------------------------------
run_kernel_src_step() {
    local kernel_src="$1"
    local patch_file="${REPO_ROOT}/patches/d330_display_resume_fix.patch"

    if [ ! -d "$kernel_src" ]; then
        log_warn "--kernel-src '$kernel_src' is not a directory; skipping clamp patch."
        return 0
    fi
    if [ ! -f "$patch_file" ]; then
        log_warn "clamp patch not found at '$patch_file'; skipping."
        return 0
    fi

    # Sanity-check the path is a kernel tree before running patch as root.
    local looks_like_kernel=false
    if [ -f "${kernel_src}/Kconfig" ]; then
        looks_like_kernel=true
    elif [ -f "${kernel_src}/Makefile" ] && \
         grep -Eq '^(VERSION|KERNELVERSION)' "${kernel_src}/Makefile" 2>/dev/null; then
        looks_like_kernel=true
    fi
    if [ "$looks_like_kernel" != true ]; then
        log_warn "'$kernel_src' does not look like a kernel source tree (no Kconfig / VERSION Makefile); skipping clamp patch."
        return 0
    fi

    if ! command -v patch >/dev/null 2>&1; then
        log_warn "'patch' is not installed; skipping clamp patch."
        return 0
    fi

    log_info "Probing clamp patch against kernel tree '$kernel_src' (patch -p1 --dry-run)..."
    local dry_rc=0
    # WR-04: no --forward here -- with it, an already-clamped tree reports
    # "Skipping patch" and returns non-zero, producing a false "clamp NOT
    # delivered" warning. Plain --dry-run only gates on context applicability.
    patch -p1 -d "$kernel_src" --dry-run --batch < "$patch_file" >/dev/null 2>&1 || dry_rc=$?

    if [ "$dry_rc" -ne 0 ]; then
        log_warn "Clamp patch does NOT apply to '$kernel_src' (context mismatch; rc=$dry_rc)."
        log_warn "The running kernel does not match the patch context, so the 600 ms PPS clamp is NOT delivered."
        log_warn "Option 2 must be applied manually after adapting the hunks to your kernel tree; install continues."
        return 0
    fi

    log_ok "Clamp patch dry-run succeeded against '$kernel_src'."
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would apply clamp patch to '$kernel_src'; skipping real apply."
        return 0
    fi

    local apply_rc=0
    patch -p1 -d "$kernel_src" --forward --batch < "$patch_file" >/dev/null 2>&1 || apply_rc=$?
    if [ "$apply_rc" -ne 0 ]; then
        log_warn "Clamp patch real apply failed (rc=$apply_rc); skipping. Install continues."
        return 0
    fi
    log_ok "Applied clamp patch to '$kernel_src'."
    log_warn "The running kernel is unaffected until you rebuild and reinstall it, then reboot."
    return 0
}

# ------------------------------------------------------------------------------
# run_grub_regen: regenerate the bootloader config after ANY /etc/default/grub.d
# mutation, in BOTH do_install and do_uninstall (M1). Tool ladder is the phase-
# 33/34 one (update-grub -> grub2-mkconfig -> grub-mkconfig). Warn-not-fail: a
# missing tool logs a named [WARN] and returns 1, but never aborts install or
# uninstall (Threat T-35-04). Optional $1 is a context string for the log line.
# ------------------------------------------------------------------------------
run_grub_regen() {
    local ctx="${1:-}"
    local suffix=""
    [ -n "$ctx" ] && suffix=" ($ctx)"

    if command -v update-grub >/dev/null 2>&1; then
        log_info "Regenerating GRUB config via update-grub${suffix}..."
        update-grub || true
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        log_info "Regenerating GRUB config via grub2-mkconfig${suffix}..."
        grub2-mkconfig -o /boot/grub2/grub.cfg || true
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        log_info "Regenerating GRUB config via grub-mkconfig${suffix}..."
        grub-mkconfig -o /boot/grub/grub.cfg || true
    else
        log_warn "grub config changed but no mkconfig tool found; GRUB not regenerated -- reboot/bootloader may not pick it up."
        return 1
    fi
    return 0
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

    # 2b. Optional Option 2 clamp patch (Phase 34): only when --kernel-src given.
    if [ -n "${KERNEL_SRC:-}" ]; then
        run_kernel_src_step "$KERNEL_SRC"
    else
        log_info "Clamp patch not applied (no --kernel-src given); Option 1 ships the DMI banner module only."
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

        # Deploy ModemManager FCC unlock. The repo stores the hook as `8086`
        # because Windows cannot track a literal colon in a filename; ModemManager
        # looks it up as `8086:7360`, so it is copied to that colon-named target.
        if [ -d "/etc/ModemManager/fcc-unlock.d" ] && [ -f "${REPO_ROOT}/patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086" ]; then
            cp "${REPO_ROOT}/patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086" /etc/ModemManager/fcc-unlock.d/8086:7360
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
            # M1: without a regen the copied 50/51/52 snippets never take effect.
            run_grub_regen "grub.d snippets deployed" || true
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
        if [ -d "/etc/thermald" ]; then
            if [ -f "${REPO_ROOT}/patches/thermal/etc/thermald/thermal-conf.xml" ]; then
                cp "${REPO_ROOT}/patches/thermal/etc/thermald/thermal-conf.xml" /etc/thermald/
            fi
        else
            log_warn "/etc/thermald not found (thermald not installed?); skipping thermal-conf.xml deployment."
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
        # M6: the tablet daemon is a systemd USER unit so it inherits the
        # graphical session env (DISPLAY/DBUS); copy it to /usr/lib/systemd/user
        # instead of the system unit directory.
        mkdir -p /usr/lib/systemd/user
        [ -f "${REPO_ROOT}/patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service" ] && \
            cp "${REPO_ROOT}/patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service" /usr/lib/systemd/user/
        [ -f "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" ] && \
            cp "${REPO_ROOT}/patches/power/etc/systemd/system/lenovo-d330-power.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service" ] && \
            cp "${REPO_ROOT}/patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/hardware_controls/etc/systemd/system/d330-hardware-state.service" ] && \
            cp "${REPO_ROOT}/patches/hardware_controls/etc/systemd/system/d330-hardware-state.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/sensors/etc/systemd/system/d330-sensor-filter.service" ] && \
            cp "${REPO_ROOT}/patches/sensors/etc/systemd/system/d330-sensor-filter.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" ] && \
            cp "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/thermal/etc/systemd/system/d330-thermal.service" ] && \
            cp "${REPO_ROOT}/patches/thermal/etc/systemd/system/d330-thermal.service" /etc/systemd/system/
        [ -f "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-swapfile.service" ] && \
            cp "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-swapfile.service" /etc/systemd/system/

        systemctl daemon-reload || true
        # Phase 34 removed the echo-only resume unit; Phase 37 removed the
        # no-op PWM boot unit. The shipped census is now 8 units
        # (35-RESEARCH Finding 2, adjusted for 37). SC2: all 8 must return
        # enabled, so this enable block, packaging/debian/postinst and the
        # RPM %post each enable the same 8 (camera-loopback was the
        # previously-missing one).
        # M6: enable the tablet daemon as a GLOBAL user unit (not a system unit).
        # If systemd-user is unavailable (systemctl absent, or systemd not PID 1),
        # warn honestly instead of silently pretending the unit is enabled.
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            systemctl --global enable d330-tablet-daemon.service 2>/dev/null || \
                log_warn "systemctl --global enable d330-tablet-daemon.service failed; tablet user unit not enabled."
        else
            log_warn "systemd user manager unavailable (no systemctl or /run/systemd/system); tablet user unit not enabled."
        fi
        systemctl enable lenovo-d330-power.service 2>/dev/null || true
        systemctl enable lenovo-d330-camera-loopback.service 2>/dev/null || true
        systemctl enable d330-hardware-state.service 2>/dev/null || true
        systemctl enable d330-sensor-filter.service 2>/dev/null || true
        systemctl enable d330-thermal.service 2>/dev/null || true
        systemctl enable d330-auto-hibernate.service 2>/dev/null || true
        systemctl enable d330-swapfile.service 2>/dev/null || true
        log_ok "Enabled systemd background units."

        # ------------------------------------------------------------------
        # Resume activation (Plan 33-02): swapfile persist + kernel cmdline.
        # Fail-closed, phase-32 guard posture: [WARN] lines instead of
        # half-executed steps, success printed only on genuine completion.
        # Units are already enabled above (SC3), so the manual-step non-zero
        # exit at the end of this block never un-enables anything.
        # ------------------------------------------------------------------

        # 1. Create the swapfile by starting the freshly-copied unit. On
        #    failure (free-space guard or dd/mkswap, RESEARCH R6) warn loudly,
        #    skip ALL remaining activation sub-steps, and let install continue:
        #    the daemon degrades honestly to suspend (Plan 33-01).
        SWAPFILE_READY=false
        if systemctl start d330-swapfile.service; then
            SWAPFILE_READY=true
        else
            log_warn "d330-swapfile.service failed to create /var/swapfile (free space or dd/mkswap failure)."
            log_warn "hibernate stays unavailable; skipping resume activation. Install continues (daemon degrades to suspend)."
        fi

        if [ "$SWAPFILE_READY" = true ]; then
            # 2. Persist activation (RESEARCH R5): verify-before-append, refuse
            #    duplicates, report the line before writing it (phase-32 seam).
            FSTAB_SWAP_LINE="/var/swapfile none swap sw 0 0"
            if grep -qxF "$FSTAB_SWAP_LINE" /etc/fstab; then
                log_info "fstab swap line already present, skipping duplicate append."
            else
                log_info "Planned fstab append: $FSTAB_SWAP_LINE"
                # Trailing-newline guard (review WR-03): a last line without a
                # newline would glue onto this append; only append the newline
                # when the file is non-empty and actually ends without one.
                if [ -s /etc/fstab ] && [ -n "$(tail -c1 /etc/fstab)" ]; then
                    echo >> /etc/fstab
                fi
                echo "$FSTAB_SWAP_LINE" >> /etc/fstab
            fi

            # 3. Validate offset unit basis (R7): fs block size must equal page
            #    size or resume_offset units would silently break resume.
            FS_BLOCK_SIZE="$(stat -f -c %S / 2>/dev/null || echo 0)"
            PAGE_SIZE="$(getconf PAGESIZE 2>/dev/null || echo 0)"
            OFFSET_UNITS_OK=false
            # Fail closed (review IN-03): both values must be positive before
            # equality means anything -- 0=0 (stat and getconf both failed)
            # must NOT pass the guard.
            if echo "$FS_BLOCK_SIZE" | grep -qE '^[1-9][0-9]*$' && \
               echo "$PAGE_SIZE" | grep -qE '^[1-9][0-9]*$' && \
               [ "$FS_BLOCK_SIZE" = "$PAGE_SIZE" ]; then
                OFFSET_UNITS_OK=true
            else
                log_warn "fs block size ($FS_BLOCK_SIZE) / page size ($PAGE_SIZE) is invalid or unequal; resume_offset units would be wrong."
            fi

            # 4. Offset EXCLUSIVELY from filefrag -v first extent physical
            #    (RESEARCH Q1.4 tooling correction: the swapon OFFSET column
            #    variant does not exist and must never appear here).
            RESUME_OFFSET=""
            if [ "$OFFSET_UNITS_OK" = true ]; then
                RESUME_OFFSET="$(filefrag -v /var/swapfile 2>/dev/null | awk '/^[[:space:]]*0:/{print $4; exit}' | sed 's/\.\..*//' || true)"
                RESUME_OFFSET="${RESUME_OFFSET:-}"
            fi
            if ! echo "$RESUME_OFFSET" | grep -qE '^[0-9]+$'; then
                log_warn "could not compute resume_offset via filefrag -v for /var/swapfile."
                RESUME_OFFSET=""
            fi

            # 5. Root UUID (RESEARCH §2): exit codes captured explicitly so a
            #    failure cannot trip set -e before an honest message prints.
            ROOT_SRC="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
            ROOT_UUID=""
            if [ -n "$ROOT_SRC" ]; then
                ROOT_UUID="$(blkid -s UUID -o value "$ROOT_SRC" 2>/dev/null || true)"
            fi
            if [ -z "$ROOT_UUID" ]; then
                log_warn "could not read root UUID from '${ROOT_SRC:-unknown}'."
            fi

            # 6. Render the snippet: substitute the two placeholder tokens in
            #    the repo template (never modified) and write ONLY under
            #    /etc/default/grub.d, only when content differs (idempotent).
            SNIPPET_RENDERED=""
            if [ -n "$ROOT_UUID" ] && [ -n "$RESUME_OFFSET" ]; then
                SNIPPET_RENDERED="$(sed -e "s/__D330_RESUME_UUID__/${ROOT_UUID}/" -e "s/__D330_RESUME_OFFSET__/${RESUME_OFFSET}/" \
                    "${REPO_ROOT}/patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg" || true)"
                if [ -d /etc/default/grub.d ]; then
                    if [ -f /etc/default/grub.d/53-lenovo-d330-resume.cfg ] && \
                       grep -qxF "GRUB_CMDLINE_LINUX_DEFAULT=\"\${GRUB_CMDLINE_LINUX_DEFAULT} resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}\"" /etc/default/grub.d/53-lenovo-d330-resume.cfg; then
                        log_info "Resume grub.d snippet already rendered with current values, not rewriting."
                    else
                        printf '%s\n' "$SNIPPET_RENDERED" > /etc/default/grub.d/53-lenovo-d330-resume.cfg
                        log_ok "Rendered /etc/default/grub.d/53-lenovo-d330-resume.cfg (resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET})."
                    fi
                else
                    log_warn "/etc/default/grub.d does not exist; cannot deploy resume snippet."
                fi
            fi

            # 7. Activation + verification ladder (R2): detect mkconfig in
            #    order update-grub -> grub2-mkconfig -> grub-mkconfig, run it,
            #    then grep the generated grub.cfg for resume_offset=. Failure
            #    of ANY link prints the exact required cmdline as a manual step
            #    and exits non-zero (locked honest behavior; enablement above
            #    already happened, so SC3 survives this exit).
            MKCONFIG_TOOL=""
            GRUB_CFG=""
            if command -v update-grub >/dev/null 2>&1; then
                MKCONFIG_TOOL="update-grub"; GRUB_CFG="/boot/grub/grub.cfg"
            elif command -v grub2-mkconfig >/dev/null 2>&1; then
                MKCONFIG_TOOL="grub2-mkconfig"; GRUB_CFG="/boot/grub2/grub.cfg"
            elif command -v grub-mkconfig >/dev/null 2>&1; then
                MKCONFIG_TOOL="grub-mkconfig"; GRUB_CFG="/boot/grub/grub.cfg"
            fi

            ACTIVATION_OK=false
            if [ -n "$MKCONFIG_TOOL" ] && [ -n "$ROOT_UUID" ] && [ -n "$RESUME_OFFSET" ] && [ -f /etc/default/grub.d/53-lenovo-d330-resume.cfg ]; then
                log_info "Regenerating GRUB config via ${MKCONFIG_TOOL}..."
                if [ "$MKCONFIG_TOOL" = "update-grub" ]; then
                    update-grub || true
                else
                    "$MKCONFIG_TOOL" -o "$GRUB_CFG" || true
                fi
                if grep -qF "resume=UUID=${ROOT_UUID}" "$GRUB_CFG" 2>/dev/null && \
                   grep -qF "resume_offset=${RESUME_OFFSET}" "$GRUB_CFG" 2>/dev/null; then
                    ACTIVATION_OK=true
                    # R1: hooks must pick up resume parameters.
                    if command -v update-initramfs >/dev/null 2>&1; then
                        update-initramfs -u || true
                    fi
                    log_ok "Resume cmdline verified in ${GRUB_CFG}: resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}"
                else
                    log_warn "${GRUB_CFG} does not contain the rendered resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET} after regeneration."
                fi
            else
                log_warn "Resume activation prerequisites missing (mkconfig tool / root UUID / offset / snippet)."
            fi

            if [ "$ACTIVATION_OK" != true ]; then
                echo ""
                log_warn "HIBERNATE RESUME NOT ACTIVATED. Manual step required:"
                log_warn "Add the following to your kernel command line (GRUB cmdline), then re-run mkconfig:"
                echo "        resume=UUID=${ROOT_UUID:-<root-uuid>} resume_offset=${RESUME_OFFSET:-<filefrag-offset>}"
                echo ""
                log_err "Resume activation failed; hibernate must not be assumed functional."
                exit 1
            fi
        fi

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
            mkdir -p /etc/pipewire/pipewire.conf.d
            [ -f "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf" ] && \
                cp "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf" /etc/pipewire/pipewire.conf.d/
            [ -f "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf" ] && \
                cp "${REPO_ROOT}/patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf" /etc/pipewire/pipewire.conf.d/
            log_ok "Installed PipeWire speaker DSP and RNNoise AI mic filters."
        fi
    fi

    # 8. Deploy TLP & Color Management configuration
    if [ "$DRY_RUN" = false ]; then
        if [ -d "/etc/tlp.d" ]; then
            if [ -f "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" ]; then
                cp "${REPO_ROOT}/patches/power/etc/tlp.d/50-lenovo-d330.conf" /etc/tlp.d/
                log_ok "Deployed TLP power configuration."
            fi
        else
            log_warn "/etc/tlp.d not found (tlp not installed?); skipping TLP power configuration."
        fi
        if [ -d "/usr/share/color/icc" ]; then
            if [ -f "${REPO_ROOT}/patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc" ]; then
                cp "${REPO_ROOT}/patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc" /usr/share/color/icc/
                log_ok "Installed calibrated D330 ICC color profile."
            fi
        else
            log_warn "/usr/share/color/icc not found (colord/ICC profile dir missing?); skipping D330 ICC profile deployment."
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
    # WR-04: --uninstall is allowed for non-root rescue shells, and every removal
    # below is `|| true`. Track whether we could actually act, so the final line
    # is honest instead of claiming a restore that never happened.
    UNINSTALL_SKIPPED_NONROOT=false
    if [ "$DRY_RUN" = false ] && [ "$EUID" -ne 0 ]; then
        UNINSTALL_SKIPPED_NONROOT=true
    fi
    if [ "$DRY_RUN" = false ]; then
        # Unload module
        modprobe -r "${PKG_NAME//-/_}" >/dev/null 2>&1 || true

        # Remove DKMS
        if dkms status -m "${PKG_NAME}" -v "${PKG_VERSION}" | grep -q "${PKG_NAME}"; then
            dkms remove -m "${PKG_NAME}" -v "${PKG_VERSION}" --all || true
        fi
        rm -rf "${DEST_SRC}"

        # Clean configs (best-effort). A rescue/non-root uninstall must continue
        # past an EPERM removal and report residue honestly instead of aborting
        # on the first failure under set -e (review: non-root honesty).
        set +e
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
        # Track grub.d presence before removal (M1, review IN-05): a removed
        # snippet leaves stale bootloader cmdline until GRUB regenerates, so the
        # refresh block below re-runs mkconfig when any snippet was present.
        GRUB_D_WAS_PRESENT=false
        for _g in 50-lenovo-d330-boot.cfg 51-lenovo-d330-acpi-override.cfg \
                  52-lenovo-d330-fastboot.cfg 53-lenovo-d330-resume.cfg; do
            [ -f "/etc/default/grub.d/$_g" ] && GRUB_D_WAS_PRESENT=true
        done
        rm -f /etc/default/grub.d/50-lenovo-d330-boot.cfg
        rm -f /etc/default/grub.d/51-lenovo-d330-acpi-override.cfg
        rm -f /etc/default/grub.d/52-lenovo-d330-fastboot.cfg
        rm -f /etc/default/grub.d/53-lenovo-d330-resume.cfg
        rm -f /usr/share/initramfs-tools/hooks/lenovo-d330-plymouth
        rm -f /etc/environment.d/50-lenovo-d330-vaapi.conf
        rm -f /etc/default/earlyoom
        # Narrow removal (M11/T-35-02): delete only the installer-authored
        # drop-in and rmdir only if empty, so foreign earlyoom drop-ins survive.
        rm -f /etc/systemd/system/earlyoom.service.d/d330-override.conf
        rmdir /etc/systemd/system/earlyoom.service.d 2>/dev/null || true
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
        # IN-02: installer-owned subtree only. Remove exactly the two files we
        # copied from patches/audio/ucm2/sof-essx8336 ({sof-essx8336,HiFi}.conf)
        # and rmdir the subtree only if empty, so a foreign file placed there is
        # never deleted (previously a broad `rm -rf` on this path).
        if [ -d /usr/share/alsa/ucm2/sof-essx8336 ]; then
            rm -f /usr/share/alsa/ucm2/sof-essx8336/sof-essx8336.conf
            rm -f /usr/share/alsa/ucm2/sof-essx8336/HiFi.conf
            rmdir /usr/share/alsa/ucm2/sof-essx8336 2>/dev/null || true
        fi
        rm -f /etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf
        rm -f /etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf
        # Migration (Phase 38): also remove fragments from the legacy, inert
        # filter-chain.conf.d location if a previous install left them there.
        rm -f /etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf
        rm -f /etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf
        rm -f /etc/tlp.d/50-lenovo-d330.conf
        rm -f /usr/share/color/icc/Lenovo-D330-sRGB-D65.icc
        # N6/I34: runtime state file written by d330-hardware-state.service
        # ExecStop (manifest kind 'state'); never removed before Phase 35.
        rm -f /etc/d330-hardware-state.json
        set -e

        # M6: the tablet daemon is a global USER unit -> disable it globally.
        # Mirror the install/verify systemd-user guard for symmetry: without
        # systemctl or a running systemd (PID 1), report honestly instead of
        # running a command that cannot succeed.
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            systemctl --global disable d330-tablet-daemon.service >/dev/null 2>&1 || true
        else
            log_warn "systemd user manager unavailable (no systemctl or /run/systemd/system); tablet user unit not disabled."
        fi
        systemctl disable --now lenovo-d330-power.service >/dev/null 2>&1 || true
        systemctl disable --now lenovo-d330-camera-loopback.service >/dev/null 2>&1 || true
        systemctl disable --now d330-hardware-state.service >/dev/null 2>&1 || true
        systemctl disable --now d330-sensor-filter.service >/dev/null 2>&1 || true
        systemctl disable --now d330-auto-hibernate.service >/dev/null 2>&1 || true
        systemctl disable --now d330-thermal.service >/dev/null 2>&1 || true
        systemctl disable --now d330-swapfile.service >/dev/null 2>&1 || true
        swapoff /var/swapfile >/dev/null 2>&1 || true
        # Remove the fstab swap line only; /var/swapfile itself is left on
        # disk on purpose -- deleting a 4 GB file mid-uninstall is unnecessary
        # risk (RESEARCH section 4 recommendation).
        if grep -qxF "/var/swapfile none swap sw 0 0" /etc/fstab 2>/dev/null; then
            # Exact-match removal (review IN-01), mirroring the install-side
            # guard: only the swap line itself can match, never a comment or
            # longer line containing it. grep -v -xF exits 1 when every line
            # was the swap line; that empty result is still a valid fstab, so
            # it replaces the file instead of silently keeping the line. Any
            # other failure (rc >= 2) leaves the original file untouched.
            FSTAB_RM_RC=0
            grep -v -xF "/var/swapfile none swap sw 0 0" /etc/fstab > /etc/fstab.d330-tmp 2>/dev/null || FSTAB_RM_RC=$?
            if [ "$FSTAB_RM_RC" -le 1 ]; then
                mv /etc/fstab.d330-tmp /etc/fstab || true
            else
                rm -f /etc/fstab.d330-tmp
            fi
        fi
        # M6: remove the user unit; clean up any legacy system-unit install
        # (pre-Phase-36) without hardcoding the retired path.
        rm -f /usr/lib/systemd/user/d330-tablet-daemon.service
        find /etc/systemd/system -maxdepth 1 -name 'd330-tablet-daemon.service' -delete 2>/dev/null || true
        rm -f /etc/systemd/system/lenovo-d330-power.service
        rm -f /etc/systemd/system/lenovo-d330-camera-loopback.service
        rm -f /etc/systemd/system/d330-hardware-state.service
        # Phase 37 migration: the no-op PWM boot unit was retired (it only
        # reported success without a register write). Remove only our own stale
        # unit by exact basename -- never a wildcard that could hit a foreign
        # unit.
        find /etc/systemd/system -maxdepth 2 -name 'lenovo-d330-backlight-pwm.service' -delete 2>/dev/null || true
        rm -f /etc/systemd/system/d330-sensor-filter.service
        rm -f /etc/systemd/system/d330-auto-hibernate.service
        rm -f /etc/systemd/system/d330-thermal.service
        rm -f /etc/systemd/system/d330-swapfile.service
        systemctl daemon-reload >/dev/null 2>&1 || true
        # N6/I35: undo wait-online masking (net-new defensive cleanup, scoped to
        # the two named units only; a no-op if they were never masked).
        systemctl unmask systemd-networkd-wait-online.service >/dev/null 2>&1 || true
        systemctl unmask NetworkManager-wait-online.service >/dev/null 2>&1 || true

        # Refresh
        if command -v systemd-hwdb >/dev/null 2>&1; then
            systemd-hwdb update || true
            udevadm trigger || true
        fi
        # M1/IN-05: regenerate GRUB when any grub.d snippet was removed, using
        # the shared ladder so stale snippets/corresponding cmdline do not
        # survive uninstall. Best-effort: uninstall must not abort on mkconfig
        # failure, but a missing tool warns loudly (run_grub_regen).
        if [ "$GRUB_D_WAS_PRESENT" = true ]; then
            run_grub_regen "grub.d snippets removed" || true
        fi
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -u || true
        elif command -v dracut >/dev/null 2>&1; then
            # N6/I33: mirror install's dracut branch so a dracut-only distro
            # refreshes its initramfs after the hook/snippet removals above.
            dracut -f || true
        fi
    fi
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Uninstall steps were simulated; no changes made."
    elif [ "$UNINSTALL_SKIPPED_NONROOT" = true ]; then
        log_warn "not root - removals were skipped; re-run as root to restore baseline state."
    else
        log_ok "Uninstallation complete. System restored to baseline state."
    fi
}

# ------------------------------------------------------------------------------
# do_verify: diff the deployed tree against deploy_manifest() (M11/N6 machine
# check). Read-only: no build tools, no root. `--root DIR` checks a fixture tree
# and skips the runtime-only kinds (unit-enabled, fstab-line) that need systemd
# or the real /etc. Exits non-zero (and prints a DRIFT line per entry) on any
# mismatch so install->uninstall symmetry is machine-checked, not eyeballed.
#
# CR-01: conditionally-deployed entries (state, file-optional, exec-optional,
# grub-snippet-optional) are SKIPPED -- never DRIFT -- when absent, because
# install legitimately omits them (runtime state, or a target dir that did not
# exist). Required entries are the only ones that count as drift. unit-enabled
# additionally requires systemd to be PID 1 ([ -d /run/systemd/system ]), so a
# chroot/container/WSL reports SKIP rather than 8 false DRIFTs (WR-05).
#
# optional $2 (default false): `--removed` mode inverts the contract -- every
# manifest path must be ABSENT (present => DRIFT), proving SC1 "install then
# uninstall leaves nothing".
# ------------------------------------------------------------------------------
do_verify() {
    local root="${1:-/}"
    local removed="${2:-false}"
    local path kind full
    local total=0 drift=0
    local expect="present"
    [ "$removed" = true ] && expect="absent"

    log_info "Verifying deployed artifacts against the deploy manifest (root=${root}, expecting ${expect})..."
    while IFS=$'\t' read -r path kind; do
        [ -n "$path" ] || continue
        total=$((total + 1))

        case "$kind" in
            unit-enabled)
                if [ "$root" = "/" ] && command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
                    if [ "$(systemctl is-enabled "$path" 2>/dev/null || true)" = "enabled" ]; then
                        if [ "$removed" = true ]; then
                            echo "  [DRIFT] $path ($kind): unit still enabled"
                            drift=$((drift + 1))
                        else
                            echo "  [OK] $path ($kind)"
                        fi
                    else
                        if [ "$removed" = true ]; then
                            echo "  [OK] $path ($kind): not enabled"
                        else
                            echo "  [DRIFT] $path ($kind): unit not enabled"
                            drift=$((drift + 1))
                        fi
                    fi
                else
                    echo "  [SKIP] $path ($kind): systemctl unavailable, non-root target, or systemd not PID 1"
                fi
                continue
                ;;
            unit-user-enabled)
                # M6: global user-unit enablement lives at
                # /etc/systemd/user/<target>.wants/<unit>; check the symlink
                # directly because `systemctl is-enabled` does not accept --global.
                if [ "$root" = "/" ] && command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
                    if [ -e "/etc/systemd/user/default.target.wants/$path" ]; then
                        if [ "$removed" = true ]; then
                            echo "  [DRIFT] $path ($kind): user unit still enabled"
                            drift=$((drift + 1))
                        else
                            echo "  [OK] $path ($kind)"
                        fi
                    else
                        if [ "$removed" = true ]; then
                            echo "  [OK] $path ($kind): not enabled"
                        else
                            echo "  [DRIFT] $path ($kind): user unit not enabled"
                            drift=$((drift + 1))
                        fi
                    fi
                else
                    echo "  [SKIP] $path ($kind): systemctl unavailable, non-root target, or systemd not PID 1"
                fi
                continue
                ;;
            fstab-line)
                if [ "$root" = "/" ]; then
                    if grep -qxF "$path" /etc/fstab 2>/dev/null; then
                        if [ "$removed" = true ]; then
                            echo "  [DRIFT] fstab entry still present: $path"
                            drift=$((drift + 1))
                        else
                            echo "  [OK] fstab: $path"
                        fi
                    else
                        if [ "$removed" = true ]; then
                            echo "  [OK] fstab entry absent: $path"
                        else
                            echo "  [DRIFT] fstab entry missing: $path"
                            drift=$((drift + 1))
                        fi
                    fi
                else
                    echo "  [SKIP] fstab line ($kind): non-root target"
                fi
                continue
                ;;
        esac

        if [ "$root" = "/" ]; then
            full="$path"
        else
            full="${root%/}${path}"
        fi

        # --removed mode: presence of ANY manifest path is drift, regardless of
        # kind -- uninstall must leave nothing behind.
        if [ "$removed" = true ]; then
            if [ -e "$full" ] || [ -d "$full" ]; then
                echo "  [DRIFT] $path ($kind): still present after uninstall"
                drift=$((drift + 1))
            else
                echo "  [OK] $path ($kind): absent"
            fi
            continue
        fi

        case "$kind" in
            dir)
                if [ -d "$full" ]; then
                    echo "  [OK] $path ($kind)"
                else
                    echo "  [DRIFT] $path ($kind): missing directory"
                    drift=$((drift + 1))
                fi
                ;;
            unit-user)
                # M6: user unit file (existence; deployed to /usr/lib/systemd/user).
                if [ -f "$full" ]; then
                    echo "  [OK] $path ($kind)"
                else
                    echo "  [DRIFT] $path ($kind): missing"
                    drift=$((drift + 1))
                fi
                ;;
            exec)
                if [ -f "$full" ] && [ -x "$full" ]; then
                    echo "  [OK] $path ($kind)"
                else
                    echo "  [DRIFT] $path ($kind): missing or not executable"
                    drift=$((drift + 1))
                fi
                ;;
            state|file-optional|exec-optional|dir-optional|grub-snippet-optional)
                # CR-01: conditional/runtime artifacts must not fail a legit
                # install. Present => OK, absent => SKIP.
                if [ -e "$full" ]; then
                    echo "  [OK] $path ($kind): present"
                else
                    echo "  [SKIP] $path ($kind): conditional/runtime artifact absent"
                fi
                ;;
            *)
                if [ -f "$full" ]; then
                    echo "  [OK] $path ($kind)"
                else
                    echo "  [DRIFT] $path ($kind): missing"
                    drift=$((drift + 1))
                fi
                ;;
        esac
    done < <(deploy_manifest)

    echo ""
    if [ "$drift" -gt 0 ]; then
        log_err "verify: ${drift} DRIFT of ${total} manifest entries (root=${root}, expecting ${expect})."
        return 1
    fi
    log_ok "verify: all ${total} manifest entries ${expect} (root=${root})."
    return 0
}

ACTION="install"
DRY_RUN=false
KERNEL_SRC=""
VERIFY_ROOT="/"
VERIFY_REMOVED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) ACTION="install"; shift ;;
        --uninstall) ACTION="uninstall"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --verify) ACTION="verify"; shift ;;
        --removed) VERIFY_REMOVED=true; shift ;;
        --dump-manifest) ACTION="dump-manifest"; shift ;;
        --root)
            if [ -z "${2:-}" ] || [ "${2#--}" != "$2" ]; then
                log_err "--root requires a directory argument."
                usage
                exit 1
            fi
            VERIFY_ROOT="$2"; shift 2 ;;
        --kernel-src)
            if [ -z "${2:-}" ] || [ "${2#--}" != "$2" ]; then
                log_err "--kernel-src requires a path argument."
                usage
                exit 1
            fi
            KERNEL_SRC="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    log_warn "Operating in DRY-RUN mode. No files will be modified."
fi

# M11: only --install (and its dry-run) needs dkms/make/gcc and root. --uninstall
# must run in a minimal rescue shell (root but no build tools), and --verify /
# --dump-manifest are read-only, so all three bypass the prerequisite + EUID
# gate; --install keeps both unchanged.
case "$ACTION" in
    install)
        check_prerequisites
        ;;
    *)
        log_info "Skipping prerequisite/root checks for '$ACTION' (rescue-shell / read-only mode); check_prerequisites runs only for install."
        ;;
esac

case "$ACTION" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    verify) do_verify "$VERIFY_ROOT" "$VERIFY_REMOVED" ;;
    dump-manifest) deploy_manifest ;;
esac
