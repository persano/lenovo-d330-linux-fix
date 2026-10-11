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
# On resume this hook schedules that re-init a few seconds later as a transient
# systemd unit, so it (a) runs after the resume has settled and (b) is not killed
# when the sleep transaction's cgroup is torn down. It is a dirty workaround:
# the unbind can log a one-off, non-fatal drm_framebuffer_cleanup oops, and the
# panel blanks for a few seconds while i915 reprobes. The real fix is the kernel
# patch patches/d330_display_resume_fix.patch; this hook is the fallback until a
# resume-path fix lands. Remove this file to disable it.

DRV=/sys/bus/pci/drivers/i915

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
        logger -t d330-display "resume: scheduling i915 reload in 10s"
        # Run detached in its own transient unit so it survives the sleep
        # transaction teardown; --on-active delays it until resume has settled.
        if command -v systemd-run >/dev/null 2>&1; then
            systemd-run --collect --quiet \
                --unit=d330-display-reload \
                --description="D330 DSI resume recovery" \
                --on-active=10 \
                "$0" _run >/dev/null 2>&1 || \
                logger -t d330-display "systemd-run failed; reload not scheduled"
        fi
        ;;
    _run/*)
        reload_i915
        ;;
esac

exit 0
