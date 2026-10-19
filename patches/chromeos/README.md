# ChromeOS & ChromiumOS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

> **Status note (2026-10-19, v11.0):** the CCS patches below predate the
> real resume fix — they fix rotated-commit `-EINVAL` black screen but NOT
> the S3 resume panel death (empty VBT `MIPI_SEQ_DEASSERT_RESET`, reset
> pulse running after DSI host up — upstream issue
> [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
> **Apply the GLK reset-order fix on top:**
> - [`d330_chromeos_glk_reset_fix_6.6.patch`](d330_chromeos_glk_reset_fix_6.6.patch)
> - [`d330_chromeos_glk_reset_fix_5.15.patch`](d330_chromeos_glk_reset_fix_5.15.patch)
>
> Both were generated against the real `chromeos-6.6` / `chromeos-5.15`
> upstream tree sources (fetched from chromium.googlesource.com,
> 2026-10-19) and verified with `git apply --check` — they apply clean.
> `IS_GEMINILAKE(i915)` is used directly since these trees predate the
> `intel_display` refactor. Source-verified only: **not built or
> device-tested on ChromeOS hardware** — the code path is identical to the
> one validated 10/10 on Linux 7.0.14, but a ChromeOS kernel build + boot
> test on the D330 is still the user's to run.

---

## 1. Provided Patches

- [`d330_chromeos_5.15.patch`](d330_chromeos_5.15.patch): Targets ChromeOS kernel branch `chromeos-5.15` (uses `dev_priv`/`i915` struct pointers).
- [`d330_chromeos_6.6.patch`](d330_chromeos_6.6.patch): Targets ChromeOS kernel branch `chromeos-6.6`+ (uses `intel_display` struct pointers).
- [`d330_chromeos_glk_reset_fix_6.6.patch`](d330_chromeos_glk_reset_fix_6.6.patch): **The real resume fix** for `chromeos-6.6`+ (GLK reset-order fixup from upstream #13225; apply after the CCS patch).
- [`d330_chromeos_glk_reset_fix_5.15.patch`](d330_chromeos_glk_reset_fix_5.15.patch): **The real resume fix** for `chromeos-5.15` (same fixup, adapted to the 5.15 i915 API).

---

## 2. ChromeOS Flex / Brunch Deployment (Without Kernel Recompile)

If running ChromeOS Flex or Brunch Framework on the D330 tablet:

1. Mount the EFI system partition (`ESP`):
   ```bash
   sudo mkdir -p /tmp/esp
   sudo mount /dev/mmcblk0p12 /tmp/esp   # Or target EFI boot partition
   ```
2. Edit GRUB configuration (`grub.cfg`):
   Append parameters to the `linux` command line:
   ```text
   i915.enable_psr=0 i915.enable_fbc=0 fbcon=nodefer video=efifb:nobgrt
   ```
3. Save and reboot.

---

## 3. Custom ChromiumOS / ChromeOS Kernel Build

When building ChromiumOS kernel image:

```bash
cd ~/chromiumos/src/third_party/kernel/v5.15
# Or v6.6
git apply /path/to/lenovo-d330-linux-screen-fix/patches/chromeos/d330_chromeos_5.15.patch
emerge-$BOARD chromeos-kernel-5_15
```
