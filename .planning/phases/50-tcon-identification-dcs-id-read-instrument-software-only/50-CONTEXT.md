# Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only) - Context

**Gathered:** 2026-10-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Identify the D330 panel's TCON controller (or prove the software read path dead) using only
the running kernel: extend the existing `i915_dsi_regs` dump node with an `echo 2` DCS
ID-read trigger (0x04 / 0xDA / 0xDB / 0xDC + generic 0x83, LP mode, VC 0, port A), capture
ID reads in both operational states (boot X=Y, black-resume X=Z), rule the I2C sideband in
or out with a same-session sweep + tracepoints, and correct DSI_MMIO_DIFF §6's 0x6b004
register label. Deliverable: `docs/research/TCON_IDENTIFICATION.md` (identity or proven
dead end + I2C conclusion + datasheet-gated candidate notes), kit-registered captures,
corrected DSI_MMIO_DIFF §6, ledger gate green. Feeds Phase 51 (the E3 discriminator is this
same read at the black-resume arm) regardless of its own outcome.

Binding standing constraints (v8.0/v9.0): DMI-gated 82H0 kernel patches; one candidate per
CI iteration with sha-verified rollback retained; user-authorized eyes-on sessions (user
triggers every suspend/resume themselves, one test per session); machine evidence alongside
every verdict; instrumentation chain + ≥18 s window + `MANIFEST.sha256` registration;
ledger gate stays green; nothing re-proposes a disproven lever.

</domain>

<decisions>
## Implementation Decisions

### Instrument Behavior (echo 2 DCS reads)
- DCS read results go in an appended annotated section **after** the NAMED OVERLAY:
  `# DCS ID READ` header, one `DCS`-prefixed annotated line per read (keeps rows out of
  the `^0x...=` record regex the diff tooling parses).
- Per-read failure semantics: record the errno/failure per read and **continue** all five
  reads — refusals are themselves informative.
- `echo 1` stays MMIO-walk-only (47/49 tooling and historical captures stay valid);
  `echo 2` = MMIO walk + DCS ID reads.
- Read timeout behavior: reuse the RX path's existing bounded `GEN_READ_DATA_AVAIL` wait
  (`intel_dsi_host_transfer`), annotate each outcome incl. errno, no extra wrapper.

### Capture Protocol & Device Sessions
- **2 sessions**: (A) boot arm X=Y — echo-2 capture + I2C sweep + tracepoints, no suspend
  involved; (B) black-resume arm X=Z — separate user-authorized suspend/resume session,
  capture on resume. The suspend IS the session's one test.
- Black-resume capture mechanics: extend `scripts/capture_dsi_dumps.sh` with the echo-2
  mode, a `timeout`-wrapped trigger (a hanging read can never wedge the session), and a
  one-command blind invocation writing to a file.
- Diff: extend `scripts/dsi_mmio_diff.sh` to parse the `# DCS ID READ` section and emit an
  ID-read comparison block (boot-vs-resume per read: answered/errno).
- Kit registration: every new artifact goes into `MANIFEST.sha256` (both DCS dumps, I2C
  sweep outputs, tracepoint logs, diff outputs).

### I2C Sweep Scope
- Delivery: dedicated `scripts/tcon_i2c_sweep.sh` — bus inventory, per-bus `i2cdetect -y`,
  `gpioinfo` rail claims, `dmesg` PMIC/controller lines — archives everything kit-ready in
  one run.
- Tracepoints: `i2c:i2c_write/read/reply/result` enabled during the echo-2 instrument run
  in both arms (passive observation, no extra user burden); the written conclusion must
  cover the boot-arm run at minimum.
