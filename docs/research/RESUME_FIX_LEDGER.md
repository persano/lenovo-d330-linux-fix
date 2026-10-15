# Resume Fix Ledger — Disproven Levers (Binding)

This ledger is **binding for every phase plan** in this repo: no phase plan or
summary may re-propose a lever listed here as a fix for the D330 (82H0) resume
black screen. Each row records one *distinct* disproven lever: what was tried
(or proposed by the community), the one-line disproof, and where the evidence
lives. The machine table below is parsed by `scripts/test_pitfalls_ledger.sh`
(alias regexes, row count, cell shape); that suite is wired into the test
harness, so re-proposing a banned lever in a plan or summary fails the build.

## Scan allowlist

The gate skips these files when scanning (they legitimately *document* the
levers; they are the disproof record, not fix proposals). Skip is silent for an
allowlisted file that does not exist yet.

- `RESUME_FIX_LEDGER.md` (this ledger)
- `DISPLAY_RESUME_CCS_MODIFIER.md`
- `DSI_RESUME_TRACE_ANALYSIS.md`
- `COMMUNITY_FINDINGS.md`
- `RESUME_CAPTURE_PROTOCOL.md`

Other `docs/research/*.md` files and every `*-PLAN.md` / `*-SUMMARY.md` under
`.planning/phases/` are scanned. A scanned file may exempt one exact string
with a marker line:

```
<!-- planner-discipline-allow: <exact string the ledger row would match> -->
```

Exemptions are per exact string, per file. Never widen them wholesale; if a new
hit appears, fix the text or add a narrow marker with a reason.

## Proven bar (not a lever)

**Corrected 2026-10-13 (45-02, eyes-on):** the only recovery that has ever restored a
visible image is a **full reboot**. The full i915 unbind/bind reload of `0000:00:02.0`
(`system-sleep` hook `lenovo-d330-display-resume.sh`) restores *sysfs* state
(`dpms=On`, `bl_power=0`) but **not the visible image** — the "reload works" claim in
older phases was sysfs-only evidence and was myth-busted with human eyes-on tests
(45-02 iteration 2). Bare PCI reset, remove+rescan, module unloading and every lighter
lever below do **not** recover the panel. A clean resume fix must therefore make the
kernel's own resume path restore a *visible* panel — sysfs state alone proves nothing.

## Corrected VBT claim (do not re-chase the stale note)

Older notes claimed "i915 has no panel-power / backlight GPIO on GLK because
`gpio_panel`/`gpio_backlight` are always NULL". That claim is **superseded**:
the `intel_dsi` fields are indeed NULL on GLK, but the VBT **MIPI sequence
elements** drive GPIO 144 (power), 145 (backlight) and 160 (reset/OTP) directly
via `mipi_exec_gpio()` → `bxt_gpio_set_value()` → `soc_gpio_set_value()`, with
identical values on the black-resume and working-reload paths. i915 *does*
drive the panel pins on Gemini Lake; "wire up the missing GPIO fields" is not a
fix. Evidence: `DSI_RESUME_TRACE_ANALYSIS.md` §"i915 *does* drive the panel
GPIOs on GLK"; correction also recorded in
`DISPLAY_RESUME_CCS_MODIFIER.md` §"Resume vs reload" (**Correction:** note).

## Lever rows: 30

