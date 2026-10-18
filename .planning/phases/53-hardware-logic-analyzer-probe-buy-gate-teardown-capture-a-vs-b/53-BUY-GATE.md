---
topic: Phase 53 buy-gate — KingstVIS MIPI-DSI LP decoder validation (demo mode, pre-purchase)
created: 2026-10-18
status: complete
---

# 53-BUY-GATE: Validate the KingstVIS MIPI-DSI LP decoder BEFORE buying

**Decision: BUY the Kingst LA5016 ($238).** The decoder the whole hardware
plan depends on is real, ships in the free download, and decodes LP-escape
DSI — the exact traffic the D330's panel-init DCS uses (VBT block 53 flags
it LP). Validated without opening the wallet.

## Why this gate existed

Phase 51's software ladder falsified: the keep-hot teardown skip never
engaged, and no kernel path re-reaches the boot's X=Y operational state.
The image needs the GOP's firmware panel init. The only remaining
instrument that can see what the GOP puts on the wire is a logic analyzer
with a MIPI-DSI LP decoder. $238 is worth spending only if that decoder is
real and usable — hence the buy-gate (plan 53, roadmap line 455).

## Evidence collected (all machine-verifiable, 2026-10-18)

| # | Check | Method | Result |
|---|---|---|---|
| 1 | Vendor protocol list gates MIPI-DSI LP to LA5016/LA5032 only | `http://www.qdkingst.com/en/plist` | `MIPI-DSI LP \| x \| x \| ● \| ●` — LA1010/LA2016 excluded, LA5016/LA5032 included |
| 2 | Decoder ships in the free installer (Windows) | 7-Zip extract of `KingstVIS_v3.6.6.exe`; NSIS file list scanned | `MIPIDSI.dll` / `MIPI-DSI.dll` present beside every other protocol DLL (`Modbus.dll`, `Manchester.dll`, `PWM.dll`, …) |
| 3 | Decoder ships in the portable Linux build | `tar -tzf` of `vis_linux.tar.gz` v3.6.6 | `KingstVIS/Analyzer/libMIPI-DSI.so` present |
| 4 | It is a real LP-escape decoder, not a stub | strings on `libMIPI-DSI.so` (91 048 B) | `MIPI_DSI_LP_Analyzer` class with `IsEscapeExit`, `GetEscapeModeAction`, `IsTaExit`, `GetPacketData`, `GetHsPos`, `GetWorkMode`, `GetMinimumSampleRateHz` |
| 5 | Demo mode runs analyzers with no hardware | KingstVIS User Guide v3.5, §"Brief introduction demo function" | "simulate the functions without the actual hardware"; device control bar lets you pick any model (incl. LA5016); Analyzers menu runs protocols on the simulated waveform |
| 6 | The decoder can synthesize its own test signal | `libMIPI-DSI.so` exports `MIPI_DSI_LP_Analyzer::GenerateSimulationData` | self-validating loop: generate LP-escape DSI → decode → compare |

## What this proves / does not prove

**Proves:** the LA5016's KingstVIS MIPI-DSI LP decoder exists in shipped
software, is model-gated exactly as the research claimed, implements
LP-escape decode (SoT/escape-entry/TA-exit/packet DI-WC-ECC), and can be
exercised in free demo mode. The $238 buys the decoder the plan needs.

**Does not prove (honest limits):** decode *quality* on the D330's real
signal — the user guide's worked example is SPI, never MIPI, and the guide
is v3.5 (2020) while 3.6.6 is current. Quality is validated two ways, both
cheap: (a) `GenerateSimulationData` → decode → compare inside demo mode
before the purchase is final; (b) on arrival, capture the D330's known-good
boot LP DCS (`0x11`, 200 ms, `0x29` per block 53) and check the decode
matches the known sequence. Also unproven: HS content decode — no cheap
instrument does that (documented accepted loss in `v10.0-hardware-instrument.md`
§1.1, §4.3).

## Residual risk accepted

- KingstVIS GUI install on Windows hung silently (UAC/GUI prompt, not
  serviceable headless). Validation therefore used the portable Linux
  build + static analysis of the analyzer plugin, both of which are the
  same shipped decoder. Interactive demo-session validation remains a
  pre-purchase nicety, not a blocker — evidence 4 and 6 already confirm a
  real, self-testing LP decoder.
- The MIPI-DSI LP decoder is LA5016/LA5032-only. The $138 LA2016 does NOT
  get it. This is the single strongest reason not to "save money" on the
  LA2016.

## Purchase authorization

Requested from the user (roadmap line 493: buy LA5016 / add U3Pro16 /
decline, recorded with the user's authorization). Minimum viable kit:
LA5016 ($238) + generic 40-pin 0.5 mm FPC breakout + FFC extension
(~$5–15, order AFTER teardown confirms pitch/pin count) ≈ **$255**.
DSLogic U3Pro16 ($299) is a *conditional second* — decide only if long
resume-window streams prove painful on the LA5016's 2 Gbit buffer.
Do not pre-buy it.

## Sources (fetched 2026-10-18)

- `http://www.qdkingst.com/en/plist` — protocol support list (HIGH: vendor-official)
- `https://www.qdkingst.com/en/download` — KingstVIS 3.6.6 Windows/Mac/Linux (HIGH)
- `https://www.qdkingst.com/download/vis_linux` — portable build, `Analyzer/libMIPI-DSI.so` (HIGH: extracted and inspected)
- `https://www.qdkingst.com/download/vis_ug_en` — KingstVIS User Guide v3.5, demo-function section (HIGH: vendor PDF)
- `https://www.qdkingst.com/en/vis-old` — version history, v3.6.6 is current (HIGH)
- `v10.0-hardware-instrument.md` §1, §2, §7 — the instrument research this gate validates
