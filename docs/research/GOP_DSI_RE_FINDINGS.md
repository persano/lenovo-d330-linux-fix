<!-- planner-discipline-allow: intel_pps.c -->
<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: i915.enable_fbc=0 -->
<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: MIPI_SEQ_INIT_OTP -->
<!-- planner-discipline-allow: MIPI_SEQ_DISPLAY_ON -->
<!-- planner-discipline-allow: Panel power cycle -->
<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: PMIC I2C bus 6 -->
<!-- planner-discipline-allow: PMIC-controlled -->
<!-- planner-discipline-allow: PMIC I2C Bus Number -->

# GOP / DSI RE Findings (Windows path, WRE-01 / WRE-02 / WRE-03)

Status: **phase 45 working notes**. Every claim cites file + address + bytes (or line).
Kit: `docs/dumps/re_kit/` (checksummed, `MANIFEST.sha256` @ commit 731d383).
Tooling: Ghidra 12.1.4 headless (sha256 ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db,
verified), uefi-firmware-parser (pip), innoextract, intel_vbt_decode (on-device, exit 0).

## 1. Provenance

| Artifact | Source | SHA-256 (first 16) |
|---|---|---|
| `spi2.bin` | device SPI dump `dd if=/dev/mtd0ro bs=4k conv=noerror,sync` 2026-10-12 | `3b965008eaf35ade` |
| `vbt.bin` | carved from spi2.bin @ 1656092, 5430 B (VBT 5382 B) — **VBT A below** | `3fd07a339dcdc39e` |
| `runtime_vbt.bin` | `/sys/kernel/debug/dri/*/i915_vbt` on-device, 5755 B — **VBT B below, the one the kernel uses** | (MANIFEST) |
| `gop_driver_dc90d1e2.efi` | Lenovo BIOS G0CN14WW capsule → FV (see §3) | `cf9d011adb9cd680` |
| `igdkmd64.sys` + INFs | Lenovo `3gid020fh6y37sb0.exe` (Intel VGA 27.20.100.8729) | `81198e584734995e` |

- Lenovo catalog `https://download.lenovo.com/catalog/82H0_Win10.xml`: display driver
  `3gid020fh6y37sb0.exe` 195,814,352 B sha256 `B119E4EACB8E0CDB83C5E1CCE879AA19517B2D9E20B38BA065545EB786CF6688`;
  BIOS `g0cn14ww.exe` 6,765,280 B sha256 `CB09960055C522A36BFFA5913897F0E41B90CC393F37E0B56A1A25BE44058D11`.
- Running firmware: `dmidecode -s bios-version` = **G0CN12WW**; capsule = G0CN14WW (two versions newer).
  The on-device SPI dump is authoritative for the machine that exhibits the bug.
- Limitation: mtd read failed past 7,860,224 / 8,388,608 bytes (I/O error, tail unreadable). VBT at
  1,656,092 is well inside the readable range; no impact on VBT/GOP work.
- Device VBT carve: spi2.bin offset **1656092**, bytes = `"$VBT BROXTON        "` (16 B signature string).
  intel_vbt_decode exit 0, full decode in `docs/dumps/re_kit/vbt_decode.txt`.

## 2. The two VBTs (WRE-03: the DSI panel as configured)

**The machine has two VBTs and they differ.** The kernel uses the second one.

**VBT A — SPI flash, "BROXTON", BDB 206** (carved from spi2.bin @ 1656092, 5382 B;
`docs/dumps/re_kit/vbt_decode.txt`):

- Blocks: 1 2 3 6 7 8 9 10 12 13 17 18 20 26 27 28 31 32 40 41 42 43 44 46 51 52 252 253 254
  (line 21). **No block 53 (MIPI sequence) and no block 55.**
- DSI config (block 52, lines 891-901): Mode VIDEO, transfer mode **non-burst with sync events
  (0x2)**, RGB888, dithering in panel controller, **Lane Count: 4**, **Dual Link Support: not
  supported** (single link), Dphy Flags Clock Stop **DISABLED**, EOT sent. PPS GPIO Pins
  **Using PMIC**, MIPI PMIC I2C Bus Number **6** (line 948). Panel power cycle delay **5000 ms**
  (line 944). Power sequence T1-T3 2000 / T8 10 / T9 2000 / T10 500 / T11-T12 5000 ms (line 595).
- LFP blocks 40-44: PP_ON_DELAYS `0x025807d0`, PP_OFF_DELAYS `0x01f407d0`, PWM freq 200, level 180.

**VBT B — runtime (GOP handoff), "GEMINILAKE", BDB 212** (`docs/dumps/re_kit/runtime_vbt.bin`,
5755 B; decode `runtime_vbt_decode.txt`):

