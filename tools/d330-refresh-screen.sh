#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Emergency Screen Refresh Utility
# Recovers from a display freeze, TCON electrical latch-up, or black screen.
# Can be bound to a keyboard shortcut or invoked from SSH / TTY.
#
# Session coverage: KDE/KWin Wayland (kscreen-doctor), wlroots Wayland
# (wlr-randr), and X11 (xrandr). The community X11-only workaround this is
# based on (lucasgabmoreno/linuxmint_lenovod330) does nothing on Wayland.
#
# Usage: d330-refresh-screen [--hold]
#   --hold  wait for Enter before exiting (keeps a launcher terminal open)

set -euo pipefail

HOLD=false
case "${1:-}" in
    --hold) HOLD=true ;;
    -h|--help)
        echo "Usage: $(basename "$0") [--hold]"
        echo "  --hold  wait for Enter before exiting (for launcher terminals)"
        exit 0 ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/d330-refresh-screen.log"

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] [d330-refresh-screen] $*"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

hold() {
    if [ "$HOLD" = true ]; then
        printf '\nLog: %s\nPress Enter to close...' "$LOG_FILE"
        read -r _ || true
    fi
}

log "Executing emergency display refresh cycle..."

# 1. KDE / KWin Wayland recovery via kscreen-doctor. KWin does not expose its
#    outputs to wlr-randr (that tool is wlroots-only), so this is the path that
#    works on a stock Kubuntu Wayland session.
if command -v kscreen-doctor >/dev/null 2>&1 && [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]; then
    OUTPUT="$(kscreen-doctor -o 2>/dev/null | awk '/^Output:/{print $3; exit}')"
    OUTPUT="${OUTPUT:-eDP-1}"
    log "Cycling KDE output '${OUTPUT}' via kscreen-doctor..."
    kscreen-doctor "output.${OUTPUT}.disable" || true
    sleep 0.6
    kscreen-doctor "output.${OUTPUT}.enable" || true
    log "KDE Wayland display reset done."
    hold
    exit 0
fi

# 2. wlroots Wayland (Sway/Hyprland) recovery via wlr-randr.
if command -v wlr-randr >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    log "Cycling Wayland outputs via wlr-randr..."
    OUTPUT=$(wlr-randr | grep -E '^[A-Za-z0-9-]+' | head -n 1 | awk '{print $1}')
    if [[ -n "$OUTPUT" ]]; then
        wlr-randr --output "$OUTPUT" --off || true
        sleep 0.6
        wlr-randr --output "$OUTPUT" --on || true
        log "Wayland display reset successfully."
        hold
        exit 0
    fi
fi

# 3. X11 recovery via xrandr.
if command -v xrandr >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    log "Cycling X11 outputs via xrandr..."
    OUTPUT=$(xrandr --current | grep " connected" | awk '{print $1}' | head -n 1 || true)
    if [[ -n "$OUTPUT" ]]; then
        # Reuse the current rotation instead of forcing one: forcing
        # `--rotate right` on an already-rotated output would double it.
        CUR_ROT=$(xrandr --current | awk -v out="$OUTPUT" \
            '$1==out { for (i=2; i<=NF; i++) { r=$i; gsub(/[()]/,"",r); if (r ~ /^(normal|left|right|inverted)$/) { print r; exit } } }' || true)
        CUR_ROT="${CUR_ROT:-normal}"
        xrandr --output "$OUTPUT" --off || true
        sleep 0.6
        xrandr --output "$OUTPUT" --auto --rotate "$CUR_ROT" || true
        log "X11 display reset successfully (rotation preserved: $CUR_ROT)."
        hold
        exit 0
    fi
fi

# 4. No kernel-DRM fallback that only pretends to work.
# Writing /sys/class/drm/*/dpms is rejected on modern i915: the node is
# read-only (DEVICE_ATTR_RO(dpms) since <=5.15), so a write fails instead of
# driving a connector modeset, and the old Off/On cycle reported success while
# changing nothing. If none of the tools above actually ran there is no safe
# userspace modeset to force from here, so exit non-zero rather than claiming a
# refresh that never happened.
log "No usable display server detected; skipping the no-op kernel DPMS cycle."
log "Re-run from a graphical session with kscreen-doctor/wlr-randr/xrandr, or switch VT."
hold
exit 1
