# Lenovo IdeaPad D330: Touchscreen & Active Pen Calibration Guide

## 1. Hardware Architecture & Problem Analysis

The Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`) utilize an integrated Goodix I2C multi-touch digitizer (`GDIX1001` ACPI device) paired with an active capacitive stylus sensor supporting the **Lenovo Active Pen** (4096 pressure levels).

### Key Technical Issues
1. **Coordinate Mismatch on Native Portrait Panel**:
   - The physical display panel is natively portrait ($800 \times 1280$ or $1200 \times 1920$).
   - When rotated $90^\circ$ clockwise by the DRM subsystem / compositor (`eDP-1` landscape mode), uncalibrated touch coordinates remain mapped to raw portrait axes. Touching the top-right results in cursor movement to the bottom-right or inverted coordinates.
2. **I2C Sleep/Resume Desynchronization**:
   - Following system wake from S0ix / S3 standby, the Goodix controller hardware state machine frequently desynchronizes or stops asserting `INT3452` interrupts due to missing power-on reset sequencing.
   - The controller remains loaded in kernel sysfs (`i2c-GDIX1001:00`), but ignores touch contact.
3. **Palm Rejection Sensitivity**:
   - Without active palm suppression thresholds, resting a hand while using the Lenovo Active Pen causes erratic multi-touch events, pinching, or missed pen strokes.

---

## 2. Coordinate Transformation

Libinput and X11 both use an affine transformation matrix:
$$\begin{pmatrix} x' \\ y' \\ 1 \end{pmatrix} = \begin{pmatrix} c_0 & c_1 & c_2 \\ c_3 & c_4 & c_5 \\ 0 & 0 & 1 \end{pmatrix} \begin{pmatrix} x \\ y \\ 1 \end{pmatrix}$$

The panel is natively portrait and its rotation is reported to userspace by the
DRM connector (`video=DSI-1:panel_orientation=right_side_up`).

- **Wayland (KWin, Mutter):** the compositor folds the panel orientation into the
  output transform and rotates absolute input devices to match, so the
  touchscreen must NOT carry its own rotation matrix. The shipped
  `LIBINPUT_CALIBRATION_MATRIX` is therefore the identity `1 0 0 0 1 0`. A
  $90^\circ$ matrix here rotates touch a second time, i.e. $90^\circ + 90^\circ =
  180^\circ$ (inverted touch).
- **X11:** the X server does not apply the panel orientation to input, so
  `patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf` carries the
  $90^\circ$ transform `0 1 0 -1 0 1 0 0 1` ($x' = y$, $y' = 1 - x$).

---

## 3. Quirk & Driver Fixes Provided

1. **Kernel DMI Quirk Patch** (`patches/touchscreen/d330_touchscreen_dmi.patch`):
   - Adds DMI matching entries to `drivers/platform/x86/touchscreen_dmi.c` for Machine Types `82H0`, `81MD`, and `81H3`.
   - Populates device properties `touchscreen-swapped-x-y`, `touchscreen-inverted-y`, and `touchscreen-stylus-supported`.
   - **Do not apply this on a Wayland compositor that already rotates input from `panel_orientation`** (KWin, Mutter): the kernel transform and the compositor transform stack, giving the same inverted-touch bug as a duplicate `LIBINPUT_CALIBRATION_MATRIX`. It is not installed by `scripts/install_dkms.sh`.
2. **Udev Rules & HWDB** (`patches/touchscreen/etc/udev/`):
   - `62-lenovo-d330-touchscreen.hwdb` and `90-lenovo-d330-touchscreen.rules` apply an **identity** `LIBINPUT_CALIBRATION_MATRIX` (`1 0 0 0 1 0`) on Wayland, deliberately neutral so it does not stack with the compositor's panel-orientation rotation.
3. **X11 InputClass Configuration** (`patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf`):
   - Applies the $90^\circ$ affine transformation matrix for Xorg sessions and sets a standard stylus pressure curve.
4. **Sleep/Wake Stabilization Hook** (`patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`):
   - Performs sysfs unbind and rebind cycle on `/sys/bus/i2c/drivers/goodix/` upon system resume, resetting the controller hardware registers and restoring touch and pen events seamlessly.

---

## 4. Verification

Run the test harness:
```bash
bash scripts/test_touch_calibration.sh --dry-run
sudo bash scripts/test_touch_calibration.sh --test-unbind
```
