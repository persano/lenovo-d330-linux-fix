#!/bin/sh
# Lenovo IdeaPad D330-10IGL Wi-Fi Sleep Resume Stabilization Hook
# Re-associates the RTL8821CE only when the link is actually wedged after
# S2idle connected standby. A healthy link (carrier up) is left untouched, so
# an active VPN / SSH / sync session is not dropped on every wake.

case "${1:-}/${2:-}" in
    post/*)
        for iface in /sys/class/net/wl*; do
            [ -d "$iface" ] || continue

            ifname="${iface##*/}"
            carrier="$(cat "$iface/carrier" 2>/dev/null || echo 0)"
            operstate="$(cat "$iface/operstate" 2>/dev/null || echo unknown)"
            echo "[d330-wifi-resume] $ifname: operstate=$operstate carrier=$carrier"

            # Carrier is up and the device is not down: nothing to do.
            if [ "$carrier" = "1" ] && [ "$operstate" != "down" ]; then
                break
            fi

            # Device present but link wedged - try a clean reconnect first,
            # falling back to a single radio bounce only if that fails.
            if command -v nmcli >/dev/null 2>&1; then
                if ! nmcli device connect "$ifname" >/dev/null 2>&1; then
                    nmcli radio wifi off >/dev/null 2>&1 || true
                    sleep 0.2
                    nmcli radio wifi on >/dev/null 2>&1 || true
                fi
            fi
            break
        done
        ;;
esac

exit 0
