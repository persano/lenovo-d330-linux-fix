# Display resume on the Lenovo IdeaPad D330-10IGL (Gemini Lake, i915)

Status: **one real bug fixed (CCS + rotation); the resume-specific panel-black
failure is open but now understood as panel-side.** Instrumented on-device: the
DSI `pre_enable` *does* run on resume, and every host register (DSI link, panel
power, PLL, CDCLK, PHY) is byte-identical between the black resume state and a
working state, so no host register write can fix it. A full i915 re-init (PCI
unbind+bind) reliably restores the panel; kept as the fallback workaround
`scripts/d330-display-reload.sh`. Kubuntu 26.04 / KWin Wayland.

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

### Exhaustive register comparison cold vs resume (clean 7.0.14-d330-fix)

Raw MMIO dump of every display range (`intel_reg read --count=N <base>`; note
`--count` takes **decimal**), cold (works) vs resume (black), diffed locally.
Only **21** registers differ and none is a simple misconfiguration:

| reg | name | cold (works) | resume (black) |
| :-- | :--- | :----------- | :------------- |
| `0x6b004` | DSI INTR_STAT | `00000000` | `40200000` (bit30 + bit22 LP_RX_TIMEOUT) |
| `0x6b010` | DSI HS_TX_TIMEOUT | `003fffff` | `0000b8ea` |
| `0x6b044` | DSI HIGH_LOW_SWITCH_COUNT | `0000001d` | `0000001e` |
| `0x6b080` / `0x6b098` | DSI DPHY_PARAM | `09051003` | `0a051003` |
| `0x6b088` | DSI CLK_LANE_SWITCH_TIME_CNT | `0022000f` | `0014000c` |
| `0x6b094` | DSI INTR_EN | `00000001` | `00000000` |
| `0x46000` | **CDCLK_CTL** | `00300278` | `00b0013b` |
| `0x160018` | DSI PHY | `00000115` | `00000001` |
| `0x70040`/`44`/`48`/`4c` | pipe (SRCSZ / position) | | different |
| `0x7019c` / `0x701ac` | DSPASURF / DSPBSURF | FB address (expected) | |
| `0x138070` / `0x138074` | display power / DC | | different |
| `0x45264`/`4528c`/`45300`/`45308` | RC6 / watermark (`RR_HW_CTL`) | counters | benign |

Live-overwriting the candidates on the *black-resume* state — `0x46000`
(CDCLK_CTL) and `0x160018` (DSI-PHY), on top of the whole DSI block already
forced by the module experiments — did **not** bring the image back. So it is
not a static register value.

On the resume-black state the panel/link is *up*: `DEVICE_READY` (`0x6b000`) =
`1`, DRM state correct (`crtc active`, plane visible, rotation 270, Y-tiled),
backlight on, legacy PPS (`0xc7204`) identical cold vs resume (`0x2`). Yet
`LP_RX_TIMEOUT` fires.

### Resume vs reload: pre_enable runs, registers identical (7.0.0-38)

Decisive experiments, done by instrumenting the module and by comparing a
failing resume against a working state produced by a full driver reload:

- **`pre_enable` is not skipped.** Unconditional `pr_err("D330MARK-...")` markers
  at the top of `intel_dsi_pre_enable()` and `intel_dsi_post_disable()` show
  `post_disable` during suspend and `pre_enable` during resume. Cold boot logs
  **neither** (i915 fast-boots and never inits the DSI), which is why cold boot
  works. So the resume path does re-run the DSI init; the "the commit fastsets
  and skips the modeset" theory is wrong.
- **Reload recovers.** After a black resume, `echo 0000:00:02.0 >
  /sys/bus/pci/drivers/i915/unbind; echo 0000:00:02.0 > .../bind` re-inits the
  display and the panel comes back (repeatable). The write to `unbind` logs a
  one-off `drm_framebuffer_cleanup` oops (fbcon had framebuffers pinned); it is
  non-fatal and the rebind completes. This is the only reliable recovery found;
  shipped as `scripts/d330-display-reload.sh`.
- **Registers are identical.** Reading the DSI link block (`0x6b000`/`0x6b8xx`),
  `DEVICE_READY`, `INTR_STAT`, the panel regs (`0x160018`, `0x160020`,
  `0x160054`, `0x138090`), the PPS (`0xc7204`), `CDCLK_CTL` (`0x46000`) and the
  DSI PLL (`0x46080`) on the black resume state and again after a working reload
  gives an **empty diff** (the MIPI PHY `0x162000`/`0x163000` reads `0xffffffff`
  in both: powered down, not decoded). `intel_reg dump` differs only in
  `DSPASURF` (scanout FB address), RP thresholds and the RC6 counter.
