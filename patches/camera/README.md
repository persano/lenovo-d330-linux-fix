# Camera Patches & Configurations for Lenovo IdeaPad D330-10IGL

Provides driver configs, udev rules, `libcamera` IPU3 IPA 3A tuning profiles, and loopback bridge service for the Intel IPU3 dual camera system.

## File Hierarchy
- `etc/modprobe.d/lenovo-d330-camera.conf`: `v4l2loopback` parameters for the camera bridge; `intel-ipu3-cio2`, `ov2680` and `ov5648` autoload with none.
- `etc/udev/rules.d/92-lenovo-d330-camera.rules`: Device permissions and power management for `/dev/media*` and `/dev/v4l-subdev*`.
- `libcamera/ipa/ipu3/ov2680.yaml`: Software 3A tuning parameters for OV2680 front camera.
- `libcamera/ipa/ipu3/ov5648.yaml`: Software 3A tuning parameters for OV5648 rear camera.
- `etc/systemd/system/lenovo-d330-camera-loopback.service`: Systemd service to spawn `d330-camera-bridge.sh`.
