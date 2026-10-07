#!/bin/sh
# Lenovo IdeaPad D330 Touchscreen Sleep/Wake Stabilization Hook
# Path: /usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh
# Fixes I2C controller lockup and missed touch interrupts across S0ix/S3 resume

I2C_DRIVER_PATH="/sys/bus/i2c/drivers/goodix"
TARGET_DEV="i2c-GDIX1001:00"

case "$1/$2" in
    pre/*)
        # Pre-suspend: device entering sleep
        logger -t lenovo-d330-touch "Preparing Goodix touchscreen for suspend ($2)"
        ;;
    post/*)
        # Post-resume: recover touch controller
        logger -t lenovo-d330-touch "Recovering Goodix touchscreen after resume ($2)"
        
        # 1. Check if device is bound in sysfs
        if [ -d "$I2C_DRIVER_PATH" ]; then
            # Check for device instance
            DEV=$(find /sys/bus/i2c/devices/ -name "*GDIX1001*" -exec basename {} \; 2>/dev/null | head -n 1)
            [ -z "$DEV" ] && DEV="$TARGET_DEV"

            if [ -e "$I2C_DRIVER_PATH/$DEV" ]; then
                logger -t lenovo-d330-touch "Cycling I2C binding for $DEV"
                echo "$DEV" > "$I2C_DRIVER_PATH/unbind" 2>/dev/null || true
                sleep 0.15
                echo "$DEV" > "$I2C_DRIVER_PATH/bind" 2>/dev/null || true
                logger -t lenovo-d330-touch "Touchscreen $DEV rebound successfully"
            else
                # If not bound, try binding directly
                echo "$DEV" > "$I2C_DRIVER_PATH/bind" 2>/dev/null || true
            fi
        else
            # Module level fallback if driver directory missing
            if lsmod | grep -q "^goodix"; then
                logger -t lenovo-d330-touch "Reloading goodix kernel module"
                modprobe -r goodix 2>/dev/null || true
                sleep 0.1
                modprobe goodix 2>/dev/null || true
            fi
        fi
        ;;
esac

exit 0
