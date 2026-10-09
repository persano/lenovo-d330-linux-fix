# Touchpad & Active Pen Patches for Lenovo IdeaPad D330-10IGL

Provides libinput model quirks (X11 and Wayland), X11 gestures configuration, and stylus diagnostics.

## File Hierarchy
- `usr/share/libinput/60-lenovo-d330.quirks`: libinput model attributes (touchpad pressure/palm, touchscreen palm, pen pressure range). Read by libinput itself, so it applies under Wayland compositors as well as X11.
- `etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf`: X11-only tapping, natural scrolling, DWT, clickfinger and the pen pressure curve. On Wayland these are compositor settings (KDE/GNOME), not libinput knobs.
- `tools/d330-pen-config.sh`: Pen and touchpad diagnostic script.

## Wayland notes
- Calibration matrices are udev properties (`LIBINPUT_CALIBRATION_MATRIX`). On Wayland the compositor already rotates absolute input from the panel orientation, so the shipped touchscreen matrix is the identity; only X11 needs a rotation (`50-touchscreen-d330.conf`).
- Tapping, natural scrolling, clickfinger, accel and the pen pressure CURVE have no libinput/udev equivalent; set them in the compositor on Wayland.
