# Touchscreen & Active Pen Patches and Configurations

This directory contains calibration and hardware quirk files for the Goodix I2C multi-touch digitizer (`GDIX1001`) and Lenovo Active Pen on the Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`).

## Contents

- `d330_touchscreen_dmi.patch`: Kernel DMI quirk patch for `drivers/platform/x86/touchscreen_dmi.c`.
- `etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb`: libinput coordinate transformation matrix (imported fallback for the udev rule). Palm thresholds live in `patches/touchpad_pen/usr/share/libinput/60-lenovo-d330.quirks`.
- `etc/udev/rules.d/90-lenovo-d330-touchscreen.rules`: Runtime udev rules for Goodix digitizer and Active Pen.
- `etc/X11/xorg.conf.d/50-touchscreen-d330.conf`: Xorg input transformation matrix.
- `etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`: Post-wake I2C controller unbind/rebind stabilization hook.
