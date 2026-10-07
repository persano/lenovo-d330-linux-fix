# Touchpad & Active Pen Patches for Lenovo IdeaPad D330-10IGL

Provides libinput hwdb property overrides, X11 gestures configurations, and stylus diagnostics.

## File Hierarchy
- `etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb`: Pressure and palm rejection hardware database.
- `etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf`: X11 tapping, natural scrolling, and stylus matrix.
- `tools/d330-pen-config.sh`: Pen and touchpad diagnostic script.
