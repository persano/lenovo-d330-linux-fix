# Android-x86 & Bliss OS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

> **Status note (2026-10-19, v11.0):** these patches predate the real
> resume fix. They carry the CCS rotation quirk + orientation/PPS pieces,
> but **NOT** the GLK reset-order fixup that actually restores the panel
> after S3 resume (empty VBT `MIPI_SEQ_DEASSERT_RESET`, reset pulse
> running after DSI host up — upstream issue
> [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
> Note that most Android-x86/Bliss builds use s2idle/Deepsleep rather
> than classic S3, so exposure differs per device config. To port: take
> `patches/upstream/0001-drm-i915-bios-Fix-reset-sequence-order-on-GLK-VBTs-w.patch`
> and adapt the GLK dispatch predicate to your branch's i915 display
> struct (6.6+: `display->platform.geminilake`). Untested on real
> Android-on-D330 hardware — porting recipe, not a verified artifact.

---

## 1. Provided Kernel Patches

- [`d330_android_x86_5.15.patch`](d330_android_x86_5.15.patch): Targets Android-x86 / Bliss OS 14/15 based on kernel 5.15 LTS.
- [`d330_android_x86_6.6.patch`](d330_android_x86_6.6.patch): Targets Android-x86 / Bliss OS 16+ based on kernel 6.6+ LTS.

---

## 2. Bootloader (`grub.cfg`) Parameters

To prevent Gemini Lake UHD 600 pipe freeze on sleep/screen timeout:

```text
kernel /android-x86/kernel root=/dev/ram0 androidboot.selinux=permissive i915.enable_psr=0 i915.enable_fbc=0 video=efifb:nobgrt
```

---

## 3. Accelerometer & Auto-Rotation

Append [`android_hal_configs/sensor_hal.prop`](android_hal_configs/sensor_hal.prop) to `/system/build.prop`:

```properties
hal.sensors.iio.accel.matrix=0,1,0,-1,0,0,0,0,1
```
