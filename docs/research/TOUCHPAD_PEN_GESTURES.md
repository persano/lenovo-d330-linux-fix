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
1. **hwdb (`63-lenovo-d330-touchpad-pen.hwdb`)**: Sets physical dimensions and pressure ranges.
2. **X11 / libinput (`60-lenovo-d330-touchpad-pen.conf`)**:
   - Enables tap-to-click with multi-finger mappings (1-finger left, 2-finger right, 3-finger middle).
   - Enables Disable-While-Typing (DWT) palm rejection.
   - Applies the 90-degree affine transformation matrix to match the rotated display.
