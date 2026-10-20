# ChromeOS Kernel Patching Guide (Lenovo D330-10IGL)

How the ChromeOS kernel for the D330 is patched, built, and (eventually)
installed. Companion: [`BLISSOS_KERNEL_GUIDE.md`](BLISSOS_KERNEL_GUIDE.md).

Target: Lenovo IdeaPad D330-10IGL (Type 82H0, Intel Gemini Lake Refresh
UHD 600, portrait 800x1280 panel).

## What the kernel fixes

Same fix pair as every other target, applied in order:

1. **CCS fix** — [`patches/chromeos/d330_chromeos_6.6.patch`](../patches/chromeos/d330_chromeos_6.6.patch)
   - D330 portrait panel orientation quirk (`lenovo_ideapad_d330_10igl_800x1280`,
     DMI `82H0`) plus the CCS-modifier blacklist in `skl_universal_plane.c`,
     so the rotated atomic commit no longer fails with `-EINVAL` and leaves
     the display black.
2. **GLK reset-order fixup** — [`patches/chromeos/d330_chromeos_glk_reset_fix_6.6.patch`](../patches/chromeos/d330_chromeos_glk_reset_fix_6.6.patch)
   - The real resume fix: runs `INIT_OTP` (GPIO + delay only) as
     `DEASSERT_RESET` in the Gemini Lake VBT sequence parser, fixing the
     resume panel death from the empty `MIPI_SEQ_DEASSERT_RESET`
     (upstream i915 issue
     [#13225](https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/13225)).

History worth knowing: the CCS patch shipped in v11.0 was claimed
"verified clean" but was in fact corrupt (bad hunk count) and anchored to a
post-`intel_display`-refactor tree that `chromeos-6.6` is not. It was
found red at the Phase 59 pre-verification gate and re-adapted against the
real tree (kernel 6.6.147). The per-file adaptation record is in
[`patches/chromeos/README.md`](../patches/chromeos/README.md); the red and
green gate logs are preserved there by reference. If you touch this patch
again, that README is where the change gets recorded.

## Source tree

- Repo: `https://chromium.googlesource.com/chromiumos/third_party/kernel`
- Branch: `chromeos-6.6` (tip `a534360e` at verification time, kernel 6.6.147)
- Checkout: shallow single-branch clone — this is the kernel repo only, NOT
  the full depot_tools platform tree (that one wants tens of GB and is only
  needed to build a complete bootable image, which is out of scope here)
- Config basis: the tree's own `arch/x86/configs/x86_64_defconfig` +
  `olddefconfig`, with the same hygiene knobs as the BlissOS build:
  debug-info/BTF/gdb-scripts off, `LOCALVERSION_AUTO` off, trusted-keys
  cleared, `WERROR` off (insurance — the BlissOS runner needed it; same
  gcc, nothing observed here yet), `LOCALVERSION=-d330-chromeos`

## Building (CI — the supported path)

Any machine with GitHub CLI auth can dispatch; the build runs on GitHub's
Ubuntu runner:

```
gh workflow run build-chromeos-kernel.yml -f ref=chromeos-6.6
```

Download the `chromeos-kernel` artifact from the run page (~40 minutes):

- `bzImage`, `System.map`, `.config`, `SHA256SUMS`
- Verify with `sha256sum -c SHA256SUMS` after download
- Proof the fixes compiled in: `System.map` contains `quirk_lenovo_d330_pps`
  and `lenovo_ideapad_d330_10igl_800x1280`

Same guardrails as the BlissOS workflow: `git apply --check` on both
patches is the first step, red before any build, and no artifact is ever
published from a failed run.

Validated: run
[39374039313](https://github.com/persano/lenovo-d330-linux-fix/actions/runs/39374039313)
(2026-10-20) — green on first dispatch, artifact hashes 3/3.

## Building (local, optional)

```
git clone --depth 1 -b chromeos-6.6 \
  https://chromium.googlesource.com/chromiumos/third_party/kernel
cd kernel
git apply --check ../patches/chromeos/d330_chromeos_6.6.patch
git apply ../patches/chromeos/d330_chromeos_6.6.patch
git apply --check ../patches/chromeos/d330_chromeos_glk_reset_fix_6.6.patch
git apply ../patches/chromeos/d330_chromeos_glk_reset_fix_6.6.patch
make x86_64_defconfig
scripts/config --enable DEBUG_INFO_NONE || true
scripts/config --disable DEBUG_INFO_BTF GDB_SCRIPTS LOCALVERSION_AUTO WERROR || true
scripts/config --disable SYSTEM_TRUSTED_KEYS SYSTEM_REVOCATION_KEYS || true
make olddefconfig
make -j"$(nproc)" bzImage
```

Result: `arch/x86/boot/bzImage`.

## Installing on the device — the hard part

Status: source-built and CI-validated, **not yet device-tested** — that is
Phase 60 (eyes-on USB boot). Honest picture before you start:

- ChromeOS does not keep the kernel as a loose file on disk. It lives in a
  dedicated, cryptographically signed **kernel partition** (`KERN-A` /
  `KERN-B`) inside the image, and the bootloader refuses anything unsigned.
- Replacing it means repacking that partition, not copying a file:

  ```
  vbutil_kernel --pack new-kernel.bin \
    --vmlinuz bzImage \
    --keyblock /usr/share/vboot/dev.keyblock \
    --signprivate /usr/share/vboot/dev_data.vbprivk \
    --config <boot-commandline-file> \
    --version 1
  ```

  then writing `new-kernel.bin` into the kernel partition
  (`cgpt add -i 2 -P 1 -T 1 ...` + `dd` from a ChromeOS live/term session,
  device in dev mode). Dev mode + `chromeos-usb`/`cgpt` tooling is assumed;
  the exact partition indices depend on the image you start from.
- A plain bzImage alone cannot boot a ChromeOS USB stick. If the repack
  route proves too heavy on the D330, the fallback is building a small
  standalone image (the deferred depot_tools route) — Phase 60 decides,
  based on what the device actually accepts.
- Same PSR/FBC caveat as BlissOS: if resume still misbehaves with the fixed
  kernel, try `i915.enable_psr=0 i915.enable_fbc=0` on the kernel
  command line (baked into the `--config` file during repack).

## Updating the patches

1. Edit the patch (or the branch ref).
2. Let CI's gate verify it — first step, red on any mismatch — or run the
   local `git apply --check` sequence above.
3. Commit, push, dispatch, and record the why in
   [`patches/chromeos/README.md`](../patches/chromeos/README.md).
