#!/usr/bin/env bash
# ==============================================================================
# scripts/d330-display-reload.sh
#
# Last-resort display recovery for the Lenovo IdeaPad D330-10IGL (82H0).
#
# After S3 resume the GLK DSI panel stays black even though the host DSI, panel
# power, PLL and CDCLK registers are byte-identical to a working state (see
# docs/research/DISPLAY_RESUME_CCS_MODIFIER.md). A full i915 re-init -- PCI
# unbind + bind of 0000:00:02.0 -- reliably brings the panel back, because the
# driver probe path re-runs the complete panel power/reset/DCS init that the
# resume path does not. This is a dirty workaround, kept as a fallback for when
# the proper resume-path fix is not available.
#
# Note: the unbind can log a one-off oops in drm_framebuffer_cleanup (fbcon had
# framebuffers pinned); it is non-fatal and the rebind re-initialises the DRM
# device. A reboot always recovers if the rebind ever fails.
#
# Usage: sudo scripts/d330-display-reload.sh
# ==============================================================================

set -euo pipefail

DEV="0000:00:02.0"
DRV="/sys/bus/pci/drivers/i915"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] must run as root (PCI unbind/bind)" >&2
    exit 1
fi
if [ ! -e "${DRV}/${DEV}" ]; then
    echo "[!] ${DEV} is not bound to i915; nothing to reload." >&2
    exit 1
fi

echo "[*] Unbinding ${DEV} from i915 (panel will blank)"
echo "${DEV}" > "${DRV}/unbind"
sleep 2

echo "[*] Rebinding ${DEV} to i915 (full panel re-init)"
echo "${DEV}" > "${DRV}/bind"
sleep 3

if [ -e "${DRV}/${DEV}" ]; then
    echo "[*] Done. The panel should be back; if not, reboot."
else
    echo "[!] Rebind did not complete; reboot to recover." >&2
    exit 1
fi
