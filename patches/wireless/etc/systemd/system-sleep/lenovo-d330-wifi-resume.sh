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

            # Carrier 0 is ambiguous: the link can be wedged, or the user can
            # have turned the radio off. Only act when the radio is actually
            # enabled, so a user-disabled Wi-Fi is never re-enabled here.
            radio_enabled=0
            if command -v nmcli >/dev/null 2>&1; then
                case "$(nmcli -t -f WIFI radio 2>/dev/null || true)" in
                    *enabled*) radio_enabled=1 ;;
                esac
            elif command -v rfkill >/dev/null 2>&1; then
                if ! rfkill list wifi 2>/dev/null | grep -q 'blocked: yes'; then
                    radio_enabled=1
                fi
            fi
            if [ "$radio_enabled" -ne 1 ]; then
                echo "[d330-wifi-resume] $ifname: Wi-Fi radio disabled/blocked; not reconnecting."
                break
            fi

            # Healthy link: already associated, leave it untouched so an active
            # VPN / SSH / sync session is not dropped (carrier 1 + operstate up).
            if [ "$carrier" = "1" ] && [ "$operstate" = "up" ]; then
                echo "[d330-wifi-resume] $ifname: link already up; skipping reconnect."
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
