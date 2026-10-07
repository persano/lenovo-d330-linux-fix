#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Emergency Screen Refresh Utility
# Recovers from any display freeze, TCON electrical latch-up, or black screen
# Can be bound to Fn hotkey or invoked from SSH / TTY

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
        xrandr --output "$OUTPUT" --off || true
        sleep 0.6
        xrandr --output "$OUTPUT" --auto --rotate right || true
        log "X11 display reset successfully."
        exit 0
    fi
fi

# 3. Direct DRM framebuffer / DPMS cycle
log "Attempting kernel DRM DPMS cycle..."
for dpms in /sys/class/drm/card*-*/dpms; do
    if [[ -f "$dpms" ]]; then
        echo "Off" > "$dpms" 2>/dev/null || true
        sleep 0.6
        echo "On" > "$dpms" 2>/dev/null || true
        log "Cycled DRM DPMS node: $dpms"
    fi
done

log "Screen refresh cycle complete."
