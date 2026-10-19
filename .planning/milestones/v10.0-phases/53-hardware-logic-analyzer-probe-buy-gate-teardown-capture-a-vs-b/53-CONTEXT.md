---
phase: 53
name: Hardware Logic-Analyzer Probe (Buy-Gate, Teardown, Capture A vs B)
status: in_progress
started: 2026-10-18
requirements: [HW-01, HW-02, HW-03, HW-04]
---

# Phase 53 Context

**Goal:** answer the three wire-level questions with a cheap logic analyzer.
Phase 51's software ladder falsified — the keep-hot teardown skip never
engaged and no kernel path re-reaches the GOP's X=Y boot state. The image
needs the GOP's firmware panel init, so the remaining instrument is a
logic analyzer on the panel flex.

## The three open wire-level questions (from `v10.0-hardware-instrument.md` §0)

1. Does GOP send anything on the DSI lanes beyond block-53's LP DCS bursts
   (`0x11`, 200 ms, `0x29`)? The unseen TCON programming would show here.
2. Does GOP toggle the PMIC rails (GPIO 144/160/145 over PMIC I2C bus 6)
   differently from the kernel's resume path?
3. Does the kernel's re-probe transmit anything at all, and how does it
   differ from boot?

## Load-bearing scope honesty

DSI HS is ~1 Gbps/lane — no buyable cheap instrument decodes it ($5k+
pro-scope capability). Accepted loss: the job is **LP DSI + I2C + rails +
HS envelope timing** (0.6 V threshold trick). If capture A shows all init
is HS, the job shrinks to the I2C-bus-only plan and the content answer
moves to static block-55 decode.

## Progress

- [x] **Buy-gate validation** — KingstVIS MIPI-DSI LP decoder confirmed real
  and shipping in the free build (portable Linux `libMIPI-DSI.so` contains
  `MIPI_DSI_LP_Analyzer` with escape-mode, TA-exit, packet parsing and
  `GenerateSimulationData`). See `53-BUY-GATE.md`.
- [ ] **User purchase authorization** — LA5016 ($238) + FPC breakout (~$5–15
  after teardown confirms pitch/pin count). U3Pro16 ($299) conditional.
- [ ] **Teardown + empirical pin ID** — battery disconnected first; GND
  continuity → rails → LP-11 pairs → behavior. No official 82H0 schematic.
- [ ] **Captures A (GOP boot), B (kernel resume), C (PMIC I2C bus 6)** —
  decoded, kit-registered, diffed per §5 mapping.
- [ ] **Findings doc + §5 verdict** — which mechanism story the evidence
  supports.

## Dependencies

Phase 51 ladder outcome (falsified → hardware probe is the documented
escalation). The purchase is user-gated.
