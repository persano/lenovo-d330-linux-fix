# ChromeOS & ChromiumOS Integration Guide: Lenovo IdeaPad D330-10IGL

Target: Lenovo IdeaPad D330-10IGL (Type 82H0 / Intel Gemini Lake Refresh UHD 600)

> **Status note (2026-10-19, v11.0):** these patches predate the real
> resume fix. They carry the CCS rotation quirk (fixes rotated-commit
> `-EINVAL` black screen) plus the PPS hedge, but **NOT** the GLK
> reset-order fixup that actually restores the panel after S3 resume
> (empty VBT `MIPI_SEQ_DEASSERT_RESET`, reset pulse running after DSI
> host up — upstream issue
> [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
> On ChromeOS you will likely still see the lit-but-blank resume with
> only these patches. To port: take
> `patches/upstream/0001-drm-i915-bios-Fix-reset-sequence-order-on-GLK-VBTs-w.patch`,
> adapt the GLK dispatch predicate to your branch's `i915` display struct
> (on 6.6+: `display->platform.geminilake`; on 5.15: the `i915` pointer
> version from the upstream note), and stack it after the CCS hunk.
> Untested on real ChromeOS hardware — treat as a porting recipe, not a
> verified artifact.

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
