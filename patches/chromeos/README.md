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

### Pre-verification against `chromeos-6.6` (Phase 59, 2026-10-20)

Local pre-run of the exact CI gate, on a fresh shallow clone of
`chromiumos/third_party/kernel`, branch `chromeos-6.6`, tip
`a534360e4c71f8cfc8350614f73c7f64124c9a05`, kernel `6.6.147`
(gate log: `.git/phase59-task1-gate.log`; pre-adaptation failure:
`.git/phase59-task1-gate-initial.log`). Patch order CCS first, then GLK.

- `d330_chromeos_glk_reset_fix_6.6.patch`: **`git apply --check` clean on
  first run** — no changes needed.
- `d330_chromeos_6.6.patch`: **initially failed** — the v11.0 status note
  above claimed this file applied clean, but the fetched tip proved that
  false: the patch was context-anchored to a newer, post-`intel_display`-
  refactor tree (array `drm_dmi_panel_orientation_data[]`, named
  `lenovo_ideapad_d330_*` structs, `struct intel_display *` hooks,
  `intel_pps_init_delays()`), none of which exist on `chromeos-6.6`
  (`orientation_data[]`, `drm_i915_private` hooks, `pps_init_delays()`),
  and its trailing `git format-patch` signature plus a wrong hunk line
  count made git report `corrupt patch at ...:45`. Adapted per file —
  same added behavior, tree-matching context/API, verified by a full
  re-run of `git apply --check` (both patches, exit 0) + real
  CCS-then-GLK apply + grep anchors (`lenovo_ideapad_d330_10igl_800x1280`,
  `dmi_match(DMI_PRODUCT_NAME, "82H0")`, `intel_fb_is_ccs_modifier`,
  `quirk_lenovo_d330_pps`, GLK anchors in `intel_bios.c`):

  | File | Adaptation |
  |------|-----------|
  | `drm_panel_orientation_quirks.c` | New struct + 82H0 entry re-anchored to `orientation_data[]`. The fetched tip already carries an upstream `Lenovo Ideapad D330-10IGL (HD)` entry with identical 800x1280 RIGHT_UP data; the adapted entry is kept immediately after it (identical match, unreachable but harmless) so the patch's scope and anchor are preserved. |
  | `intel_pps.c` | Clamp re-anchored into `pps_init_delays()` (the pre-rename 6.6 name) after `#undef get_delay`; `display` → `dev_priv` (`dp_to_i915`), `intel_has_quirk(dev_priv, ...)`/`drm_info(&dev_priv->drm, ...)` per this tree's API. |
  | `intel_quirks.c` | `quirk_lenovo_d330_pps()` re-anchored before `intel_dmi_quirks[]`, signature/log calls converted to `struct drm_i915_private *i915` form; DMI entry appended to the array (this tree's array ends `},\n};`). |
  | `intel_quirks.h` | `QUIRK_INCREASE_PPS_CYCLE_DELAY` appended after `QUIRK_SKIP_LINK_CHECK` (enum order differs in this tree). |
  | `skl_universal_plane.c` | Context matched as-is; only line offsets differed (handled by `git apply`). `#include <linux/dmi.h>` block re-anchored to this tree's include order. |
  | (patch file) | Removed the trailing `git format-patch` signature (`-- \n2.43.0`) and fixed the corrupt hunk line count — neither is a hunk deletion; every functional hunk remains. |

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
