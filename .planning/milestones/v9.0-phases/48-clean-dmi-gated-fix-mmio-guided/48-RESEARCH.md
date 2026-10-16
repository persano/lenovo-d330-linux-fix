---
phase: 48
title: Clean DMI-Gated Fix (MMIO-Guided) — Technical Research
generated: 2026-10-14
researcher: gsd-phase-researcher (inline fallback — 3 consecutive subagent-spawn 504s; orchestrator executed research protocol directly)
model: opus (orchestrator)
---

# Phase 48 Research: DSI Resume Fix Design Space

## 1. What we know for certain (machine-evidenced, this repo)

### 1.1 The resume path DOES run the full DSI init (v8.0, D330MARK markers)
`intel_dsi_pre_enable()` runs on resume (post_disable on suspend). The "commit
fastsets and skips encoder hooks" theory is **disproven**
(DISPLAY_RESUME_CCS_MODIFIER.md "Resume vs reload" section). Cold boot runs
neither hook (i915 fast-boots on GOP handover) — cold boot works because GOP
already initialized the panel.

### 1.2 The VBT MIPI sequences run identically on resume and reload
Instrumented `intel_dsi_vbt_exec_sequence()` (D330SEQ/D330DATA/D330GPIO
markers): suspend sends BACKLIGHT_OFF(7)→DISPLAY_OFF(4)→ASSERT_RESET(5)→
POWER_OFF(11); resume sends POWER_ON(10)→DEASSERT_RESET(1)→INIT_OTP(2)→
DISPLAY_ON(3)→BACKLIGHT_ON(6); a working reload sends the same two batches.
GPIO 144/145/160 driven with identical values. **The panel-side DCS/power
sequence is NOT the difference.**

### 1.3 Value writes at end of pre_enable are disproven (ledger rows 3/18)
Forcing HS_TX_TIMEOUT/DPHY_PARAM/CLK_LANE_SWITCH_TIME/HIGH_LOW_SWITCH_COUNT/
INTR_EN to boot values at the end of `intel_dsi_pre_enable()` (row 18) and the
earlier 0x46000+0x160018 overwrite (row 3) produced "registers match cold
boot" and the screen stayed black. **Phase 47's operational rows overlap row
18's batch almost exactly** (0x6b010=_MIPIA_HS_TX_TIMEOUT 0xb010,
0x6b044=_MIPIA_HIGH_LOW_SWITCH_COUNT 0xb044; register map verified in
`vlv_dsi_regs.h:95-233` on the device tree).

### 1.4 The ONLY reliable recovery is the full i915 re-probe
`unbind; bind` (`scripts/d330-display-reload.sh`) always lights the panel.
Reload = PCI remove (display core power OFF, panel POWER_OFF via cleanup
disable path, DMC re-load, power domains rebuilt) then **the same pre_enable
sequence from a hardware-reset DSI block**. No lighter recovery works (28+
disproven rows).

### 1.5 The at-wake operational state is a flickering proxy, NOT the discriminator
Phase 47 session 1 (0-1 s post-wake): operational rows at X=Y (0x160018=0x115,
0x6b010=0x3fffff) — panel outcome unknown at wake (verdict missed), image only
after the user's manual workaround later. Session 2 (verified BLACK): X=Z +
timeout-marked 0x6b004. v8.0's late reads: empty diff black-vs-reload (X=Y
both). **Synthesis: the operational register set returns to X=Y by
late-readback even when the panel stays black.** The DSI_MMIO_DIFF §5
falsification branch is therefore LIVE and now has two legs of support: (a)
row-18 forced X=Y + black; (b) X=Y eventually + black.

### 1.6 The one code-visible divergence between resume and reload: retained DSI device state
`glk_dsi_enable_io()` (vlv_dsi.c:328-345): `cold_boot |= !(MIPI_DEVICE_READY &
DEVICE_READY)`. On **resume**, DEVICE_READY is retained set through S3 →
`glk_cold_boot=1`. On **reload/probe**, fresh hardware → DEVICE_READY=0 →
`glk_cold_boot=0`. Forcing `glk_cold_boot=0` alone changed nothing (it only
moves `intel_dsi_prepare()` after `intel_dsi_device_ready()`).

**But `glk_dsi_device_ready()` (vlv_dsi.c:369-428) branches independently on
DEVICE_READY and was never touched by that experiment:**
```c
if (!(MIPI_DEVICE_READY & DEVICE_READY)) {
    /* plain path: rmw ULPS_STATE_MASK → DEVICE_READY */        ← reload takes this
} else {
    /* ULPS enter → wait ULPS active → ULPS exit → normal op → LP_WAKE clear */
}                                                                ← resume takes this
```
On resume the driver runs the **ULPS enter/exit dance on a device that was
never taken out of ready**, then `intel_dsi_wait_for_set(GLK_DATA_LANE_STOP_STATE)`
and `AFE_LATCHOUT`. The panel TCON sees a ULPS poke where the working path
(reload) sees a clean DEVICE_READY from reset. **This dance is the only
sequence step that structurally differs between the always-black resume path
and the always-lit reload path.** It is un-tried as a lever (forcing
glk_cold_boot did not alter it; it only reads the same retained
DEVICE_READY).