- Bus range: dynamic — sweep every enumerated bus from `i2cdetect -l` +
  `/sys/bus/i2c/devices` (research's `seq 0 9` is a floor, not a bound).
- Conclusion location: single `docs/research/TCON_IDENTIFICATION.md` carries identity-or-
  proven-dead verdict + I2C conclusion (buses, PMIC on bus 6, sideband in/out) +
  datasheet-gated candidate notes (AUO G101EAN01.x, ILI9881C, ST7701/ST7703, HX8394(F),
  NT36672(a)) cross-checked against AUO PnP 0xaf06/6104 and FRU 5D11A20220.

### DSI_MMIO_DIFF §6 Correction & Open Anomalies
- §6 correction scope: fix **only** the 0x6b004 row label to the bit-accurate decode
  (`SPL_PKT_SENT | HS_TX_TIMEOUT | LOW_CONTENTION`; LP_RX_TIMEOUT bit 22 NOT set),
  cross-consistent with §5.2 and `NO_CLEAN_FIX_PROOF.md` §7.1.
- `0x6b010=0xb8ea` anomaly: stays flagged **open** with a documented reason — a
  write/read-back probe is a register WRITE, which violates this instrument's read-only
  contract; it needs its own gated change.
- `0x6b080` DPHY anomaly (matches neither VBT nor kernel values): same treatment —
  flagged, documented, no action this phase.
- Ledger rows this phase: **none** — nothing here falsifies a fix lever; ID-read results
  are evidence in `TCON_IDENTIFICATION.md`. The ledger gate (`test_pitfalls_ledger.sh`)
  just stays green.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `patches/d330_dsi_dump.patch` — the `i915_dsi_regs` node
  (`drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c`): 256 KiB frozen snapshot
  buffer, PLL-gated DSI/PHY walks, `# RANGE`/`# SKIPPED`/NAMED-OVERLAY output contract,
  re-probe-safe registration (post-49 fix). `echo 2` extends
  `d330_dsi_dump_write()`/`d330_dsi_dump_walk()` in this file.
- `scripts/capture_dsi_dumps.sh` (the 47/49 capture discipline), `scripts/dsi_mmio_diff.sh`
  (diff engine to extend), `scripts/test_dsi_mmio_evidence.sh` + `test_pitfalls_ledger.sh`
  (gates that must stay green), `docs/dumps/re_kit/MANIFEST.sha256`.
- CI kernel pipeline: `.github/workflows/build-kernel.yml` builds the patched kernel; the
  patch stack in `patches/` carries the falsified v9.0 candidates (do not disturb).
- Research ground truth: `.planning/research/v10.0-tcon-hunt.md` §2 (fingerprints),
  §3.1-3.2 (I2C facts + probe commands), §4 (instrument design + feasibility proof),
  §5.2 (bit-accurate register map incl. the 0x6b004 decode).
- On-device VBT facts: BTA enabled (block 52), PMIC I2C bus 6, block 53 has zero
  I2C/SPI/PMIC elements; `mipi_exec_send_packet()` returns `-EOPNOTSUPP` for READ packets —
  the VBT executor cannot do reads, the node extension calls `mipi_dsi_dcs_read()` directly.

### Established Patterns
- Capture protocol mirrors the 47/49 discipline: boot arm (X=Y) + black-resume arm (X=Z),
  kit-registered, diffed; user-authorized sessions; machine evidence alongside every verdict.
- Debugfs output contract: `#`-prefixed headers, `NAME 0x...=` overlay rows kept out of the
  `^0x...=...` record regex — the new DCS section must follow the same convention.
- Additive-only patch style with honest DMI banner and commentary on every decision.

### Integration Points
- `d330_dsi_dump_write()` trigger parsing (`kstrtobool_from_user` today → needs echo-2
  value parsing while keeping `echo 1` behavior).
- `mipi_dsi_dcs_read()` (`vlv_dsi.c` RX path: `GEN_READ_DATA_AVAIL` wait + `read_data()`)
  — the read primitive the instrument calls; LP mode (`MIPI_DSI_MODE_LPM`), VC 0, port A.
- `scripts/dsi_mmio_diff.sh` section parser — new `# DCS ID READ` section handling.
- `docs/research/DSI_MMIO_DIFF.md` §6 — the 0x6b004 label correction;
  `NO_CLEAN_FIX_PROOF.md` §7.1 consistency check.

</code_context>

<specifics>
## Specific Ideas

- The block-55 VBT mystery is closed as a negative result (DSC compression parameters,
  never parsed by the kernel) — document it in `TCON_IDENTIFICATION.md` for the record
  (research §1.3).
- Expected payoff of successful reads: TCON identity → public datasheet → documented
  wake/reset requirements feeding Phase 51's ladder; AUO product-code cross-check
  (PnP 6104 vs live ID).
- Reads succeeding at boot but failing at wake = TCON state loss; succeeding in both =
  TCON alive-but-misconfigured (the hunt pivots to wake-register content).
- Pre-kernel GOP I2C traffic is invisible to kernel tracing — honored constraint, note it
  in the conclusion (needs the Phase 53 logic analyzer).

</specifics>

<deferred>
## Deferred Ideas

- The 0x6b010 write/read-back probe (register-write instrument mode) — deliberate
  non-goal: violates the read-only instrument contract; own gated change if ever needed.
- Pre-kernel GOP bus-traffic capture — needs Phase 53 hardware (logic analyzer).
- Any fix-candidate work — Phase 51's territory; this phase only instruments and identifies.

</deferred>
