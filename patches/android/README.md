# Android-x86 & Bliss OS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

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