### 1.7 Register names (tree-verified, device `~/d330-kernel/linux-7.0.0`)
| offset | name | source |
|--------|------|--------|
| 0x6b000 | MIPI_DEVICE_READY (A) | vlv_dsi_regs.h:95-97 |
| 0x6b004 | MIPI_INTR_STAT (A) | :105 |
| 0x6b008 | MIPI_INTR_EN (A) | :108 (the 0x6b094 row is a second INTR area cell — cite by address) |
| 0x6b010 | MIPI_HS_TX_TIMEOUT (A) | :167-169 |
| 0x6b014 | MIPI_LP_RX_TIMEOUT (A) | :172-174 |
| 0x6b044 | MIPI_HIGH_LOW_SWITCH_COUNT (A) | :231-233 |
| 0x6b088 | MIPI_CLK_LANE_SWITCH_TIME_CNT (A) | (same header family) |
| 0x160004/8 | MIPIO_TXESC_CLK_DIV1/2 | vlv_dsi_pll_regs.h:11-13 |
| 0x160020 | BXT_P_DSI_REGULATOR_CFG | vlv_dsi_regs.h:32 |
| 0x160054 | BXT_P_DSI_REGULATOR_TX_CTRL | :35 |
| 0x160018 / 0x160084 | UNNAMED in tree — cite by address | grep returned no define |

## 2. The GLK pre_enable sequence as code (7.0.0, `vlv_dsi.c:723-817`)

```
intel_dsi_wait_panel_power_cycle()
bxt_dsi_pll_disable() + bxt_dsi_pll_enable()          [GLK/BRX]
BXT_P_CR_GT_DISP_PWRON |= MIPIO_RST_CTRL              [BROXTON ONLY — skipped on GLK!]
if (!glk) intel_dsi_prepare()
MIPI_SEQ_POWER_ON + panel_on_delay + MIPI_SEQ_DEASSERT_RESET
if (glk): glk_cold_boot = glk_dsi_enable_io();        ← DEVICE_READY probe
          if (cold_boot) intel_dsi_prepare()          ← BEFORE device_ready
intel_dsi_device_ready()                              ← GLK: ULPS dance if DEVICE_READY set
if (glk && !cold_boot) intel_dsi_prepare()            ← AFTER device_ready
MIPI_SEQ_INIT_OTP
cmd-mode: MAX_RETURN_PKT + TEAR_ON + DISPLAY_ON
video-mode: msleep(20); dpi_send_cmd(TURN_ON); msleep(100); DISPLAY_ON; port_enable
backlight_enable + MIPI_SEQ_BACKLIGHT_ON
```

