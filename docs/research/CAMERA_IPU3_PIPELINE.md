# Research: Intel IPU3 Dual Camera Pipeline on Lenovo IdeaPad D330-10IGL

## 1. Hardware Architecture & Sensors
The Lenovo IdeaPad D330-10IGL (Type 82H0, 81MD, 81H3) utilizes the Intel Gemini Lake Refresh SOC with an integrated **Intel Image Processing Unit 3 (IPU3 / CIO2)** controller (PCI `8086:31a8`).

Unlike traditional USB UVC webcams, the cameras in the D330 are raw MIPI CSI-2 image sensors wired directly to the Intel CIO2 receiver:
1. **Front Camera**: Omnivision OV2680 (2 Megapixel, 1600x1200 @ 30fps) or Himax HM2056.
2. **Rear / World Camera**: Omnivision OV5648 (5 Megapixel, 2592x1944 @ 30fps).
3. **Power Management & Clock Generator**: Intel discrete ACPI companion device `INT3472` (`intel-skl-int3472-discrete`), managing GPIO pins for reset (`RESET_B`), power-down (`PWDN_B`), and 19.2 MHz master reference clock gating.

## 2. Linux Kernel Driver Stack
- **CIO2 Controller**: Driven by `intel-ipu3-cio2`.
- **Sensor Drivers**: `ov2680` and `ov5648` V4L2 subdevice drivers.
- **Power Sequencing**: `intel-skl-int3472-discrete` handles ACPI sensor discovery and maps GPIOs to standard Linux `regulator` and `clk` subsystems.
- **V4L2 Media Controller**: Exposes `/dev/media0` containing the CIO2 receiver entities, CSI-2 virtual channels, and subdevices `/dev/v4l-subdev*`.

## 3. Userspace Software 3A (libcamera & PipeWire)
Because raw Bayer data is emitted by the CSI-2 receiver without in-sensor ISP processing, Linux utilizes `libcamera` with the `ipu3` pipeline handler and Image Processing Algorithm (IPA):
- Auto Exposure (AGC)
- Auto White Balance (AWB)
- Black Level Correction (BLC)
- Tone Mapping / Gamma Curves

### Compatibility with Standard Apps
Standard applications (Chromium, Firefox, Zoom, Cheese, Teams) expect V4L2 YUYV/MJPEG streams via `/dev/video*`. Two mechanisms are provided:
1. **PipeWire Camera Portal**: Modern Wayland desktops (GNOME, KDE) access camera streams directly via XDG Desktop Portal and PipeWire.
2. **v4l2loopback Bridge**: For legacy applications, `d330-camera-bridge.sh` and `lenovo-d330-camera-loopback.service` stream decoded YUY2 video to `/dev/video10` (Front) and `/dev/video11` (Rear).

## 4. Verification
Run `scripts/test_cameras.sh --probe` or `--dry-run` to test kernel state, device nodes, and capture capabilities.
