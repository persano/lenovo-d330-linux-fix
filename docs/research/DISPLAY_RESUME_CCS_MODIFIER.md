# Display resume on the Lenovo IdeaPad D330-10IGL (Gemini Lake, i915)

Status: **partial fix landed, one issue still open** (as of kernel 7.0.0-38-generic,
Kubuntu 26.04 / KWin Wayland).

## Summary

The black-screen-after-resume has (at least) two independent causes:

1. **Fixed:** the compositor's scanout framebuffer is render-compressed (CCS)
   and the panel is scanned out **rotated 270°**, a combination `i915` rejects.
   Every resume atomic commit therefore failed with `-EINVAL`.
2. **Open:** after the commit succeeds the panel is powered/backlit but shows
   **no image**; the DSI host reports an LP-RX timeout, i.e. the panel is not
   responding. Suspected panel (logic) power / sequencing not being restored on
   resume (VBT says panel power goes through the PMIC on I2C bus 6).

Cold boot works because the UEFI GOP leaves the display fully initialised and
`i915` fast-boots without re-programming the pipe; only resume forces a real
modeset.

## Cause 1: rotation + CCS framebuffer rejected (fixed)

Evidence, with `drm.debug=0xe`, captured over one suspend/resume cycle
(`/tmp/dmesg_resume.txt`, 2657 lines):

- ~2500× `[drm:intel_crtc_state_dump] [CRTC:77:pipe A] enable: yes [failed]`
- 66× `[drm:skl_plane_check] [PLANE:…] RC support only with 0/180 degree rotation (8)`
- source: `display/skl_universal_plane.c` `skl_plane_check_fb()` returns
  `-EINVAL` when `rotation & ~(ROTATE_0 | ROTATE_180)` **and**
  `intel_fb_is_ccs_modifier(fb->modifier)`.
- `[failed]` text comes from `display/intel_display.c` `intel_crtc_state_dump(new_crtc_state, state, "failed")`.

The plane advertises CCS for XRGB/ARGB8888 in `skl_plane_format_mod_supported()`,
so KWin picks a CCS framebuffer. `kwinoutputconfig.json` had the DSI-1 output at
`transform: Rotated270`.

Partial fix (patched module, srcversion `EFE1FA61A952FD4D26B7DDB`,
`suspend`+`resume` retested): stop advertising CCS on this platform (DMI `82H0`).
Result: plane-check errors `0`, failed commits `0`. KWin falls back to Y-tiled,
which does support 90/270 rotation. Patch:
`patches/d330_display_resume_fix.patch`.

Cold-boot confirmation that rotation alone matters: at cold boot, forcing
`kscreen-doctor output.DSI-1.rotation.none` on the working display also stopped
the failed-commit loop, and a full cold-boot modeset with rotation 0 renders the
desktop normally.

## Cause 2: panel dark with no image after a successful commit (open)

After the fix the atomic commit succeeds but the panel still shows nothing.
Resume DSI state:

| reg | value |
| :-- | :---- |
| `0x6b000` DEVICE_READY | `0x00000001` |
| `0x6b004` INTR_STAT | `0x40280000` (bit30, **bit22 LP_RX_TIMEOUT**, bit19 LOW_CONTENTION) |
| `0x6b104` MIPI_CTRL | `0xd0000003` |
| `0x6b080` DPHY_PARAM | `0x09051003` |
| `0x46080` DSI_PLL_ENABLE | `0xc0000000` |
| `0x161000` DSI_PLL_CTL | `0x00000132` |

`INTR_STAT` was `0x0` at a working cold boot. The VBT sequences run (POWER_ON,
INIT_OTP toggles GPIO 160; DISPLAY_ON sends DCS `0x11`/`0x29`; backlight set on
DSI-1), but the panel does not answer on LP RX. The VBT notes
`PPS GPIO Pins: Using PMIC` and `MIPI PMIC I2C Bus Number: 6`, so panel logic
power is likely supplied via the PMIC rather than a plain GPIO. Hypothesis:
that PMIC path is not re-initialised on resume.

## Disproven theories (don't retry)

- PPS / TCON power-cycle timing clamp (`intel_pps.c`) — wrong subsystem (eDP);
  VBT reports a 500 ms power-cycle already.
- D-PHY `exit_zero_cnt` quirk, `HS_TX_TIMEOUT` tuning.
- DSI-SoC register mismatch vs GOP (all registers matched).
- Re-sending the DCS init (`MIPI_SEQ_INIT_OTP` + `DISPLAY_ON`) after video enable.
- DSI regulator / MIPI-IO power (`0x138090`/`0x160020`/`0x160054`/`0x46080`/
  `0x161000` identical cold-boot-working vs resume-black); the `broxton`-only
  `BXT_P_CR_GT_DISP_PWRON` block in `vlv_dsi.c` is skipped on GLK anyway.

## VBT note

Installed `G0CN12WW` VBT (sig `$VBT GEMINILAKE`) contains the MIPI sequence block
(GPIO 144 power / 145 backlight / 160 reset/OTP, DCS `11/29/28/10`). The newer
`G0CN14WW` BIOS VBT (sig `$VBT BROXTON`) has **no** MIPI sequence block and no
GPIO 144/145/160 anywhere. Do **not** flash `G0CN14WW` on Linux.

## Reproduction / tooling

- Tablet source tree: `~/d330-kernel/linux-7.0.0` (tarball, no git).
- Incremental module build: `make -j2 M=drivers/gpu/drm/i915 modules`, then
  `strip --strip-debug`, `zstd -19`, copy to
  `/lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst`,
  `depmod -a`, `update-initramfs -u -k 7.0.0-38-generic`, reboot.
- DRM debug: `echo 0xe > /sys/module/drm/parameters/debug`.
