# TCON Identification — Verdict

**Phase:** 50 (Milestone v10.0 — Crack the Panel)
**Date:** 2026-10-17
**Session discipline:** 47/49 RE-kit protocol; all captures registered in `docs/dumps/re_kit/MANIFEST.sha256` (`prepare_safety_kit.sh --verify` exit 0).

## Verdict

**The software DCS read path is dead on the D330 panel. The TCON identity is NOT obtainable from the running kernel.**

The `echo 2` instrument (Phase 50 / plan 50-01) was built by CI (run 38974632465), deployed behind a sha-verified rollback, and exercised in both operational states. All five DCS reads (0x04 Get Display ID, 0xDA, 0xDB, 0xDC, generic read) returned `ret=4 avail=0 data=00 00 00` in every run, in both arms:

| Arm | State | Runs | DCS result |
|-----|-------|------|------------|
| X=Y (boot, image visible) | panel initialized by GOP | 2 (user-requested retry; byte-identical) | all five: `avail=0 data=00 00 00` |
| X=Z (black resume, eyes-on: "screen lit but black") | panel after S3 | 1 | all five: `avail=0 data=00 00 00` |

`GEN_READ_DATA_AVAIL` (MIPI_INTR_STAT bit 29) was never set — the panel never placed read data on the RX path. `intel_dsi_host_transfer()` returns `4 + payload_length` even on timeout (research finding), so `ret=4` is not evidence of a successful read; the `avail` annotation is the discriminator, and it reads 0 everywhere.

## What this falsifies

- **E3 discriminator (Phase 51 ladder):** the DCS-read discriminator cannot work — the read path fails at X=Y already, so "reads succeed at boot but fail at wake" can never be observed. E3 is dead as designed; any E3-shaped discriminator needs the hardware logic analyzer (Phase 53), not the kernel.
- **Datasheet hunt via ID read:** no ID → no direct datasheet cross-reference. The candidate list (AUO G101EAN01.x, ILI9881C, ST7701/ST7703, HX8394(F), NT36672(a)) stays open, gated on Phase 53 wire-level identification or an FRU/glass cross-reference that does not exist publicly today.

## What this does NOT falsify

- The MMIO-dump instrument itself: both captures are complete (7296 records, all five sections 100%, floor-checked) and the boot-vs-resume MMIO diff ran clean (`dsi_regs_diff_tcon_boot_vs_resume.txt`, 24 rows).
- The write path: the node's MMIO walk and dmesg confirmation work in both arms; the kernel-side RX plumbing exists but the panel never answers.

## Why the reads may be dead (documented reasons, honest scope)

1. **GLK/Cherryview DSI host may serialize LP access against active HS video** (RESEARCH Q1) — reads issued on the LP GEN channel while video runs on HS. Untestable from software: there is no way to quiesce video at X=Y without losing the state we are probing.
2. **Panel/TCON may never implement BTA/reads** despite VBT block 52 declaring BTA enabled — VBT is the *motherboard's* claim, not the panel's promise.
3. **Both are consistent with the §6 signature** ("HS video stream never accepted by panel"): a panel that never completed the host's video handshake may also never complete a BTA read.

Distinguishing 1 vs 2 requires driving LP/HS from outside the kernel — Phase 53's logic-analyzer capture (buy-gate first).

## I2C sideband conclusion (TCON-03)

- **11 buses exist** (i2c-0..5 LPSS DesignWare, i2c-6..8 gmbus, i2c-9 AUX/DDI/PHY, i2c-10 SMBus I801 @0000:00:1f.1).
- **No PMIC found by name on bus 6** (bus 6 = gmbus dpb) — the pre-session "PMIC on bus 6" expectation is **not confirmed**; INT33FF did not appear in this boot's inventory. i2c-10 (SMBus) ACKs at 0x08 and 0x44.
- **No panel-TCON sideband on any bus:** during the echo-2 instrument run (boot arm) there were **zero i2c-core transfers**; during wake-to-capture (resume arm) the only traffic was the Goodix touchscreen (i2c-1 @0x14) and one i2c-3 write. Nothing addresses a display controller.
- GPIO: `line 23: unnamed output consumer=reset` — a candidate panel reset line, consistent with no software-visible sideband.
- `i2c_dw_handle_tx_abort: lost arbitration` storm on i2c_designware.4 during the sweep — recorded, not investigated (out of phase scope).
- **Pre-kernel GOP blind spot:** every I2C claim above is scoped to the kernel-era time windows the tracepoints covered; any bus the GOP touched during firmware init (before the kernel armed its tracepoints) is invisible here — closing that gap needs Phase 53's wire-level capture.

## Artifacts

| File | sha256 (first 8) | Arm |
|------|------------------|-----|
| `tcon_boot_dsi_regs.txt` | `b77d5abb` | X=Y run 1 |
| `tcon_boot_dsi_regs_run2.txt` | `7826a5be` | X=Y run 2 (retry) |
| `tcon_resume_dsi_regs.txt` | `da692043` | X=Z |
| `tcon_i2c_sweep.txt` / `_run2.txt` | `28b99307` / `884388e2` | X=Y sweeps |
| `tcon_i2c_trace_boot.txt` / `_run2.txt` | `f013a648` / `bf0f1f2a` | X=Y traces |
| `tcon_i2c_trace_resume.txt` | `e504f9fd` | X=Z wake trace |
| `dsi_regs_diff_tcon_boot_vs_resume.txt` | (kit-registered) | X=Y vs X=Z MMIO diff |

## Consequences for Phase 51

E1 (skip panel-side teardown) and E2 (warm-resume enable) are unaffected — they do not depend on DCS reads. E3 must be redefined: its discriminator is now "does the image come back" (E1/E2 outcome itself), not a DCS read. Phase 53's buy-gate (KingstVIS MIPI-DSI LP decoder demo-mode validation) becomes the identification path if E1/E2 fail and the panel still matters.
<!-- planner-discipline-allow: No PMIC found by name on bus 6 -->
