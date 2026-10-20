# BlissOS Kernel Patching Guide (Lenovo D330-10IGL)

How the BlissOS (Android-x86) kernel for the D330 is patched, built, and
installed. Companion: [`CHROMEOS_KERNEL_GUIDE.md`](CHROMEOS_KERNEL_GUIDE.md).

Target: Lenovo IdeaPad D330-10IGL (Type 82H0, Intel Gemini Lake Refresh
UHD 600, portrait 800x1280 panel).

## What the kernel fixes

Both fixes live in two patches applied in order:

1. **CCS fix** — [`patches/android/d330_android_x86_6.6.patch`](../patches/android/d330_android_x86_6.6.patch)
   - Registers the D330's portrait panel orientation quirk
     (`lenovo_ideapad_d330_10igl_800x1280`, DMI `82H0`).
   - Stops `skl_universal_plane.c` from advertising render-compressed (CCS)
     modifiers on the D330. Userspace scans out rotated 90/270 degrees;
     `skl_plane_check_fb()` rejects a CCS framebuffer combined with that
     rotation, so every atomic commit fails with `-EINVAL` and the display
     stays black. Without CCS advertised, userspace falls back and the
     commit succeeds.
2. **GLK reset-order fixup** — [`patches/android/d330_android_glk_reset_fix_6.6.patch`](../patches/android/d330_android_glk_reset_fix_6.6.patch)
   - The real resume fix. The Gemini Lake VBT ships an empty
     `MIPI_SEQ_DEASSERT_RESET` sequence, so on resume the DSI panel reset
     pulse runs *after* the DSI host is already up and the panel dies
     (upstream i915 issue
     [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).
     The fix parses and runs `INIT_OTP` (GPIO + delay only) as
     `DEASSERT_RESET`, restoring correct reset ordering.

Applied alone, the CCS patch fixes orientation and the rotated-commit black
screen but NOT the resume panel death — always apply the GLK patch on top.

Historical debug probes (`patches/d330_dsi_*.patch`) are investigation
artifacts, not shipping fixes, and are intentionally not part of the kernel.

## Source tree

- Repo: `https://github.com/android-generic/kernel_common` (the live BlissOS
  x86 tree; the old BlissRoms tree is stale, max 6.3)
- Branch: `hm/crimson` — kernel 6.6.129 (verified against tip `447ff151`)
- Config basis: `x86_64_defconfig` + `olddefconfig`, with these adjustments
  (kept in the workflow so a rebuild is reproducible):
  - `DEBUG_INFO_NONE`, `DEBUG_INFO_BTF`, `GDB_SCRIPTS`, `LOCALVERSION_AUTO`
    off — the runner has limited disk and the result is a normal bootable kernel
  - `SYSTEM_TRUSTED_KEYS`/`SYSTEM_REVOCATION_KEYS` cleared (no corporate CA)
  - `WERROR` off — the crimson defconfig sets `CONFIG_WERROR=y`; the runner's
    gcc hits `-Werror=implicit-fallthrough` in upstream code (BlissOS builds
    this tree with clang, whose warning set differs). Warnings stay visible,
    they no longer abort the build.
- The tree has a `drivers/kernelsu` submodule symlink — a shallow clone must
  run `git submodule update --init --depth 1` or Kconfig dies with
  "can't open file drivers/kernelsu/Kconfig".

## Building (CI — the supported path)

Any machine with GitHub CLI auth can dispatch; the build runs on GitHub's
Ubuntu runner, nothing is needed locally:

```
gh workflow run build-blissos-kernel.yml -f ref=hm/crimson
```

Then open the run in the Actions tab and download the `blissos-kernel`
artifact when it finishes (about 40 minutes):

- `bzImage` — the kernel
- `System.map` — symbol table (proof the fixes compiled in: look for
  `quirk_lenovo_d330_pps`)
- `.config` — exact build configuration
- `SHA256SUMS` — verify after download with `sha256sum -c SHA256SUMS`

The workflow's first step re-verifies both patches with `git apply --check`
against a freshly fetched tree, so a bad patch goes red before any build
time is spent, and a failed run never publishes a partial artifact.

Validated: run
[39365529173](https://github.com/persano/lenovo-d330-linux-fix/actions/runs/39365529173)
(2026-10-20) — green, artifact hashes 3/3, CCS symbols present in System.map.

## Building (local, optional)

```
git clone --depth 1 -b hm/crimson https://github.com/android-generic/kernel_common
cd kernel_common
git submodule update --init --depth 1
git apply --check ../patches/android/d330_android_x86_6.6.patch
git apply ../patches/android/d330_android_x86_6.6.patch
git apply --check ../patches/android/d330_android_glk_reset_fix_6.6.patch
git apply ../patches/android/d330_android_glk_reset_fix_6.6.patch
make x86_64_defconfig
scripts/config --enable DEBUG_INFO_NONE || true
scripts/config --disable DEBUG_INFO_BTF GDB_SCRIPTS LOCALVERSION_AUTO WERROR || true
scripts/config --disable SYSTEM_TRUSTED_KEYS SYSTEM_REVOCATION_KEYS || true
make olddefconfig
make -j"$(nproc)" bzImage
```

Result: `arch/x86/boot/bzImage`. Same gate order as CI: `--check` before
each `apply`, CCS first, GLK second.

## Installing on the device

Status: source-built and CI-validated, **not yet device-tested** — that is
Phase 58 (eyes-on USB boot). The expected procedure, Android-x86 layout:

- The kernel ships as a plain `kernel` file next to `initrd.img` on the USB
  (or inside the ISO root — extract the ISO first).
- Replace that file with the artifact's `bzImage` (renamed to `kernel`).
- Keep `initrd.img` and the syslinux/grub config untouched — they do not
  change.
- Installed-to-disk variant: same file, under `/boot` of the Android
  partition.

If the panel still dies on resume with the fixed kernel, try booting with
`i915.enable_psr=0 i915.enable_fbc=0` on the kernel command line — the
Linux distro setup disables PSR/FBC via modprobe config for pipe lockups;
on Android-x86 that has to happen via cmdline, not kernel build.

## Updating the patches

1. Edit the patch (or the tree ref) in this repo.
2. Run the local pre-verification above (or let CI do it — the gate is the
   first step and turns the job red on any mismatch).
3. Commit, push, dispatch. If you change the patch file, record the why in
   [`patches/android/README.md`](../patches/android/README.md) — that file
   is the per-file adaptation ledger.
