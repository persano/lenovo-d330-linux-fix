# Upstream Handoff: D330-10IGL (Gemini Lake) MIPI-DSI panel black after S3 — filing package

<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: rebind -->
<!-- planner-discipline-allow: PMIC -->
<!-- planner-discipline-allow: panel power-cycle -->
<!-- planner-discipline-allow: MIPI_SEQ_INIT_OTP -->

Purpose: everything a maintainer (or you, filing by hand per the phase 44 decision) needs
to reproduce, evidence, and reason about this bug. Machine evidence first, honest outcome
stated. **Do not commit credentials; this file contains none.**

## Machine

- Lenovo IdeaPad D330-10IGL, DMI product `82H0` (DMI: LENOVO 82H0/LNVNB161216, BIOS
  G0CN12WW 12/19/2022)
- Gemini Lake Refresh: Celeron N4020, UHD Graphics 600; MIPI-DSI panel 800x1280
  (card1-DSI-1), GPIOs 144 (power) / 145 (backlight) / 160 (reset/OTP) per VBT block 53
- Ubuntu resolute-era userspace, kernel 7.0.0-38.38 base (upstream 7.0.14) with a small
  DMI-gated CCS patch unrelated to this bug (kept separate)

## Symptom

Suspend (S3 `deep` — and also `s2idle`) → resume: backlight returns, desktop session
survives, sysfs reports the connector enabled (`dpms=On`, `bl_power=0`, brightness
restored), `i915_display_info` shows pipe B `enable=yes active=yes mode="800x1280"
port_clock=80000` with planes assigned — and the **panel shows no image** (lit but black).
The display pipeline cannot be recovered by: the i915 unbind/bind reload (restores sysfs,
not the image), a fresh compositor (SDDM restart), KScreen DPMS cycles, a second
suspend/resume, or an atomic full encoder cycle forced post-resume. **Only a full reboot
restores the panel.**

## What we proved (evidence)

1. **Kernel state is byte-identical working vs broken**: `i915_display_info` captured on
   the same boot pair differs only in the cursor plane's framebuffer; everything else —
   pipe, clocks, planes, connector — identical. The failure is below the kernel's
   software model.
2. **The VBT sequences run and are not enough**: ftrace shows the resume path running the
   complete block-53 cycle (POWER_ON ~1 ms GPIO 144, INIT_OTP 50 ms GPIO 160 toggling,
   DISPLAY_ON 152 ms DCS 0x11→0x29) plus `intel_backlight_enable`; the panel still shows
   nothing.
3. **The boot-time success depends on the GOP firmware**: the GOP driver
   (`gop_driver_dc90d1e2.efi`) runs its own panel init from the same VBT before ExitBootServices;
   the kernel's later replay of the same sequences does not reproduce the result. Two VBTs
   exist (SPI copy "BROXTON" BDB 206 without block 53; runtime OpRegion copy "GEMINILAKE"
   BDB 212 with block 53 — the kernel uses the runtime one).
4. **Disproven levers (29)**: PPS/TCON timing clamps, D-PHY retuning, forced register
   batches (MIPI/CDCLK/chicken), panel power-cycle re-sends, keep-panel-powered
   early-returns, PMIC-I2C theories, s2idle/deep switches, power-well disables, backlight
   toggles, re-probe/rebind recoveries, and more — each with its disproof in
   docs/research/RESUME_FIX_LEDGER.md.
5. **Not PMIC on I2C bus 6**: no Linux I2C client exists there and the GOP binary has no
   I2C/PMIC MMIO or strings.

## Artifacts

- `docs/research/NO_CLEAN_FIX_PROOF.md` — full iteration closure (3 deployed, eyes-on
  tested candidates: deferred atomic full cycle, post-resume re-probe, s2idle — all
  failed with the panel still imageless)
- `docs/research/GOP_DSI_RE_FINDINGS.md` — GOP RE (22,080 B driver, VBT handoff at
  OpRegion +0x3ba/+0x3c2, block-53 sequence table decoded)
- `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md` — suspend/off vs reload vs probe
  differential with traces
- `docs/dumps/re_kit/` — checksummed kit: GOP binary, SPI dump, VBT decodes, ftrace
  traces, displayinfo pair + diff

## Ask for upstream

Which part of the boot-time GOP panel bring-up the kernel's resume path fails to
replicate on GLK DSI — and what instrumentation you would want added (e.g. a
GLK-DSI-capable `i915_dsi_info` debugfs dump of the transcoder/DPHY registers at boot
vs post-resume) to close the gap. We could not find it within 5 iterations
(NO_CLEAN_FIX_PROOF.md); the display-state registers we could see are identical.

## Filing note (for the user)

File at https://gitlab.freedesktop.org/drm/i915/kernel/-/issues with: this file's
machine/symptom/evidence sections, `dmesg` from a failing resume,
`/sys/kernel/debug/dri/*/i915_display_info` boot + post-resume pair, and the ftrace
resume trace. Attach the kit's `broken_displayinfo.txt`/`boot_displayinfo.txt`/diff.
Remove any personal info before submitting.
