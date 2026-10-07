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

## 2. Coordinate Transformation Mathematics

Libinput and X11 use an affine transformation matrix:
$$\begin{pmatrix} x' \\ y' \\ 1 \end{pmatrix} = \begin{pmatrix} c_0 & c_1 & c_2 \\ c_3 & c_4 & c_5 \\ 0 & 0 & 1 \end{pmatrix} \begin{pmatrix} x \\ y \\ 1 \end{pmatrix}$$

For a $90^\circ$ clockwise rotation from physical portrait to logical landscape:
- $x' = 0 \cdot x + 1 \cdot y + 0$
- $y' = -1 \cdot x + 0 \cdot y + 1$

Therefore:
$$\text{LIBINPUT\_CALIBRATION\_MATRIX} = \text{"0 1 0 -1 0 1"}$$

And for X11 `TransformationMatrix`:
$$\text{"0 1 0 -1 0 1 0 0 1"}$$

---

## 3. Quirk & Driver Fixes Provided

1. **Kernel DMI Quirk Patch** (`patches/touchscreen/d330_touchscreen_dmi.patch`):
   - Adds DMI matching entries to `drivers/platform/x86/touchscreen_dmi.c` for Machine Types `82H0`, `81MD`, and `81H3`.
   - Populates device properties `touchscreen-swapped-x-y`, `touchscreen-inverted-y`, and `touchscreen-stylus-supported`.
2. **Udev Rules & HWDB** (`patches/touchscreen/etc/udev/`):
   - `62-lenovo-d330-touchscreen.hwdb`: Direct hardware database matching by DMI.
   - `90-lenovo-d330-touchscreen.rules`: Fallback runtime rule applying `LIBINPUT_CALIBRATION_MATRIX` and palm rejection properties (`LIBINPUT_ATTR_PALM_PRESSURE_THRESHOLD=120`, `LIBINPUT_ATTR_PALM_SIZE_THRESHOLD=12`).
3. **X11 InputClass Configuration** (`patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf`):
   - Applies matching affine transformation matrix for Xorg server sessions and sets standard stylus pressure curve.
4. **Sleep/Wake Stabilization Hook** (`patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`):
   - Performs sysfs unbind and rebind cycle on `/sys/bus/i2c/drivers/goodix/` upon system resume, resetting the controller hardware registers and restoring touch and pen events seamlessly.

---

## 4. Verification

Run the test harness:
```bash
bash scripts/test_touch_calibration.sh --dry-run
sudo bash scripts/test_touch_calibration.sh --test-unbind
```