- The resume entry point is `__intel_display_driver_resume()`
  (`display/intel_display_driver.c`), which commits via
  `drm_atomic_helper_commit_duplicated_state()`; a reload instead goes through
  the full probe + `intel_modeset_setup_hw_state()`.
- **MIPI sequences are identical too.** Instrumenting
  `intel_dsi_vbt_exec_sequence()` (`display/intel_dsi_vbt.c`, `pr_err` markers
  `D330SEQ`/`D330DATA`) shows the same sequence on both paths: suspend sends
  `BACKLIGHT_OFF(7)`, `DISPLAY_OFF(4)`, `ASSERT_RESET(5)`, `POWER_OFF(11)`;
  resume sends `POWER_ON(10)`, `DEASSERT_RESET(1)`, `INIT_OTP(2)`,
  `DISPLAY_ON(3)`, `BACKLIGHT_ON(6)`; a working reload sends the same two
  batches. Every sequence runs (`present=1`); `panel=0 bl=0` on every line
  because on GLK i915 has **no panel-power / backlight GPIO** --
  `intel_dsi_vbt_gpio_init()` sets `want_panel_gpio` only for
  valleyview/cherryview, so `gpio_panel`/`gpio_backlight` are always NULL by
  design.
- **The only host difference is `glk_cold_boot`.** Resume reaches
  `intel_dsi_pre_enable()` with `glk_cold_boot=1` (so `intel_dsi_prepare()` runs
  *before* `intel_dsi_device_ready()`), a reload with `glk_cold_boot=0` (prepare
  *after*). Forcing it to `0` on `82H0` (DMI-gated) changed nothing: resume is
  still black. `glk_cold_boot` is a correlate, not the cause.

