# Display resume on the Lenovo IdeaPad D330-10IGL (Gemini Lake, i915)

Status: **one real bug fixed, the resume-specific failure still open** (as of
kernel 7.0.0-38-generic, Kubuntu 26.04 / KWin Wayland). Parked here.

## Summary

Observed behaviour on the D330 (native portrait 800x1280 panel):

| state | rotation 0 | rotation 270 |
| :---- | :--------- | :----------- |
| cold boot | image, sideways | **image, upright** (GOP-initialised) |
| resume from S3 | image, sideways (seen once) | **black** |

Two separate things were found:

1. **Fixed:** `skl_plane_check_fb()` rejects a render-compressed (CCS) scanout
   framebuffer combined with 90/270 rotation. KWin picks a CCS framebuffer, so
   `kwinoutputconfig.json` at `transform: Rotated270` made every atomic commit
   fail with `-EINVAL`. Not advertising CCS on `82H0` fixes that; the patch is
   `patches/d330_display_resume_fix.patch`.
2. **Open:** after resume the atomic commit succeeds (`skl_plane_check` errors
   `0`) but the panel stays black at rotation 270, even though the exact same
   rotation renders correctly at cold boot. This is a KWin-rotation + GLK-DSI
   resume interaction, not a readable register mismatch.

Cold boot works because the UEFI GOP leaves the display fully initialised and
`i915` fast-boots without re-programming the pipe; resume forces a real modeset.

## Cause 1: rotation + CCS framebuffer rejected (fixed)

Evidence, `drm.debug=0xe`, one suspend/resume cycle:

- ~2500x `[drm:intel_crtc_state_dump] [CRTC:77:pipe A] enable: yes [failed]`
- 66x `[drm:skl_plane_check] [PLANE:...] RC support only with 0/180 degree rotation (8)`
- source: `display/skl_universal_plane.c` `skl_plane_check_fb()` returns
  `-EINVAL` when `rotation & ~(ROTATE_0 | ROTATE_180)` **and**
  `intel_fb_is_ccs_modifier(fb->modifier)`.

Fix (patched module, retested): stop advertising CCS on `82H0` in
`skl_plane_format_mod_supported()`. KWin then uses Y-tiled
(`modifier = 0x100000000000002`), which supports 90/270, and the commit
succeeds (`[failed]` and plane-check counters drop to `0`).
Patch: `patches/d330_display_resume_fix.patch`.

## Cause 2: resume still black at rotation 270 (open)

With the CCS fix in place the commit succeeds but the display is still black
after resume at rotation 270. Confirmed on-device:

- Cold boot, `kscreen-doctor output.DSI-1.rotation.right` (270): image upright.
- `rtcwake -m mem` resume at 270: black, and re-applying the rotation does not
  bring it back.
- Resume at rotation 0 was seen to render once (sideways); rotation 90 rendered
  (upside down, i.e. 270 is the correct orientation).
- No `skl_plane_check`/`[failed]` errors in any of these.

### Register comparison cold boot vs resume

`intel_reg dump` (engine/pipe/backlight/PPS) differs only in counters
(`GEN6_RP_UP_*`, `WM_SR_CNT`, `RC6_RESIDENCY_TIME`). Full DSI block
(`0x6b000`-`0x6b104`, `intel_reg read`) differs only in:

| reg | cold (works) | resume (black) |
| :-- | :----------- | :------------- |
| `0x6b004` INTR_STAT | `0x00080000` | `0x40200000` (bit30 + bit22 LP_RX_TIMEOUT) |
| `0x6b010` HS_TX_TIMEOUT | `0x003fffff` | `0x0000b8ea` |
| `0x6b094` INTR_EN_REG_1 | `0x00000001` | `0x00000000` |
| `0x7019c` DSPASURF | different FB address (expected) | — |
| `0x160020` DSI_REGULATOR_CFG | `0x00008646` | `0x00000646` (bit15 clear) |

`0x160020` bit15: set by the GOP, not programmed by i915 on GLK (the block that
writes it is `broxton`-only in `vlv_dsi.c intel_dsi_pre_enable()`). Attempting
to set it there (`intel_de_rmw(..., BIT(15))`) did **not** stick: the register
still read `0x00000646` after resume, so it did not fix the screen either.

Note: on GLK `intel_reg dump` decodes several pipe registers as `0` in the
working cold-boot state too (`PIPEA`, `HTOTAL_A`, `VSYNC_A`...), so it cannot
reliably read that block; only the `intel_reg read` of the DSI range above is
trustworthy.

### vlv_dsi.c experiments tried on-device (none fixed it)

All gated on the existing `vlv_dsi_dphy_quirk` DMI match (`82H0`):

- Forced panel power-cycle (`MIPI_SEQ_POWER_OFF` + `MIPI_SEQ_ASSERT_RESET` +
  500 ms) before the normal power-on: made the panel light up but not show an
  image.
- Re-sending `MIPI_SEQ_INIT_OTP` + `MIPI_SEQ_DISPLAY_ON` after backlight on.
- `BXT_P_DSI_REGULATOR_CFG` bit15 write (see above, did not stick).
- `MIPI_HS_TX_TIMEOUT` forced to `0x3fffff` on all ports.

The tablet currently runs a module with these `vlv_dsi.c` changes
(srcversion `090806398B82B5991C8FC42`) plus the CCS fix; cold boot works.
Reverting `vlv_dsi.c` to stock is only a rebuild away and is recommended for a
clean tree.

## Disproven theories (do not retry)

- PPS / TCON power-cycle timing clamp (`intel_pps.c`) — wrong subsystem (eDP);
  the VBT already reports a 500 ms power cycle.
- D-PHY `exit_zero_cnt` quirk, `HS_TX_TIMEOUT` retuning.
- DSI-SoC register mismatch vs GOP.
- DCS re-send after video enable.
- DSI regulator / MIPI-IO power (`0x138090`/`0x160020`/`0x160054`/`0x46080`/
  `0x161000`); the `broxton`-only block in `vlv_dsi.c` is skipped on GLK.

## VBT note

Installed `G0CN12WW` VBT (sig `$VBT GEMINILAKE`) contains the MIPI sequence block
(GPIO 144 power / 145 backlight / 160 reset/OTP, DCS `11/29/28/10`). The newer
`G0CN14WW` BIOS VBT (sig `$VBT BROXTON`) has **no** MIPI sequence block and no
GPIO 144/145/160 anywhere. Do **not** flash `G0CN14WW` on Linux.

## Suggested next steps (parked)

- Try an upstream/mainline kernel in case GLK DSI resume is a fixed regression.
- Investigate a KWin-side workaround (compositor-side rotation instead of plane
  rotation for this output).
- A post-resume `systemctl` sleep hook re-applying the output config did not
  help.

## Reproduction / tooling

- Tablet source tree: `~/d330-kernel/linux-7.0.0` (tarball, no git).
- Incremental module build: `make -j2 M=drivers/gpu/drm/i915 modules`, then
  `strip --strip-debug`, `zstd -19`, copy to
  `/lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst`,
  `depmod -a`, `update-initramfs -u -k 7.0.0-38-generic`, reboot.
- Suspend/resume without touching the lid: `rtcwake -m mem -s N`.
- DRM debug: `echo 0xe > /sys/module/drm/parameters/debug`.
