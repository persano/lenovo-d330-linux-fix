# FydeOS Kernel Patches (Lenovo D330-10IGL)

The D330 display fix pair for the FydeOS kernel line.

Target: Lenovo IdeaPad D330-10IGL (Type 82H0, Intel Gemini Lake Refresh
UHD 600, portrait 800x1280 panel).

## Which tree, and how that was decided

- Repo: `https://chromium.googlesource.com/chromiumos/third_party/kernel`
- Branch: `release-R150-16700.B-chromeos-6.12` (tip `b4e10020ba49` at
  pre-verification time, **kernel 6.12.54**)
- Evidence — read from the shipped image itself, not from a manifest:
  - FydeOS for PC slim v23.0-SP1 (`amd64-fydeos_slim`, released 2026-09-10).
    Official metadata from `https://release-api.fydeos.io/api/downloads?l=en`
    reports `Chromium OS release-R150-16700.B` for this board.
  - Image `FydeOS_for_PC_slim_v23.0-SP1-io.bin.zip`, SHA-256
    `4679828fcc5300c2006a988076e8846ad5c77d7a7a45eb3c8bfcdc478f1cb2c8`
    (matches the official checksum), 7,314,946,560 bytes extracted.
  - KERN-A partition → `vbutil_kernel --get-vmlinuz` → CRLF-safe
    `scripts/extract-vmlinux` → banner
    `Linux version 6.12.54-fyde-01180-gb4e10020ba49-dirty`, and
    `b4e10020` is exactly this branch's tip.
- Superseded choices, kept honest:
  - The original R132-6.6 branch came from the openFyde manifest pin
    (`openFyde/manifest:chromiumos.xml`, path `src/third_party/kernel/v6.6`).
    The manifest was stale relative to the shipped image. Its patch
    (`d330_fydeos_6.6.patch`, now deleted) and its dispatch (run
    `40014541648`) never passed an image-derived gate — that run builds a
    wrong-branch kernel and its artifact must not be used.
  - A pre-gate against `release-R150-16700.B-chromeos-6.6` was also wrong:
    this image ships 6.12, not 6.6.
- Honest limit: the shipped banner ends in `-dirty`, i.e. FydeOS built the
  kernel with uncommitted local modifications that are unknowable offline.
  Gates run against the pristine public branch. If their dirty tree touched
  the same lines, CI `git apply` fails red before any build step — never a
  forced apply.

## The two patches

1. **CCS fix — [`d330_fydeos_6.12.patch`](d330_fydeos_6.12.patch)**:
   portrait-panel orientation quirk (`lenovo_ideapad_d330_10igl_800x1280`),
   CCS-modifier blacklist in `skl_universal_plane.c` (kills the rotated-commit
   `-EINVAL` black screen), and the D330 PPS power-cycle-delay quirk
   (`quirk_lenovo_d330_pps` / `QUIRK_INCREASE_PPS_CYCLE_DELAY`).
   - Per-file adaptation record (2026-10-23, gate at pristine tip
     `b4e10020ba49`, kernel 6.12.54, against the old 6.6 R132 variant):
     - `drm_panel_orientation_quirks.c` — applies unmodified
     - `skl_universal_plane.c` — applies unmodified
     - `intel_pps.c` — **re-anchored**: `pps_init_delays` runs under the
       `intel_display` refactor (`struct intel_display *display`,
       `display->drm`); clamp block inserted after `#undef get_delay` with
       `intel_has_quirk(display, ...)` / `drm_info(display->drm, ...)`
     - `intel_quirks.c` — **adapted to 6.12 idioms**:
       `quirk_lenovo_d330_pps(struct intel_display *)` with
       `intel_set_quirk(display, ...)`; DMI array entry appended after the
       Google Volteer entry (the array now ends at
       `quirk_no_chicken_on_s0ix_entry`)
     - `intel_quirks.h` — **enum entry appended** after
       `QUIRK_NO_CHICKEN_ON_S0IX_ENTRY` (6.12 added three enum members the
       6.6 context lacks)