Conclusion: the host configures the panel identically whether it ends up black
or lit. The failure is below the register layer -- most consistent with the
panel being left in a state that only the panel power/reset/DCS init (re-run in
full by the reload's probe path) clears. Host-side register patching cannot fix
it.

### Suspend depth and panel power are not the cause

- `mem_sleep`: both `deep` (S3) and `s2idle` resume black.
- A module that returns early from `intel_dsi_post_disable()` on `82H0` (panel
  never powered off / reset / PLL-disabled by i915) still resumes black, so the
  panel state does not survive suspend even when i915 leaves it alone.
- Adding a DMI-gated `msleep(300)` after `MIPI_SEQ_POWER_ON` (vs the ~1 ms
  `panel_on_delay`) did not help.

### vlv_dsi.c experiments tried on-device (none fixed it)

All gated on `dmi_match(DMI_PRODUCT_NAME, "82H0")`:

- Forced `MIPI_HS_TX_TIMEOUT=0x3fffff`, `MIPI_DPHY_PARAM=0x09051003`,
  `MIPI_CLK_LANE_SWITCH_TIME_CNT=0x0022000f`, `MIPI_HIGH_LOW_SWITCH_COUNT=0x1d`,
  `MIPI_INTR_EN=0x1` at the end of `intel_dsi_pre_enable()`: registers then match
  cold boot but the screen stays black.
- `msleep(300)` after `MIPI_SEQ_POWER_ON`.
- Early-return from `intel_dsi_post_disable()` (keep the panel powered).
- (Earlier) panel power-cycle + `MIPI_SEQ_INIT_OTP`/`MIPI_SEQ_DISPLAY_ON`
  re-send, and `BXT_P_DSI_REGULATOR_CFG` bit15 (does not stick: that block is
  `broxton`-only in `vlv_dsi.c`, skipped on GLK).

The tablet tree is restored: `vlv_dsi.c` back to stock (`vlv_dsi.c.orig`), the
clean 7.0.0-38 module rebuilt, and the default boot kernel is the clean CI
`7.0.14-d330-fix`.

## GOP reverse engineering (what cold boot relies on)

The UEFI GOP `IntelGopDriver` was extracted from the BIOS flash-descriptor dump
(`bios.bin`, sha256 `74947A176B2973B5E944D98C479BA11369AEE55EFC76E67C8AE87DE58A7F7C4B`)
and disassembled (PE32+, x64, ~89 KB, capstone). Findings:

- Uses the DSI blocks (`0x6b000`/`0x6b800`/`0x6c000`), the DSI-PHY
  (`0x162000`/`0x163000`), `BXT_P_CR_GT_DISP_PWRON` (`0x138090`), and the
  **legacy PPS** (`0xC7200`/`0xC7300`): `PP_CONTROL |= 8` (`EDP_FORCE_VDD`) then
  a stall, then `|= 4` (`EDP_BLC_ENABLE`). i915's GLK-DSI path never touches
  that PPS.
- No hardcoded I2C/PMIC MMIO base and no PMIC/I2C strings (only
  `Intel(R) GOP Driver`, `MIPI`); the panel is powered via the VBT MIPI sequence
  (GPIO 144/145/160) that i915 already runs.
- The PPS reads identical (`0x2`) cold vs resume and i915 ignores it, so GOP's
  PPS use is not the missing step either.

Extraction tooling (Python): `uefi_firmware` to parse the flash descriptor →
walk the FV/FFS → dump the `IntelGopDriver` compressed section → carve the
`MZ`/PE32+ → capstone disassembly.


## Disproven theories (do not retry)

- PPS / TCON power-cycle timing clamp (`intel_pps.c`) — wrong subsystem (eDP);
  the VBT already reports a 500 ms power cycle. The legacy PPS (`0xc7204`) runs
  and reads identical cold vs resume anyway.
- D-PHY `exit_zero_cnt` quirk, `HS_TX_TIMEOUT` retuning.
- DSI-SoC register mismatch vs GOP: the full cold/resume register diff (above)
  was forced live with no effect.
- `CDCLK_CTL` (`0x46000`) and DSI-PHY (`0x160018`) value mismatch — written live
  on the black state, no effect.
- DCS re-send after video enable.
- DSI regulator / MIPI-IO power (`0x138090`/`0x160020`/`0x160054`/`0x46080`/
  `0x161000`); the `broxton`-only block in `vlv_dsi.c` is skipped on GLK.
- Suspend depth: both `deep` (S3) and `s2idle` resume black.
- "Keep the panel powered across suspend" (early-return from
  `intel_dsi_post_disable`) — still black, so the panel does not survive suspend
  even when i915 leaves it alone.
- A PMIC on I2C bus 6 that GOP programmes and i915 does not: no Linux I2C client
  exists on bus 6, and the GOP has no I2C/PMIC MMIO or string. Not the cause.
- `modprobe -r i915` after resume: still blocked (the module stays "in use",
  ~28 refs). But a lower-level **PCI unbind/bind of `0000:00:02.0`** does work
  and restores the panel (see the reload workaround), so the earlier "cannot
  re-init without a boot" conclusion is superseded.
- `glk_cold_boot` ordering in `intel_dsi_pre_enable()`: forced to `0` on `82H0`,
  resume still black (correlate, not cause).
- Bare PCI `echo 1 > /sys/bus/pci/devices/0000:00:02.0/reset` does **not** recover
  and makes the panel worse (fully off). A full `remove`+`rescan` of the device
  also does not recover and left the box hung. Only the i915 **unbind/bind**
  reload restores the panel -- do not hot-remove the GPU.

## VBT note

Installed `G0CN12WW` VBT (sig `$VBT GEMINILAKE`) contains the MIPI sequence block
(GPIO 144 power / 145 backlight / 160 reset/OTP, DCS `11/29/28/10`). The newer
`G0CN14WW` BIOS VBT (sig `$VBT BROXTON`) has **no** MIPI sequence block and no
GPIO 144/145/160 anywhere. Do **not** flash `G0CN14WW` on Linux.

## Next steps

- The panel DCS / VBT-sequence path has now been traced and is **identical**
  between a black resume and a working reload, so the trigger is not a missing
  host re-send. The remaining panel-side lever is the panel's own
  power/reset/DCS lines (VBT GPIO 144/145/160), which i915 never drives on GLK;
  the reload's probe path effectively power-cycles the display, which is what
  clears the state.
- Fallback (kept as the working base): ship the reload recovery
  (`scripts/d330-display-reload.sh`), e.g. as a `systemd` sleep hook or a manual
  SSH/desktop action.
- Try an upstream/mainline kernel in case GLK DSI resume is a fixed regression,
  and search i915/GitLab for GLK DSI resume reports.
- KWin-side workaround: avoid the encoder disable/enable on resume
  (compositor-side rotation, or never blanking the DSI output).

## Reproduction / tooling

- Default boot kernel is the clean CI build `7.0.14-d330-fix` (CCS fix only).
- Tablet source tree: `~/d330-kernel/linux-7.0.0` (tarball, no git; stock
  `vlv_dsi.c` kept as `vlv_dsi.c.orig`).
- Incremental module build: `make -j2 M=drivers/gpu/drm/i915 modules`, then
  `strip --strip-debug`, `zstd -19`, copy to
  `/lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst`,
  `depmod -a`, `update-initramfs -u -k 7.0.0-38-generic`, reboot.
- Suspend/resume without touching the lid: `rtcwake -m mem -s N`.
- DRM debug: `echo 0xe > /sys/module/drm/parameters/debug`.
- Raw MMIO dump: `intel_reg read --count=<decimal> <base>` (writes go to stderr);
  `intel_reg dump` mis-decodes GLK pipe regs as `0`.
- GOP extraction: `bios.bin` → `uefi_firmware` (parse flash descriptor, walk
  FV/FFS, dump `IntelGopDriver` compressed section) → carve PE32+ → capstone.