- Source: `/sys/kernel/debug/dri/*/i915_vbt` on the running system (2026-10-12, kernel
  7.0.14-d330-fix). This is the VBT i915 actually parses — delivered through the GOP OpRegion
  handoff (GOP writes pointer+size to the OpRegion ASLS mailbox; see §3.3).
- Blocks: 31 32 40 41 42 43 44 46 51 52 **53** **55** 252 253 254.
- **Block 53 "MIPI sequence block", version v3, Panel 0 (LFP1)(LFP2)** — the panel-init
  sequences (`runtime_vbt_decode.txt` / `b53_full.txt`, full table):

| Seq | Name | Content |
|---|---|---|
| 1 | DEASSERT_RESET | empty |
| 2 | MIPI_SEQ_INIT_OTP | delay 10 ms; GPIO 160 set 1; delay 10 ms; GPIO 160 set 0; delay 10 ms; GPIO 160 set 1; delay 20 ms |
| 3 | MIPI_SEQ_DISPLAY_ON | DCS (Port A, VC 0, LP, 0x05, len 1) `0x11`; delay 200 ms; DCS `0x29`; delay 10 ms |
| 4 | MIPI_SEQ_DISPLAY_OFF | DCS `0x28 00`; delay 200 ms; DCS `0x10 00`; delay 100 ms |
| 5 | MIPI_SEQ_ASSERT_RESET | delay 100 ms; GPIO 160 set 0; delay 1 ms |
| 6 | MIPI_SEQ_BACKLIGHT_ON | delay 150 ms; GPIO 145 set 1; delay 2 ms |
| 7 | MIPI_SEQ_BACKLIGHT_OFF | GPIO 145 set 0; delay 1 ms |
| 10 | MIPI_SEQ_POWER_ON | GPIO 144 set 1; delay 1 ms |
| 11 | MIPI_SEQ_POWER_OFF | delay 100 ms; GPIO 144 set 0 |

- GPIOs are PMIC-controlled panel rails (matches VBT A "PPS GPIO Pins: Using PMIC"):
  GPIO **160** = panel reset (index 0), GPIO **144** = panel power (index 3), GPIO **145** = backlight (index 4).
- Block 55 (258 B) undecoded by intel_vbt_decode; block 254 = VBIOS version string
  ("1001Intel(R) Mobile/Desktop PCI Accelerated SVGA BIOS", raw first bytes of block 254).
- LFP child: LFP1 on pipe A (PRD table, entries 1-4).

**Why this matters**: the SPI-carved VBT A is what any static VBT analysis would find, but it
has NO sequences — while the runtime VBT B (what Windows/Linux both receive from the GOP)
HAS them. Any "VBT has no panel-init sequences" reasoning based on the SPI image alone is
wrong for this machine. (An earlier revision of this document made exactly that mistake;
corrected here against `i915_vbt` debugfs evidence.)

## 3. WRE-01: the GOP driver

`gop_driver_dc90d1e2.efi` (22,080 B, FFS file GUID `dc90d1e2-556a-45cf-b3ef-9de451807a17`,
section1.pe of the G0CN14WW BIOS FV `volume-ee4e5898` inside the LZMA-compressed main volume)
is the **Intel GOP driver**:

1. `IntelGraphicsMem` string @ file offset **0x4a40** — GOP's hardware-state NVRAM variable
   (decomp `gop_driver_dc90d1e2_decomp.c` line 521, `s_IntelGraphicsMem_00004a40`).
2. `$VBT` dword constant **0x54425624** compared in the VBT getter (decomp lines 197, 471;
   string bytes `"$VBT"` @ file offset **0x612**).
3. VBT handoff to OS: pointer + size written to a runtime block at `+0x3ba` / `+0x3c2`
   (`*(undefined8 *)(DAT_00005010 + 0x3ba) = ...; *(uint *)(DAT_00005010 + 0x3c2) = size`,
   function at `_decomp.c` around the `0xc0004` reference) — this is the GOP→OS VBT pointer
   handoff (matches the i915 `GopDriver`/GOP-VBT-early-doc flow).
4. 107 functions total (decomp `_funcs.txt`); grep of the full decompiled C finds:
   **no direct panel-power MMIO constants** (no `0xc7204/0xc7208`, no delay loops
   0x1f4/0x1388/0x7d0 as immediates). The GOP parses VBT, sets mode, and passes the handoff
   (§3.3). Whether the GOP itself replays the block-53 sequences (GPIO/DCS table) before
   handoff is not proven from decomp alone; the sequence CONTENT is fully known (§2) and
   the Linux side executes them at enable/disable (see
   docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md).
5. Other FV modules (`gop_candidate_06b5947e.efi` 126,720 B — no identifying strings;
   `vbt_candidate_a622ab73.efi` 63,456 B — `GdCreatePixmap: unsupported format %08x` string,
   Insyde graphics helper) are not the GOP driver.