2. **GLK reset-order fixup —
   [`d330_fydeos_glk_reset_fix_6.12.patch`](d330_fydeos_glk_reset_fix_6.12.patch)**:
   the real S3-resume fix (runs `INIT_OTP` as `DEASSERT_RESET`, upstream i915
   issue [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
   It now needs its own 6.12 variant: the shared
   `../chromeos/d330_chromeos_glk_reset_fix_6.6.patch` fails at
   `intel_bios.c:2001` (post-refactor, that context is the
   `icl_fixup_mipi_sequences` comment block). Adaptations:
   - `mipi_seq_v3_count_elems` + `glk_fixup_mipi_sequences(struct intel_display *,
     struct intel_panel *)` inserted after `icl_fixup_mipi_sequences`
   - `drm_dbg_kms(display->drm, ...)` instead of `&i915->drm`
   - dispatch line `else if (IS_GEMINILAKE(i915))` — the macro still takes
     `i915` in 6.12 (`i915_drv.h:528`), and `fixup_mipi_sequences` still has
     `i915` in scope via `to_i915(display->drm)`

## Building (CI — the supported path)

```
gh workflow run build-fydeos-kernel.yml
```

The `ref` input defaults to `release-R150-16700.B-chromeos-6.12`. Download
the `fydeos-kernel` artifact from the run page: `bzImage`, `System.map`,
`.config`, `SHA256SUMS` (verify with `sha256sum -c SHA256SUMS`; proof of the
fixes: `quirk_lenovo_d330_pps` and `lenovo_ideapad_d330_10igl_800x1280` in
`System.map`). Same guardrails as the other kernel workflows: both
`git apply --check`s are the first step after fetch, red before any build,
and no artifact is ever published from a failed run.

Config and banner: the workflow builds with the tree's own chromeos x86_64
fragments (`chromeos/scripts/prepareconfig chromiumos-x86_64-generic` —
`CONFIG_DM_VERITY=y`, `CONFIG_DM_VERITY_CHROMEOS=y`, `CONFIG_BLK_DEV_DM=y`,
`CONFIG_DRM_I915=y`, which a generic defconfig lacks and the verity-rooted
image needs to boot at all), plus `CONFIG_LOCALVERSION="-fyde-01180"` +
`CONFIG_LOCALVERSION_AUTO=y`. At tip `b4e10020` with the gate's patches
applied, that reproduces the shipped banner exactly:
`6.12.54-fyde-01180-gb4e10020ba49-dirty` (`-g<sha>-dirty` comes from the
kernel's own `scripts/setlocalversion` against the shallow clone).

Local pre-verification (2026-10-23, what the CI gate enforces): fresh
shallow clones at tip `b4e10020` — both on a native LF checkout and on the
NTFS CRLF checkout — both `--check`s pass, both patches apply in order
(CCS then GLK), and all eight grep anchors land.

## Route B repack facts (Phase 60, validated offline against the image)

The plan: build here, patch the KERN-A partition in the image, user flashes
and boots. Offline validation done on the shipped v23.0-SP1 image:

- KERN-A = start 20480, size 32768 sectors (16 MiB); blob layout: keyblock
  `[0,0xcb8)`, preamble `@0xcb8` (0xf348 bytes), body `@0x10000`; the
  bootloader and vmlinuz-header regions are all zeros on stock (UEFI image,
  no legacy stub) → `--bootloader` = zero-filled 20480 bytes.
- The stock keyblock is byte-identical to the rootfs file
  `/usr/share/vboot/devkeys/recovery_kernel.keyblock`, and its data key
  (RSA8192/SHA512, sha1 `e78ce746a037837155388a1096212ded04fb86eb`) pairs
  with `/usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk`.
- Round-trip proof with the stock vmlinuz: `vbutil_kernel --pack` with
  `orig.keyblock` + that `.vbprivk` + zero bootloader + the stock 668-byte
  cmdline produces a blob that `--verify` reports "Body verification
  succeeded", whose keyblock segment is byte-identical to stock, and whose
  config round-trips byte-identically. Verdict: repack reuses the image's
  own signed keyblock, so bootloader acceptance is the same chain the stock
  kernel boots with — no dev-mode or re-signing gamble.

Nothing here is device-tested yet. Phase 60 (eyes-on boot) is the verdict.
