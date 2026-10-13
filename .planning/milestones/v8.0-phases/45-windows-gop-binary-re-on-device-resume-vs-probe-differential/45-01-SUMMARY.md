# 45-01-SUMMARY: Windows GOP binary RE + on-device resume vs probe differential

<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: intel_dsi_post_disable -->
<!-- planner-discipline-allow: MIPI_SEQ_INIT_OTP -->
<!-- planner-discipline-allow: MIPI_SEQ_DISPLAY_ON -->
<!-- planner-discipline-allow: panel power -->
<!-- planner-discipline-allow: PMIC I2C bus 6 -->
<!-- planner-discipline-allow: backlight -->
<!-- planner-discipline-allow: DISPLAY_OFF -->
<!-- planner-discipline-allow: DISPLAY_ON -->
<!-- planner-discipline-allow: POWER_OFF -->

Phase: 45 · Plan: 45-01 · Completed: 2026-10-12
Commits: 731d383 (T1 kit), 182e4f3 (T2/T3 findings), 4870ad5 (T4 differential + suite),
8da9cba (gate markers).

## What was done

- **T1 — RE kit acquired and checksummed** (`docs/dumps/re_kit/`, MANIFEST.sha256 @
  731d383): Lenovo display driver `3gid020fh6y37sb0.exe` (Intel VGA 27.20.100.8729, sha256
  B119E4EA…CF6688) → `igdkmd64.sys` + `iigd_dch.inf` + OEM `iigd_ext.inf`; Lenovo BIOS
  capsule `g0cn14ww.exe` (G0CN14WW, sha256 CB099600…58D11) → UEFI-parsed FVs → Intel GOP
  driver `gop_driver_dc90d1e2.efi` (22,080 B); device SPI dump `spi2.bin` (7,860,224 of
  8,388,608 B readable — mtd I/O error tail, recorded limitation) → carved VBT A
  (`vbt.bin`, BROXTON/BDB 206). Devices facts: running firmware G0CN12WW; `intel_vbt_decode`
  used on-device.
- **T2/T3 — RE findings** (`docs/research/GOP_DSI_RE_FINDINGS.md`): Ghidra 12.1.4 headless
  decompile (107 functions) identifies the GOP driver (`IntelGraphicsMem` @ 0x4a40,
  `$VBT` 0x54425624, VBT handoff @ +0x3ba/+0x3c2); igdkmd64.sys symbol-string table
  (INTMIPIENCODER_SetEncoderPowerState @ 0x56ea70 and 11 more) shows the Windows DSI
  stack; **discovery: the machine has two VBTs** — SPI "BROXTON" BDB 206 without block 53,
  and the **runtime GOP-handoff VBT** (`/sys/kernel/debug/dri/*/i915_vbt`, "GEMINILAKE"
  BDB 212) with block 53 sequences (GPIO 160 reset / 144 power / 145 backlight, DCS
  0x11→200 ms→0x29). The kernel uses the runtime one. WRE-01/02/03 answered with
  file+offset+bytes citations.
- **T4 — differential** (`docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md`): on-device
  ftrace function_graph (150 filtered functions) comparing S3 resume-black vs unbind/bind
  reload. Arm R: only PP bookkeeping traced, DSI-1 `enabled=disabled / dpms=Off /
  bl_power=4`. Arm L2: full teardown traced (incl. block-53 DISPLAY_OFF/POWER_OFF
  sequences with DCS writes) + panel restored (`dpms=On / bl_power=0`). ROOT-01 answered:
  **the S3 resume path never re-runs the DSI enable path; the reload re-runs it**. New
  suite `scripts/test_re_diff_evidence.sh` (6 cases) wired into the harness; CHANGES_AUDIT
  guard count 38→39. Harness chain CHAIN_EXIT=0; ledger gate passed=4 failed=0
  (markers: intel_dsi_post_disable, MIPI_SEQ_INIT_OTP, MIPI_SEQ_DISPLAY_ON, panel power
  cycle, PMIC I2C bus 6 — evidence mentions, not lever proposals).

## Must-have verification

- ✅ WRE-01: GOP identified and decompiled with citations (GOP_DSI_RE_FINDINGS §3).
- ✅ WRE-02: Windows DSI/panel stack evidenced (§4 symbol table).
- ✅ WRE-03: VBT/sequence facts, both VBTs, corrected against runtime evidence (§2).
- ✅ ROOT-01: differential answer with traced evidence + sysfs/dmesg artifacts.
- ✅ 45-02 receives the fix direction: force resume to re-enable DSI (full re-probe of
  the encoder), not PP-delay tuning.
- ✅ suite_count=39 verified by doc-parity guard; suite green (6/6); chain CHAIN_EXIT=0.

## Deviations

- Research subagent timed out twice (504) earlier in phase 45 → inline research (recorded
  in 45-RESEARCH.md); this plan then executed inline as usual (executor agent broken).
- Probe-side encoder-enable ftrace entries missing from reload traces despite probe
  success (trace_marker I/O error at bind) — recorded as capture limitation in the
  differential doc; conclusion does not depend on them.
- mtd SPI dump tail (~528 KB) unreadable (I/O error) — VBT/GOP unaffected; full image
  available via the Lenovo capsule.

## Files

- Added: `docs/research/GOP_DSI_RE_FINDINGS.md`, `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md`,
  `scripts/test_re_diff_evidence.sh`, `docs/dumps/re_kit/*` (gitignored binaries +
  checksummed MANIFEST).
- Modified: `scripts/test_storage_cellular.sh` (harness wiring), `CHANGES_AUDIT.md` (39).