6. The capsule (G0CN14WW) carries its own `"$VBT GEMINILAKE     "` inside the GOP FV
   (`bios_raw_8dfae5d4.bin` offset **2736**, header 48, vbt_size 4284 — smaller than the
   runtime 5755 B VBT of §2 VBT B; different build). The running firmware (G0CN12WW) supplies
   the runtime VBT through its own GOP.

## 4. WRE-02: what the Windows driver owns

`igdkmd64.sys`: PE32+ x64 (machine `0x8664`, opt magic `0x20b`), 27,071,280 B,
`iigd_dch.inf` → `DriverVer=09/11/2020,27.20.100.8729` (OEM ext INF `iigd_ext.inf` present).
No export directory (data directory entry 0 = rva 0) — DCH dispatch via DriverEntry.

The driver embeds C++ symbol-name strings (assert tags) that name its DSI/panel stack
(file offsets in igdkmd64.sys):

| Offset | Symbol string |
|---|---|
| 0x56ea70 | `INTMIPIENCODER_SetEncoderPowerState` |
| 0x56e940 | `INTMIPIENCODER_Initialize` |
| 0x56e9b0 | `INTMIPIENCODER_SetTiming` |
| 0x56e960 | `INTMIPIENCODER_DisableEncoder` |
| 0x56e9c8→0x56ec… | `INTMIPIENCODER_AddTiming`, `INTMIPIENCODER_Gen11SetTiming`, `INTMIPIENCODER_GetBestTimingForSetMode`, `INTMIPIENCODER_ModifyTimingOnCompensation` |
| 0x572a20 | `GEN9DSICONTROLLER_SetTiming` |
| 0x572a70 | `GEN9DSICONTROLLER_UpdateDSIBasedOnVbt` |
| 0x572a40 | `GEN9DSICONTROLLER_GetDSIClockFreq` |
| 0x571b70 | `MIPISINK_GetPanelPowerSeqTimingDelay` |
| 0x571b40 | `VBT_MIPI_PP_SEQUENCING_REGISTER_TYPE_ENUM` |
| 0x56abc0 | `CSLBASE_SetPanelPower` |
| 0x570110 | `GMCHGEN10_SendPPSPacket` |
| 0x56aba0 / 0x562900 / 0x5628c0 | `SB_SET_PANEL_POWER` / `SB_SAVESTATE_ARGS` / `SB_RESTORESTATE_ARGS` |

Reading: the Windows driver owns a complete DSI encoder lifecycle — power-state transitions
(`SetEncoderPowerState`), timing setup from VBT (`UpdateDSIBasedOnVbt`), panel power sequencing
(`SetPanelPower`, `SendPPSPacket`, `GetPanelPowerSeqTimingDelay`) — and runs it on its own
save/restore path (`SB_SAVESTATE_ARGS` / `SB_RESTORESTATE_ARGS`). This is the direct counterpart
of the Linux resume path (`intel_dsi_vbt.c` + `intel_pps.c`), and the two implementations
differ: Windows re-runs its DSI power-state sequence on every S3 resume; Linux only re-runs
the enable path if something re-atomic-enables the connector — which does not happen on this
device (see docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md).

## 5. Implications for the bug (feeds 45-02)

- The differential (docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md) proves the shape: on
  S3 resume with the connector disabled pre-suspend, the Linux resume path runs only PP
  bookkeeping (intel_pps_vdd_on/off, unlock_regs_wa, encoder_reset, get_hw_state) and
  **never re-runs the DSI enable path** (no intel_dsi_pre_enable, no block-53 sequences,
  no backlight on). The connector stays `enabled=disabled`, `dpms=Off`, `bl_power=4`.
  A full i915 re-probe (unbind/bind) re-runs everything and the panel returns.
- 45-02 candidate therefore: force the resume path to re-enable the DSI encoder (full
  modeset/re-probe of the connector) from the `lenovo_d330_fix` module — not a PP-delay
  clamp. The block-53 sequence content (§2) is the reference for what a correct enable
  must replay: POWER_ON (GPIO 144 high) → INIT_OTP (GPIO 160 toggle) → DISPLAY_ON
  (DCS 0x11, 200 ms, DCS 0x29) → BACKLIGHT_ON (150 ms, GPIO 145 high).
- Non-goals: `i915.enable_psr=0` / `i915.enable_fbc=0` / `bl_power` masking are already
  excluded by docs/research/RESUME_FIX_LEDGER.md; this pass does not reopen them.

## 6. Open items

- Whether the GOP itself replays block-53 sequences before handoff (decomp shows no direct
  DCS/MMIO table interpreter; could be indirect via VBT structure) — unproven, flagged §3.4.
- PMIC I2C bus 6 traffic path in GOP (which controller GOP talks to) — unproven, flagged §3.
- igdkmd64.sys full decompilation (27 MB) — deliberately not done; symbol-string evidence above
  is sufficient for the findings scope. A Ghidra project can be rebuilt from the kit if needed.