<!-- LEDGER-LEVERS-START -->
| # | Lever (canonical) | Alias regex (ERE, case-insensitive) | Disproof one-liner | Evidence |
|---|-------------------|--------------------------------------|--------------------|----------|
| 1 | PPS/TCON power-cycle timing clamp (`intel_pps.c`) | `intel_pps\.c\|PP_CONTROL\|TCON power-cycle` | wrong subsystem (eDP); VBT already reports a 500 ms power cycle; legacy PPS `0xc7204` runs and reads identical cold vs resume | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) |
| 2 | D-PHY `exit_zero_cnt` quirk / `HS_TX_TIMEOUT` retuning | `exit_zero_cnt\|HS_TX_TIMEOUT` | retune left the registers matching cold boot and the screen stayed black | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) |
| 3 | DSI-SoC register mismatch vs GOP (forced live register diff) | `register mismatch\|forced live` | the full cold-vs-resume register diff was forced live onto the black state with no effect — not a static register value | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) + §Exhaustive register comparison |
| 4 | `CDCLK_CTL` / DSI-PHY value mismatch live overwrite | `CDCLK_CTL\|0x160018` | written live on the black-resume state (`0x46000`, `0x160018`), no effect; CDCLK frequency identical working vs black | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry); DSI_RESUME_TRACE_ANALYSIS.md §Ruled out by these traces |
| 5 | DCS re-send after video enable | `DCS re-send` | re-sending DCS after video enable did not restore the panel | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) |
| 6 | DSI regulator / MIPI-IO power (`BXT_P_DSI_REGULATOR_CFG`, broxton-only block) | `BXT_P_DSI_REGULATOR_CFG\|DSI regulator\|0x160054` | the regulator block is `broxton`-only in `vlv_dsi.c` and is skipped on GLK; forcing `0x138090`/`0x160020`/`0x160054`/`0x46080`/`0x161000` does nothing | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) + §vlv_dsi.c experiments |
| 7 | `0x138090` as an enabled/disabled state marker | `0x138090` | reads `0` in the working console state and `0xb` after the working reload, so no simple value distinguishes working from broken | DSI_RESUME_TRACE_ANALYSIS.md §Ruled out by these traces |
| 8 | DSI PLL math / clock-gating "chicken" registers | `DSI PLL math\|BXT_DSI_PLL_CTL` | the differing registers are `GEN9_CLKGATE_DIS_*`/`CHICKEN`/DE-PLL control, not PLL ratios; `BXT_DSI_PLL_CTL` reads `0x132` on both paths | DSI_RESUME_TRACE_ANALYSIS.md §Ruled out by these traces + §Reload vs resume |
| 9 | Post-resume CRTC read-state lever (trust late CRTC reads) | `CRTC read\|readout path` | a CRTC reading taken minutes after resume is meaningless (flaky `enable=yes/no`, KDE idle blanking); the readout path itself decides "still enabled" and skips re-init — that is the bug, not a fix | DSI_RESUME_TRACE_ANALYSIS.md §Ruled out by these traces + §Result 3 |
| 10 | Suspend depth choice (`deep` vs `s2idle`) | `mem_sleep\|suspend depth` | both `deep` (S3) and `s2idle` resume black; s2idle additionally leaves the backlight off (`bl_power=4`) and re-enabling it gives a lit-but-blank panel | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) + §Suspend depth and panel power + NO_CLEAN_FIX_PROOF.md §1 iteration 3 |
| 11 | Keep the panel powered (early-return from `intel_dsi_post_disable`) | `early-return from\|keep the panel powered\|intel_dsi_post_disable` | still black, so the panel does not survive suspend even when i915 leaves it alone | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) + §Suspend depth and panel power + §vlv_dsi.c experiments |
| 12 | PMIC on I2C bus 6 (GOP-programmed, i915-missing) | `PMIC\|I2C bus 6` | no Linux I2C client exists on bus 6 and the GOP binary has no I2C/PMIC MMIO or strings — not the cause | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) + §GOP reverse engineering |
| 13 | `modprobe -r i915` after resume | `modprobe -r` | the module stays "in use" (~28 refs) and cannot be unloaded; the lower-level PCI unbind/bind is the working alternative | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) |
| 14 | `glk_cold_boot` ordering force in `intel_dsi_pre_enable()` | `glk_cold_boot` | forced to `0` on `82H0`, resume still black — a correlate, not the cause | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry); DSI_RESUME_TRACE_ANALYSIS.md §Reload vs resume |
| 15 | Probe-style full display-core init (`intel_power_domains_init_hw(display, false)`) | `intel_power_domains_init_hw\|probe-style` | trips repeated `WARNING: display/intel_dmc.c:701 at assert_dmc_loaded` and gives no panel; the display core is already power-cycled by every S3 | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry); DSI_RESUME_TRACE_ANALYSIS.md §A full display power cycle |
| 16 | `drm.debug` / dyndbg tracing of the i915 display path | `drm\.debug\|dyndbg` | writes accepted but zero `[drm:...]` lines land and `dynamic_debug/control` has no `vlv_dsi` sites; only unconditional `pr_err` markers produce output | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry); DSI_RESUME_TRACE_ANALYSIS.md §pr_err marker tracing |
| 17 | Bare PCI reset / `remove`+`rescan` recovery | `echo 1 > .*reset\|rescan` | bare `reset` does not recover and fully powers the panel off; `remove`+`rescan` does not recover and hung the box; only the i915 unbind/bind reload works | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories (do not retry) |
| 18 | Forced MIPI register batch (`MIPI_HS_TX_TIMEOUT`, `MIPI_DPHY_PARAM`, `MIPI_CLK_LANE_SWITCH_TIME_CNT`, `MIPI_HIGH_LOW_SWITCH_COUNT`, `MIPI_INTR_EN`) | `MIPI_HS_TX_TIMEOUT\|MIPI_DPHY_PARAM\|MIPI_CLK_LANE_SWITCH_TIME_CNT\|MIPI_HIGH_LOW_SWITCH_COUNT` | registers then match cold boot byte-for-byte but the screen stays black — five forced registers, one disproven lever | DISPLAY_RESUME_CCS_MODIFIER.md §vlv_dsi.c experiments tried on-device |
| 19 | `msleep(300)` after `MIPI_SEQ_POWER_ON` | `msleep\(300\)` | did not help vs the ~1 ms VBT `panel_on_delay` | DISPLAY_RESUME_CCS_MODIFIER.md §Suspend depth and panel power are not the cause + §vlv_dsi.c experiments |
| 20 | Panel power-cycle + `MIPI_SEQ_INIT_OTP`/`MIPI_SEQ_DISPLAY_ON` re-send (incl. the disproven DMI-gated pre-enable patch) | `MIPI_SEQ_INIT_OTP\|panel power cycle\|panel power-cycle` | the early sequences transmit over a DSI link that is not ready, the modeset fails and the CRTC is left disabled; the panel already power-cycles across suspend/resume | DISPLAY_RESUME_CCS_MODIFIER.md §vlv_dsi.c experiments; DSI_RESUME_TRACE_ANALYSIS.md §Disproven patch: DSI panel power cycle on resume |
| 21 | Display-server brute force (`xrandr` off/on reset) | `xrandr` | X11-only (fails on Wayland/Plymouth/console) and cannot wake a kernel that failed S0ix | COMMUNITY_FINDINGS.md §2.2 Brute-Force X11 Display Reset |
| 22 | Sleep-target masking (`systemctl mask sleep/suspend/...`) | `systemctl mask\|sleep\.target` | the device can never sleep — battery drain and thermal buildup, not a fix | COMMUNITY_FINDINGS.md §2.3 Sleep Target Masking Workarounds |
| 23 | Kernel param `i915.enable_psr=0` | `enable_psr=0` | community suggestion for PSR hangs; no on-device or upstream evidence it fixes the D330 resume (panel black with PSR irrelevant to the traced host-identical state) | COMMUNITY_FINDINGS.md §2.4 Kernel Boot Parameters & Driver Flags |
| 24 | Kernel param `i915.enable_fbc=0` | `enable_fbc=0` | community suggestion for visual corruption; addresses corruption, not the resume-black failure | COMMUNITY_FINDINGS.md §2.4 Kernel Boot Parameters & Driver Flags |
| 25 | Kernel param `i915.enable_dpcd_backlight=0` | `enable_dpcd_backlight=0` | community suggestion for eDP DPCD backlight; the D330 panel is DSI, and backlight is a separate second bug | COMMUNITY_FINDINGS.md §2.4 Kernel Boot Parameters & Driver Flags; DISPLAY_RESUME_CCS_MODIFIER.md §Backlight is a second, separate bug |
| 26 | Keep the display power well / DC on across suspend (`i915.disable_power_well=1 i915.enable_dc=0`) | `disable_power_well\|enable_dc=0` | still resumes black; disabling i915's display power management does not save the panel | DISPLAY_RESUME_CCS_MODIFIER.md §Suspend depth and panel power are not the cause |
| 27 | Backlight re-enable as the black-screen fix | `bl_power\|actual_brightness` | forcing the backlight on shows the panel backlit but still blank — a separate second bug, not the missing image | DISPLAY_RESUME_CCS_MODIFIER.md §Backlight is a second, separate bug; DSI_RESUME_TRACE_ANALYSIS.md §Backlight is a second, separate bug |
| 28 | Deferred atomic full DSI encoder cycle post-resume (`disable_all` → `commit_duplicated_state`, 82H0-gated quirk) | `disable_all\|commit_duplicated_state` | the cycle ran and traced (`intel_dsi_disable` 35 ms → `post_disable` → `pre_enable`, "encoder re-enabled", `bl_power=0`, `brightness=640`) and the panel was still lit-black with eyes on — re-running the enable path on the living driver does not produce an image | NO_CLEAN_FIX_PROOF.md §1 iteration 1 + §3; RESUME_VS_RELOAD_DIFFERENTIAL.md §Iteration log |
| 29 | Post-resume i915 re-probe / rebind as a recovery (service or manual module rebind; incl. the unbind/bind reload) | `rebind` | the re-probe ran (`reprobe done rc=0`, module reloaded) and the panel went fully black; manual rebind also left it black — the rebind restores sysfs state, never the visible image; the "rebind recovers the panel" claim was myth-busted with eyes-on tests (45-02) | NO_CLEAN_FIX_PROOF.md §1 iteration 2 + §2; RESUME_VS_RELOAD_DIFFERENTIAL.md §Iteration log |
| 30 | v9.0 iteration 1: DMI-gated (82H0) clear of retained DSI DEVICE_READY + ULPS state before the GLK cold-boot probe in pre_enable, forcing the resume enable path onto the fresh-probe branch (reload ordering; ULPS dance skipped) | `ULPS_STATE_MASK` | CI kernel 7.0.14-d330-fix sha 43b2e7c2…8932 deployed behind a verified rollback (d47 dump kernel ba47df8d…87be); one rtcwake 45 s session (user-authorized scripted trigger); eyes-on verdict verbatim: "Still black" (user); at-wake dump (wake+1 s, 7296 records, 0 skipped) shows the SAME broken operational signature as the unpatched session-2 pair — 0x6b010 003fffff→0000b8ea, 0x6b044 0000001d→0000001e, 0x6b080/0x6b098 09051003→0a051003, 0x6b088 0022000f→0014000c, 0x160018 00000115→00000001, 0x6b004 W1C 00080000→40200000 — while 0x6b000 DEVICE_READY and 0x160084 read identical to boot. The enable path ran the reload-identical branch and the panel stayed black: the retained-DEVICE_READY/ULPS-dance divergence is falsified as the sole cause. Next rung (§48-RESEARCH ladder): full panel power cycle inside pre_enable (iter 2) | 48-01-SUMMARY.md; 48-02-SUMMARY.md; 48-03-PROGRESS-it1.md; docs/dumps/re_kit/dsi_regs_diff_it1.txt; it1 dumps (boot f104496e…fcf0 / resume 52bd720c…0e62) |
<!-- LEDGER-LEVERS-END -->

Row-count note: 30 distinct levers from the three source docs plus the 45-02
iteration closure and the v9.0 phase-48 iterations (the roadmap bar is 22; the
honest enumeration lands above it — no padding, no merging below
distinctness). Cross-doc duplicates (CDCLK, force-init, panel power-cycle,
early-return, glk_cold_boot, backlight) are merged into single rows carrying
every evidence link; the forced-MIPI-register batch is one row.
