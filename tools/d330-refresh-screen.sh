#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Emergency Screen Refresh Utility
# Recovers from a display freeze, TCON electrical latch-up, or black screen.
# Can be bound to an Fn hotkey or invoked from SSH / TTY.

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-refresh-screen] $*"
}

log "Executing emergency display refresh cycle..."

# 1. Wayland / Sway / Hyprland recovery via wlr-randr
if command -v wlr-randr >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    log "Cycling Wayland outputs via wlr-randr..."
    OUTPUT=$(wlr-randr | grep -E '^[A-Za-z0-9-]+' | head -n 1 | awk '{print $1}')
    if [[ -n "$OUTPUT" ]]; then
        wlr-randr --output "$OUTPUT" --off || true
        sleep 0.6
        wlr-randr --output "$OUTPUT" --on || true
        log "Wayland display reset successfully."
        exit 0
    fi
fi

# 2. X11 recovery via xrandr
if command -v xrandr >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    log "Cycling X11 outputs via xrandr..."
    OUTPUT=$(xrandr --current | grep " connected" | awk '{print $1}' | head -n 1)
    if [[ -n "$OUTPUT" ]]; then
        # Reuse the current rotation instead of forcing one: forcing
        # `--rotate right` on an already-rotated output would double it.
        CUR_ROT=$(xrandr --current | awk -v out="$OUTPUT" \
            '$1==out { for (i=2; i<=NF; i++) if ($i ~ /^(normal|left|right|inverted)$/) { print $i; exit } }')
        CUR_ROT="${CUR_ROT:-normal}"
        xrandr --output "$OUTPUT" --off || true
        sleep 0.6
        xrandr --output "$OUTPUT" --auto --rotate "$CUR_ROT" || true
        log "X11 display reset successfully (rotation preserved: $CUR_ROT)."
        exit 0
    fi
fi

# 3. No kernel-DRM fallback that only pretends to work.
# Writing /sys/class/drm/*/dpms is a no-op on modern i915: the node is
# writable but does not drive a connector modeset, so the old Off/On cycle
# reported success while changing nothing. If neither wlr-randr nor xrandr was
# available there is no safe userspace modeset to force from here.
log "No usable display server detected; skipping the no-op kernel DPMS cycle."
log "Re-run from a graphical session with wlr-randr or xrandr, or switch VT."

log "Screen refresh cycle complete."