Notable: the `BXT_P_CR_GT_DISP_PWRON |= MIPIO_RST_CTRL` block (the 0x138090
MIPIO_RST_CTRL family — one of Phase 47's ranges) is **broxton-only** in the
tree and skipped on GLK; v8.0 already noted the REGULATOR_CFG bit15 experiment
failed because "that block is broxton-only in vlv_dsi.c, skipped on GLK".

## 3. Fix design space (ranked, ledger-compliant)

**Shape discipline:** every candidate is *sequencing-state* (control flow of
the enable path), never a bare register-value restore. All are DMI-gated
`dmi_match(DMI_PRODUCT_NAME, "82H0")`, additive, in the enable path.

### Iteration 1 (primary): fresh-device-state branch — eliminate the retained-state path
Make the resume `intel_dsi_pre_enable()` run the DSI device exactly like the
working reload path: DMI-gated, before/at `intel_dsi_device_ready()`, when
`MIPI_DEVICE_READY & DEVICE_READY` is observed set on resume (i.e., retained
state), write the plain fresh path instead of the ULPS dance:
clear ULPS_STATE_MASK + DEVICE_READY (device off), then take the
`!(DEVICE_READY)` branch (plain DEVICE_READY set) — i.e. force the
fresh-probe branch of `glk_dsi_device_ready()`, optionally also force
`glk_cold_boot=1` semantics consistently (prepare-before-device_ready) so the
whole pre_enable matches the reload-probe ordering.
- Evidence fit: only structural difference left; ULPS poke on a live-but-buggy
  GLK panel is plausible poison; reload works from DEVICE_READY=0.
- Evidence output per protocol: at-wake dump (operational rows + timeout bits)
  + eyes-on verdict.

### Iteration 2 (parameter/order): full panel power cycle inside pre_enable
If iter 1 fails: DMI-gated true panel power-cycle at resume — run
ASSERT_RESET + POWER_OFF, delay (≥ t4+ per VBT panel delays, ~300 ms),
POWER_ON + DEASSERT_RESET, then INIT_OTP + DISPLAY_ON (the exact cycle
pci-remove→re-probe produces for the panel, which the resume path halves).
Variants: delay scaling, sequence order swap.

### Iteration 3 (alternative hook): DSI-block reset before sequence
Assert the GLK MIPIO/DSI block reset at the top of pre_enable (the
`BXT_P_CR_GT_DISP_PWRON MIPIO_RST_CTRL` toggle, broxton-only in the tree but
the register exists on GLK — 0x138090 family appears in Phase 47's dump with
identical values) — drop+re-assert MIPIO_RST_CTRL before the sequence so the
DSI block starts from reset, mimicking the probe path. Risk noted: machine
evidence shows 0x138090 identical across arms, so this may be a no-op; it is
the last pre-TCON host lever.

### Iters 4-5 (spare / falsification pivot)
If 1-3 fail with X=Y held at wake and panel black → **falsification confirmed**:
mechanism is below host MMIO (panel TCON side). Write NO_CLEAN_FIX_PROOF v9.0
section + the §6 next-instrument spec. The concrete next instrument per
DSI_MMIO_DIFF §6: at-wake re-dump + panel-side probe via the reset/power rails
(GPIO 144/160 timing capture) — e.g. logic-marker instrumentation of the VBT
GPIO toggles vs the reload path.

## 4. Banned-lever compliance check

- Row 3 (0x46000+0x160018 overwrite) / row 18 (5-register batch): NOT
  re-proposed — iteration 1 writes only the DEVICE_READY/ULPS state machine as
  part of re-running the enable sequence (control flow), not the operational
  config values.
- 0x6b104 RO matching: not a lever (identical both arms).
- backlight forcing: separate bug, not the fix.
- power-well/DC levers, DMC init(false), post_disable early-return,
  msleep(300) after POWER_ON: all disproven rows, not re-proposed.
- The fix kernel keeps the dump node (0600, read-only, PLL-gated) —
  instrumentation, not a lever.

## 5. Test/deploy protocol per iteration (binding)

1. CI build on a fix branch (`fix/d330-resume-fix-itN` or the instrument
   branch), inputs `kernel_version=7.0.0-38-generic`, `ubuntu_release=resolute`.
2. sha256-verify deb on host AND device; **verify rollback deb
   (`20dc04db…9e91`) present before install**; install + reboot.
3. Boot arm dump (node live) → user-triggered suspend/resume (user reports
   verdict; scripted execution only if user re-authorizes per session) →
   at-wake dump ≤18 s → verdict + machine evidence.
4. On failure: RESUME_FIX_LEDGER row + broken dump archived to RE kit; guard
   chain green; next iteration.
5. On success: repeat cycles for DONE-01 (that is Phase 49's bar — here one
   verified working resume + guard chain + no regression is the Phase gate).

## 6. Open questions (resolved by this research)

- **Q: does pre_enable run on resume?** A: YES — D330MARK markers (v8.0). Do
  not plan around "encoder hooks skipped".
- **Q: do the VBT sequences differ resume vs reload?** A: NO — D330SEQ/ GPIO
  markers identical. Do not plan around "panel DCS init missing".
- **Q: is the operational-register diff the discriminator?** A: NO as an
  absolute — it is an at-wake transient; X=Y occurs in black states too
  (row 18, v8.0 late reads, session 1). The at-wake dump remains valuable as
  EVIDENCE but cannot be the success bar alone; the success bar is eyes-on
  (FIX-01) with the dump as corroboration.
- **Q: which part of the enable path differs from the working reload?** A:
  the retained DEVICE_READY / ULPS dance branch (§1.6). Everything else
  (PLL re-init, prepare placement, sequences, GPIOs) is identical or
  order-forced already.
- **Q: where is the falsification line?** A: §5 of DSI_MMIO_DIFF — sequencing
  reaching X=Y + holding + still black ⇒ TCON side ⇒ iters 4-5 pivot to
  honest closure + next instrument.

## Validation Architecture

Not applicable as a standard section — this phase's validation IS the
on-device protocol in §5 (user-triggered suspend/resume, eyes-on verdicts,
at-wake dumps). No runnable unit-level harness applies to a kernel panel fix;
the guard chain (ledger gate, evidence suites, kit verify) is the
machine-checkable part and is exercised every iteration.
