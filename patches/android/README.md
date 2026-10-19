# Android-x86 & Bliss OS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

> **Status note (2026-10-19, v11.0):** the CCS patches below predate the
> real resume fix — they fix orientation + rotated-commit black screen but
> NOT the S3 resume panel death (empty VBT `MIPI_SEQ_DEASSERT_RESET`,
> reset pulse running after DSI host up — upstream issue
> [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
> **Apply the GLK reset-order fix on top:**
> - [`d330_android_glk_reset_fix_6.6.patch`](d330_android_glk_reset_fix_6.6.patch)
> - [`d330_android_glk_reset_fix_5.15.patch`](d330_android_glk_reset_fix_5.15.patch)
>
> Generated against the real AOSP common-kernel sources
> (`android15-6.6` / `android13-5.15`, fetched from android.googlesource.com,
> 2026-10-19), verified with `git apply --check` — they apply clean. The
> 5.15 variant uses the old `i915->vbt.dsi` API; the 6.6 variant uses
> `panel->vbt.dsi` with `IS_GEMINILAKE(i915)` (both trees predate the
> `intel_display` refactor). Source-verified only: **not built or
> device-tested on Android-on-D330 hardware.** Note most Android-x86/Bliss
> builds use s2idle/Deepsleep rather than classic S3, so resume exposure
> differs per device config.

---

## 1. Provided Kernel Patches

- [`d330_android_x86_5.15.patch`](d330_android_x86_5.15.patch): Targets Android-x86 / Bliss OS 14/15 based on kernel 5.15 LTS.
- [`d330_android_x86_6.6.patch`](d330_android_x86_6.6.patch): Targets Android-x86 / Bliss OS 16+ based on kernel 6.6+ LTS.
- [`d330_android_glk_reset_fix_6.6.patch`](d330_android_glk_reset_fix_6.6.patch): **The real resume fix** for 6.6+ kernels (GLK reset-order fixup from upstream #13225, generated against AOSP `android15-6.6`; apply after the CCS patch).
- [`d330_android_glk_reset_fix_5.15.patch`](d330_android_glk_reset_fix_5.15.patch): **The real resume fix** for 5.15 kernels (same fixup against AOSP `android13-5.15`, old `i915->vbt` API).

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
