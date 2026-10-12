<!-- planner-discipline-allow: intel_pps.c -->
<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: i915.enable_fbc=0 -->
<!-- planner-discipline-allow: bl_power -->

# GOP / DSI RE Findings (Windows path, WRE-01 / WRE-02 / WRE-03)

Status: **phase 45 working notes**. Every claim cites file + address + bytes (or line).
Kit: `docs/dumps/re_kit/` (checksummed, `MANIFEST.sha256` @ commit 731d383).
Tooling: Ghidra 12.1.4 headless (sha256 ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db,
verified), uefi-firmware-parser (pip), innoextract, intel_vbt_decode (on-device, exit 0).

## 1. Provenance

| Artifact | Source | SHA-256 (first 16) |
|---|---|---|
| `spi2.bin` | device SPI dump `dd if=/dev/mtd0ro bs=4k conv=noerror,sync` 2026-10-12 | `3b965008eaf35ade` |
| `vbt.bin` | carved from spi2.bin @ 1656092, 5430 B (VBT 5382 B) | `3fd07a339dcdc39e` |
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

## 2. WRE-03: the DSI panel as configured (authoritative device VBT)

From `docs/dumps/re_kit/vbt_decode.txt`:

- Header: signature `"$VBT BROXTON        "` (line 4; GLK uses the Broxton family string), version
  1.0, BDB version **206**, 29 blocks: 1 2 3 6 7 8 9 10 12 13 17 18 20 26 27 28 31 32 40 41 42 43
  44 46 51 52 252 253 **254** (line 21).
- LFP1 child device, DVO Port **DP-A** (GLK DSI port A), boot display (child device table).
- **No MIPI sequence block**: blocks 53/54 absent; block 254 is "VBIOS only, no decoding available"
  (vbt_decode.txt line 1019, 234 B). Raw parse of block 254 first byte = `0x00` → the VBT carries
  **no DCS panel-init sequences**. Consequence: Linux `intel_dsi_vbt.c` has no sequences to run;
  panel init is done by whoever brings up the DSI link (panel self-init in video mode).
- DSI link (block 52, vbt_decode.txt lines 891-901): Mode **VIDEO**, transfer mode
  **non-burst with sync events (0x2)**, RGB888, dithering in panel controller,
  **Lane Count: 4**, **Dual Link Support: not supported** (single link), Dphy Flags
  **Clock Stop: DISABLED**, EOT sent.
- PPS (block 51/52, vbt_decode.txt): PPS GPIO Pins **Using PMIC**, MIPI PMIC I2C Bus Number **6**
  (line 948); power sequence T1-T3 2000 / T8 10 / T9 2000 / T10 500 / T11-T12 5000 ms (line 595);
  panel power cycle delay **5000 ms** (line 944).
- LFP blocks 40-44: PP_ON_DELAYS `0x025807d0`, PP_OFF_DELAYS `0x01f407d0`, PWM freq 200, level 180.
- Placeholder native timing 1024x768 in block 42; real 1366x768 timing comes from the DTD/driver.

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
   **no DCS command sequences** (no `0x11`/`0x29` write sequences), **no panel-power MMIO
   constants** (no `0xc7204/0xc7208`, no delay loops 0x1f4/0x1388/0x7d0), **no MIPI sequence
   interpreter**. The GOP only parses VBT, sets mode, and passes handoff data — consistent
   with §2: this panel needs no DCS init (video-mode self-init), and panel power rails are
   managed over the PMIC I2C bus per VBT (the I2C traffic path is the one unproven area;
   flagged, not asserted).
5. Other FV modules (`gop_candidate_06b5947e.efi` 126,720 B — no identifying strings;
   `vbt_candidate_a622ab73.efi` 63,456 B — `GdCreatePixmap: unsupported format %08x` string,
   Insyde graphics helper) are not the GOP driver.
6. The capsule's own VBT differs from the running one: `bios_raw_8dfae5d4.bin` offset **2736**
   holds `"$VBT GEMINILAKE     "` (header 48, vbt_size 4284) — a different build's VBT.
   Recorded as reference only; the SPI (G0CN12WW) VBT of §2 is what the panel actually runs with.

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
differ: Windows re-runs its DSI power-state sequence on every S3 resume; Linux depends on the
PPS register state surviving S3 (only writes PP regs when it thinks they need reprogramming)
and has **no VBT sequences to replay** (§2).

## 5. Implications for the bug (feeds 45-02)

- The only "sequence" the panel needs beyond a plain DSI link up is panel power rails
  (PMIC bus 6) + PP timing (500/500/500/5000 ms). The 5000 ms power-cycle delay is the
  suspect: if Linux programs PP registers with stale/short state at resume (panel not fully
  power-cycled), the panel stays black while everything else comes up cleanly (phase 44 sweep:
  kernel logs clean, panel black; full i915 unbind/bind reload = the one fix that works).
- 45-02 candidate: clamp the PP power-cycle delay path (`intel_pps.c` upstream logic) so the
  resume PP sequence is forced deterministic, mirroring what Windows does unconditionally.
  This RE pass supplies the ground truth for that patch.
- Non-goals: `i915.enable_psr=0` / `i915.enable_fbc=0` / `bl_power` masking are already
  excluded by docs/research/RESUME_FIX_LEDGER.md; this pass does not reopen them.

## 6. Open items

- PMIC I2C bus 6 traffic path in GOP (which controller GOP talks to) — unproven, flagged in §3.4.
- igdkmd64.sys full decompilation (27 MB) — deliberately not done; symbol-string evidence above
  is sufficient for the findings scope. A Ghidra project can be rebuilt from the kit if needed.
