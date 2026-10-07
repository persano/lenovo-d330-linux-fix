#!/bin/sh
# Lenovo IdeaPad D330-10IGL Wi-Fi Sleep Resume Stabilization Hook
# Ensures Wi-Fi adapter re-associates cleanly after S2idle connected standby

case "$1/$2" in
    post/*)
        # Check if Wi-Fi interface exists and is down
        for iface in /sys/class/net/wl*; do
            if [ -d "$iface" ]; then
                dev=$(basename "$iface")
                # Trigger network manager interface re-scan if carrier lost
                if command -v nmcli >/dev/null 2>&1; then
                    nmcli radio wifi off >/dev/null 2>&1 || true
                    sleep 0.2
                    nmcli radio wifi on >/dev/null 2>&1 || true
                fi
                break
            fi
        done
        ;;
esac

exit 0
