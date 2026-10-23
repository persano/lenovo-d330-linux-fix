# FydeOS Kernel Patches (Lenovo D330-10IGL)

The D330 display fix pair for the FydeOS (openFyde) R132 kernel line.

Target: Lenovo IdeaPad D330-10IGL (Type 82H0, Intel Gemini Lake Refresh
UHD 600, portrait 800x1280 panel).

## Which tree, and how that was decided

- Repo: `https://chromium.googlesource.com/chromiumos/third_party/kernel`
- Branch: `release-R132-16093.B-chromeos-6.6` (tip `05ed601c` at
  pre-verification time, **kernel 6.6.56**)
- Evidence: the openFyde manifest (`github.com/openFyde/manifest`,
  `chromiumos.xml`) pins exactly this branch at
  `src/third_party/kernel/v6.6` for R132-16093.B builds, and the
  `openfyde.xml` overlays are all on `r132-dev`. This is the kernel line
  openFyde amd64 builds — and FydeOS — are based on.
- Honest limit: this was verified from the open-source manifest, not from a
  downloaded FydeOS v23 image. Phase 60 (boots the real image) is where the
  image's actual `kernel` gets compared against this branch. If it differs,
  this README and the workflow `ref` input are where the correction lands.

## The two patches

1. **CCS fix — [`d330_fydeos_6.6.patch`](d330_fydeos_6.6.patch)** (this
   directory): portrait-panel orientation quirk
   (`lenovo_ideapad_d330_10igl_800x1280`), CCS-modifier blacklist in
   `skl_universal_plane.c` (kills the rotated-commit `-EINVAL` black
   screen), and the D330 PPS power-cycle-delay quirk
   (`quirk_lenovo_d330_pps` / `QUIRK_INCREASE_PPS_CYCLE_DELAY`).
   - This is a **variant of `patches/chromeos/d330_chromeos_6.6.patch`**,
     regenerated against the R132 tip. The shared patch is context-anchored
     to the newer `chromeos-6.6` tip (6.6.147) and fails here at
     `drivers/gpu/drm/i915/display/intel_quirks.h` — the newer tip has
     `QUIRK_SKIP_LINK_CHECK` in the enum that 6.6.56 does not have yet
     (initial red preserved at `.git/fydeos-gate-initial-red.log`).
   - Per-file adaptation record (2026-10-23, local gate at tip `05ed601c`):
     - `drm_panel_orientation_quirks.c` — applies (offsets -12/-54 lines)
     - `intel_pps.c` — applies as-is
     - `intel_quirks.c` — applies (offset -6 lines)
     - `intel_quirks.h` — **adapted**: enum context ends at
       `QUIRK_NO_PPS_BACKLIGHT_POWER_HOOK` on 6.6.56 (no
       `QUIRK_SKIP_LINK_CHECK`); the `QUIRK_INCREASE_PPS_CYCLE_DELAY`
       line is added there
     - `skl_universal_plane.c` — applies (one offset of 4 lines)

2. **GLK reset-order fixup —
   [`../chromeos/d330_chromeos_glk_reset_fix_6.6.patch`](../chromeos/d330_chromeos_glk_reset_fix_6.6.patch)**
   (shared with the ChromeOS build): the real S3-resume fix (runs `INIT_OTP`
   as `DEASSERT_RESET`, upstream i915 issue
   [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
   `git apply --check` passed against the R132 tree unmodified, so it is
   reused as-is — no duplicate copy kept in this directory.

## Building (CI — the supported path)

```
gh workflow run build-fydeos-kernel.yml -f ref=release-R132-16093.B-chromeos-6.6
```

Download the `fydeos-kernel` artifact from the run page: `bzImage`,
`System.map`, `.config`, `SHA256SUMS` (verify with `sha256sum -c
SHA256SUMS`; proof of the fixes: `quirk_lenovo_d330_pps` and
`lenovo_ideapad_d330_10igl_800x1280` in `System.map`). Same guardrails as
the other two kernel workflows: `git apply --check` on both patches is the
first step after fetch, red before any build, and no artifact is ever
published from a failed run.

Local pre-verification (what the CI gate enforces) was run 2026-10-23
against a fresh shallow clone of the branch: both `--check`s pass, both
patches apply (CCS first, GLK second), and all seven grep anchors land.

## Honest caveats

- The CI build configures `x86_64_defconfig` — it proves the patches build
  and boots as a generic kernel. FydeOS ships its own kernel config
  (chromeos config fragments, ARCVM/virtio bits). Whether Phase 60 swaps a
  defconfig kernel into the image or rebuilds with FydeOS's config is a
  Phase 60 decision; the patch pair itself is config-independent.
- Nothing here is device-tested yet. Phase 60 is the eyes-on verdict.
