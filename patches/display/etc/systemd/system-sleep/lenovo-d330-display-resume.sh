#!/bin/sh
# Lenovo IdeaPad D330-10IGL display resume recovery hook
# Path: /usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh
#
# After S3 resume the Gemini Lake DSI panel stays black even though the host
# DSI link, panel power, PLL and CDCLK registers are byte-identical to a working
# state (see docs/research/DISPLAY_RESUME_CCS_MODIFIER.md). The only thing that
# brings the panel back is a full i915 re-init: a PCI unbind + bind of the GPU,
# which re-runs the panel power/reset/DCS init that the resume path does not.
#
# The reload runs SYNCHRONOUSLY in the post phase, before the systemd-suspend
# transaction completes, and is bounded by `timeout` so a stuck rebind cannot
# hang the resume.
#
# A running Wayland compositor cannot survive the GPU teardown (its DRM fd dies
# with the device; KWin does not re-open it), so the hook then restarts the
# display manager to bring up a fresh session on the re-initialised GPU. That
# means the desktop session is lost on resume -- you log back in. Recovering the
# panel without a reboot is the point; there is no way to keep the live session.
#
# It is a dirty workaround: the unbind logs a one-off, non-fatal
# drm_framebuffer_cleanup oops and the DRM card node changes. The real fix is the
# kernel patch patches/d330_display_resume_fix.patch; this hook is the fallback
# until a resume-path fix lands.
#
# Enabled by default. To disable, either remove this file, or create
# /etc/default/lenovo-d330-display-resume containing:
#     D330_DISPLAY_RESUME=0
# (the hook logs this on every resume).

DRV=/sys/bus/pci/drivers/i915
DISABLE_FILE=/etc/default/lenovo-d330-display-resume

reload_i915() {
    for d in "$DRV"/[0-9a-f]*; do
        [ -L "$d" ] || continue   # PCI device symlinks only (skip bind/unbind/...)
        bdf="${d##*/}"
        logger -t d330-display "reloading i915 device $bdf after resume"
        printf '%s\n' "$bdf" > "$DRV/unbind" 2>/dev/null || true
        sleep 2
        printf '%s\n' "$bdf" > "$DRV/bind" 2>/dev/null || true
    done
}

case "${1:-}/${2:-}" in
    post/*)
        # Only the D330-10IGL (82H0).
        [ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = "82H0" ] || exit 0
        [ -d "$DRV" ] || exit 0
        if [ -r "$DISABLE_FILE" ]; then
            # shellcheck disable=SC1090
            . "$DISABLE_FILE"
        fi
        if [ "${D330_DISPLAY_RESUME:-1}" = "0" ]; then
            logger -t d330-display "resume reload disabled (D330_DISPLAY_RESUME=0 in $DISABLE_FILE)"
            exit 0
        fi
        logger -t d330-display "resume: reloading i915 and restarting the display manager; disable with 'echo D330_DISPLAY_RESUME=0 > $DISABLE_FILE' or 'rm $0'"
        # Synchronous and bounded: the reload must finish before the compositor
        # resumes, but must never hang the resume if the rebind wedges.
        if command -v timeout >/dev/null 2>&1; then
            timeout 30 "$0" _run || logger -t d330-display "i915 reload/restart timed out or failed (rc=$?)"
        else
            "$0" _run
        fi
        ;;
    _run/*)
        reload_i915
        # Bring up a fresh session on the re-initialised GPU (the live one cannot
        # survive the teardown above).
        sleep 2
        logger -t d330-display "restarting display manager"
        systemctl restart display-manager.service 2>/dev/null || \
            systemctl restart sddm.service 2>/dev/null || \
            logger -t d330-display "display manager restart failed"
        ;;
esac

exit 0
