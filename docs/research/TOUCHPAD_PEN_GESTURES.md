# Research: Touchpad & Active Pen Gestures on Lenovo D330-10IGL

## 1. Dock Touchpad Characteristics
The detachable keyboard dock includes an integrated multi-touch clickpad connected via internal USB (Lenovo Vendor `17ef`).
Default generic Linux X11/Wayland settings treat this as a basic mouse:
- Tap-to-click is disabled.
- Scrolling direction is unnatural.
- Palm rejection is uncalibrated, causing cursor jumps while typing.

## 2. Active Pen Stylus Digitizer
The display includes a Goodix active electrostatic stylus digitizer supporting the Lenovo Active Pen (Wacom AES protocol / Goodix Pen):
- 2048 levels of pressure sensitivity.
- Top barrel button: secondary click (Button 3).
- Bottom barrel button: eraser (Button 2).

## 3. Configuration Profiles
1. **libinput quirks (`usr/share/libinput/60-lenovo-d330.quirks`)**: model attributes read by libinput itself, so they apply under X11 and Wayland compositors (KWin/GNOME): touchpad pressure range and palm thresholds, touchscreen palm thresholds, pen pressure range.
2. **X11 / libinput (`60-lenovo-d330-touchpad-pen.conf`)** (X11-only):
   - Enables tap-to-click with multi-finger mappings (1-finger left, 2-finger right, 3-finger middle).
   - Enables Disable-While-Typing (DWT) palm rejection.
   - Applies the 90-degree affine transformation matrix to match the rotated display.
3. **Wayland**: no matrix is needed, and one must not be added. The compositor rotates absolute input from the panel orientation reported by the DRM connector (`panel_orientation=...`), so the shipped `LIBINPUT_CALIBRATION_MATRIX` is the identity (`1 0 0 0 1 0`). Tapping, natural scrolling, clickfinger, accel and the pen pressure curve are user preferences with no libinput/udev control; set them in the compositor (KDE System Settings > Input Devices; GNOME Settings).
