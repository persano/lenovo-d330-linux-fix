# ChromeOS & ChromiumOS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

---

## 1. Provided Patches

- [`d330_chromeos_5.15.patch`](d330_chromeos_5.15.patch): Targets ChromeOS kernel branch `chromeos-5.15` (uses `dev_priv`/`i915` struct pointers).
- [`d330_chromeos_6.6.patch`](d330_chromeos_6.6.patch): Targets ChromeOS kernel branch `chromeos-6.6`+ (uses `intel_display` struct pointers).

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
