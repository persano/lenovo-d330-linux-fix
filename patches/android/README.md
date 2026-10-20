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
>
> **Crimson pre-verification (2026-10-19, Phase 57 / plan 01):** both 6.6
> patches were gate-checked against a fresh shallow fetch of the live BlissOS
> x86 tree — `android-generic/kernel_common`, branch `hm/crimson` (supersedes
> the stale BlissRoms `kernel_common` noted in ROADMAP) — fetched tip commit
> `447ff15184f6dd2e0d010f7fba9af1d886bd7443`, kernel version **6.6.129**
> (VERSION/PATCHLEVEL/SUBLEVEL from the clone's Makefile). The gate is the
> exact sequence the Phase 57 CI workflow enforces: `git apply --check` on the
> CCS patch (`d330_android_x86_6.6.patch`) first, then `git apply --check` on
> the GLK patch (`d330_android_glk_reset_fix_6.6.patch`), per locked decision 2.
>
> - `d330_android_x86_6.6.patch` (CCS): **initially FAILED** the crimson gate —
>   `error: patch fragment without header at ...:44: @@ -375,6 +380,15 @@`, then
>   (after header recount) `patch does not apply` in 4 of 5 files. Adapted
>   minimally per the record below; `git apply --check` now **passes** clean.
> - `d330_android_glk_reset_fix_6.6.patch` (GLK): `git apply --check` **passes**
>   clean against crimson, unmodified.
>
> Both patches were then applied for real in CCS-then-GLK order against the
> clone and all grep anchors landed: `lenovo_ideapad_d330_10igl_800x1280`
> (drm_panel_orientation_quirks.c), `dmi_match(DMI_PRODUCT_NAME, "82H0")` +
> `intel_fb_is_ccs_modifier` (skl_universal_plane.c), `Running INIT_OTP
> (GPIO/delay only) as DEASSERT_RESET` + `IS_GEMINILAKE` (intel_bios.c).
>
> **CCS patch adaptations, per file (crimson `hm/crimson` vs the AOSP
> `android15-6.6` basis verified 2026-10-19):**
>
> 1. *All files (structural):* the committed patch's hunk headers carried
>    wrong line counts from the hand-port — e.g. the quirks.c first hunk
>    declared `-192,6 +192,11` over a 7-context/12-line body, which made
>    `git apply --check` fail with "patch fragment without header" against
>    **any** tree. Headers recounted from the hunk bodies; no added or
>    context line was changed where the context already matched.
> 2. `drm_panel_orientation_quirks.c`: crimson uses the generic structs
>    (`lcd800x1280_rightside_up` etc.) and the `orientation_data[]` table,
>    not the named `lenovo_ideapad_d330_*` structs of the AOSP basis — and
>    it already ships an upstream "Lenovo Ideapad D330-10IGL (HD)" quirk.
>    Both hunks were re-anchored: the struct hunk after
>    `lcd800x1280_rightside_up`, the table entry after crimson's native
>    IGL entry. The re-anchored entry duplicates crimson's native behavior
>    (identical `driver_data` values; first match wins) — kept, not deleted,
>    so the patch stays whole; it is behaviorally inert on crimson.
> 3. `intel_pps.c`: AOSP's `intel_pps_init_delays()` does not exist in
>    crimson — the function is `pps_init_delays()`. The 600 ms clamp hunk
>    was re-anchored there and adapted to crimson's pre-`intel_display`
>    refactor API: `intel_has_quirk(dev_priv, ...)`,
>    `drm_info(&dev_priv->drm, ...)` (AOSP basis used `display`/
>    `display->drm`).
> 4. `intel_quirks.c`: the quirk hook was adapted from AOSP's
>    `struct intel_display *display` signature to crimson's
>    `struct drm_i915_private *i915` (`intel_set_quirk(i915, ...)`,
>    `drm_info(&i915->drm, ...)`); the DMI table entry was re-anchored to
>    the end of crimson's `intel_dmi_quirks[]` (AOSP basis anchored near
>    the `.hook = quirk_increase_t12_delay` entry, which crimson serves
>    from the PCI subdevice table instead).
> 5. `intel_quirks.h`: enum context re-anchored — crimson's enum ends
>    `QUIRK_LVDS_SSC_DISABLE, QUIRK_NO_PPS_BACKLIGHT_POWER_HOOK`, not the
>    AOSP basis's `QUIRK_NO_PCH_PWM_ENABLE, QUIRK_INCREASE_T12_DELAY`.
> 6. `skl_universal_plane.c` (the critical CCS fix): **unmodified** —
>    context matched crimson exactly; both hunks apply as generated.
>
> No hunk was deleted to pass the gate; no `--3way`/`-f` force-apply was
> used anywhere. The gate was re-run green after every adaptation.
> `index` lines still carry the AOSP-generation blob SHAs — context-based
> apply ignores them (`--3way` is forbidden by policy).

---

## 1. Provided Kernel Patches

- [`d330_android_x86_5.15.patch`](d330_android_x86_5.15.patch): Targets Android-x86 / Bliss OS 14/15 based on kernel 5.15 LTS.
- [`d330_android_x86_6.6.patch`](d330_android_x86_6.6.patch): Targets Android-x86 / Bliss OS 16+ based on kernel 6.6+ LTS.
- [`d330_android_glk_reset_fix_6.6.patch`](d330_android_glk_reset_fix_6.6.patch): **The real resume fix** for 6.6+ kernels (GLK reset-order fixup from upstream #13225, generated against AOSP `android15-6.6`; apply after the CCS patch).
- [`d330_android_glk_reset_fix_5.15.patch`](d330_android_glk_reset_fix_5.15.patch): **The real resume fix** for 5.15 kernels (same fixup against AOSP `android13-5.15`, old `i915->vbt` API).

---

## 2. CI build (Phase 57)

The workflow `.github/workflows/build-blissos-kernel.yml` builds a standalone
bootable `x86_64_defconfig` kernel from `android-generic/kernel_common`
(default branch `hm/crimson`). Dispatch it yourself — runs are checked only
when you ask (standing no-polling rule):

```bash
gh workflow run build-blissos-kernel.yml -f ref=hm/crimson
```

Any branch of `android-generic/kernel_common` can be passed as `ref`. On
success the run publishes one artifact, `blissos-kernel`, containing
`bzImage`, `System.map`, `.config`, and `SHA256SUMS`. The workflow's first
step after fetching the tree is the patch gate: `git apply --check` on both
6.6 patches in CCS-then-GLK order, with grep anchors proving the code landed
— a failed or overrun build is an honest red job with no artifact, never a
truncated one (BLIS-02/AUDIT-03, CHRM-02).

---

## 3. Bootloader (`grub.cfg`) Parameters

To prevent Gemini Lake UHD 600 pipe freeze on sleep/screen timeout:

```text
kernel /android-x86/kernel root=/dev/ram0 androidboot.selinux=permissive i915.enable_psr=0 i915.enable_fbc=0 video=efifb:nobgrt
```

---

## 4. Accelerometer & Auto-Rotation

Append [`android_hal_configs/sensor_hal.prop`](android_hal_configs/sensor_hal.prop) to `/system/build.prop`:

```properties
hal.sensors.iio.accel.matrix=0,1,0,-1,0,0,0,0,1
```
