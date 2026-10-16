# Requirements: Lenovo IdeaPad D330-10IGL Linux Display & Power Parity Project

**Defined:** 2026-10-16
**Milestone:** v10.0 Crack the Panel — TCON Identification and the GOP-Init Hunt
**Core Value:** the D330 resumes with a visible image. v9.0 closed honestly: every
kernel-visible display state is byte-identical working-vs-broken, the failure lives below
host MMIO on the panel TCON side, and only the GOP's boot-time firmware init (unreachable
from every kernel path tested) produces an image — recovery is a reboot. v10.0 identifies
the TCON software-only, stops tearing the panel down at suspend (the keep-hot ladder),
ships a self-healing safety net regardless of fix outcome, and gates a cheap wire-level
hardware probe. No upstream dependency — we are the only people working on this.

**Invariants from v8.0/v9.0 (binding):** `docs/research/RESUME_FIX_LEDGER.md` (32 rows)
and `docs/research/NO_CLEAN_FIX_PROOF.md` stay binding; the ledger gate
(`scripts/test_pitfalls_ledger.sh`) stays green in every phase; nothing re-proposes a
disproven lever; a falsified candidate with machine evidence is an acceptable outcome
(FIX-01 precedent) — never a fake fix.

## Standing constraints (v8.0/v9.0 precedent, binding)

- **DMI/DMO-gated `82H0`** on every kernel patch (proven harmless outside 82H0 three times
  in v9.0).
- **One fix candidate per CI iteration**; the sha-verified rollback `.deb` is retained
  before every deploy.
- **User-authorized eyes-on verdicts gate every device session**: the user triggers every
  suspend/resume test themselves and reports the verdict in their own time; no
  SSH-triggered test ever requires their eyes; one test per session.
- **Machine evidence (`i915_dsi_regs` dumps, ftrace) alongside every verdict.**
- **Instrumentation chain**: `scripts/capture_dsi_dumps.sh` + the re-probe-safe
  `i915_dsi_regs` dump node + `scripts/dsi_mmio_diff.sh` + D330SEQ/D330GPIO/D330DLY ftrace
  markers; ≥18 s window discipline; captures registered in the RE kit
  (`MANIFEST.sha256`).
- **Deferred-commit machine**: code/data uncommitted until `/gsd-ship`; docs committed via
  `commit_docs`.
- **Recovery order (proven bar)**: reboot is the only recovery that restores the image;
  every lighter lever is ledger-disproven; blackguard packages that recovery behind
  guardrails.

## Requirements (each maps to exactly one phase)

### TCON identification (Phase 50)

- **TCON-01**: The DCS ID-read instrument exists: `echo 2 >
  /sys/kernel/debug/dri/*/i915_dsi_regs` performs DCS reads (0x04 Get Display ID;
  0xDA/0xDB/0xDC per-byte fallbacks; generic 0x83) in LP mode, VC 0, appended as an
  annotated dump section — shipped through the CI kernel pipeline with the sha-verified
  rollback retained, and the capture/diff scripts handle the new section.

- **TCON-02**: The TCON is identified — or the software read path is proven dead with the
  failure mode documented: boot (X=Y) and black-resume (X=Z) ID-read captures,
  kit-registered and diffed, cross-checked against the machine's own data (AUO PnP
  0xaf06/6104, FRU 5D11A20220) and the candidate fingerprints (AUO G101EAN01.x, ILI9881C,
  ST7701/ST7703, HX8394(F), NT36672(a)); on success, datasheet-gated wake-requirement
  notes feed the ladder.

- **TCON-03**: The I2C sideband is ruled in or out: bus inventory + per-bus sweep, PMIC
  presence on bus 6, and `i2c:i2c_write/read/reply/result` tracepoints during the
  instrument session archived; a written conclusion states whether any panel-TCON sideband
  exists on any bus.

- **TCON-04**: `DSI_MMIO_DIFF.md` §6's 0x6b004 label is corrected to the bit-accurate
  decode (`SPL_PKT_SENT | HS_TX_TIMEOUT | LOW_CONTENTION`; LP_RX_TIMEOUT bit 22 NOT set),
  consistent with §5.2 and `NO_CLEAN_FIX_PROOF.md` §7.1; the open `0x6b010=0xb8ea`
  anomaly stays flagged, not papered over.

### Keep-panel-powered fix ladder (Phase 51)

- **KEEP-01**: Keep-hot infra: a `d330_82h0_panel()` DMI helper and a suspend-commit flag
  on `struct intel_display`, so the keep-hot gating fires only on the `82H0` during the
  suspend commit — never on KWin's post-resume modeset or user modesets.

- **KEEP-02**: E1 — skip the panel-side teardown at suspend: no DISPLAY_OFF /
  ASSERT_RESET / POWER_OFF (GPIO 160 and GPIO 144 stay high), no SHUTDOWN DCS;
  BACKLIGHT_OFF kept; all host-side teardown (ULPS, PLL, `clear_device_ready`) kept.
  Ftrace (D330SEQ/D330GPIO) proves the skips.

- **KEEP-03**: E2 — warm-resume enable: `intel_dsi_pre_enable()` skips POWER_ON + INIT_OTP
  behind the keep-hot flag (INIT_OTP is a GPIO 160 reset toggle that would throw away the
  kept state), keeps DEASSERT_RESET, the GLK link bring-up, DISPLAY_ON and backlight.
  Success = the X=Y operational set in the ~4 s post-commit dump + eyes-on image.

- **KEEP-04**: E3 — rail-survival discriminator (only if E1 falsifies): a DCS ID read
  pre-INIT_OTP on the re-trained link yields the TCON-alive vs rails-cut verdict,
  recorded with the escalation decision (→ Phase 53) and ledger rows appended.

- **KEEP-05**: The fix verdict, honest either way: the panel shows an image after S3
  resume via the keep-hot change (eyes-on + X=Y held across repeated user-triggered
  cycles, battery cost quantified once), OR the ladder is falsified with machine evidence
  per rung and `NO_CLEAN_FIX_PROOF.md` gets a v10.0 section — never a fake fix.

### Black-resume self-healing (Phase 52)

- **BLK-01**: `d330-blackguard` ships: state machine (arm/trigger/beeps/10 s countdown →
  `systemctl reboot`), the `/usr/lib/systemd/system-sleep/` hook spawning a detached child
  (settle delay, DMI gate, config gate), tmpfs state with TTL + flock,
  `/etc/default/lenovo-d330-blackguard` config with master disable + DRY_RUN, sudoers
  NOPASSWD exact-command grant — installed by a deploy-convention installer
  (sha256-verified uploads, `visudo -c`, `D330_SUDO_PW` discipline, DRY_RUN skip).

- **BLK-02**: The trigger UX: Plasma 6.1+ "Command or Script" shortcut how-to (Meta+Shift+B
  → `sudo -n ... --trigger`) documented in the README with a VT fallback; the `keys`
  evdev-burst heuristic ships opt-in default OFF with EV_ABS/BTN_TOUCH exclusion.

- **BLK-03**: The legacy `lenovo-d330-display-resume.sh` hook stands down via its own
  documented mechanism (`D330_DISPLAY_RESUME=0` written + journaled why) — it is strictly
  harmful post-v9.0 (kills kwin; leaves lit-black).

- **BLK-04**: Tests + on-device validation: `scripts/test_blackguard.sh` green on the
  specified assertion set (DMI gate, disable file, trigger→countdown, burst→pause,
  Esc→cancel, TTL, flock, DRY_RUN never reboots, quiet suppresses), plus one
  user-authorized rtcwake validation on-device (black resume → hotkey → beeps → countdown
  → reboot; Esc-cancel + typing-pause drills pass; journal trail complete) and
  research-session quiet-mode wiring in the capture helper.

### Hardware logic-analyzer probe (Phase 53)

- **HW-01**: The buy-gate decision is documented: KingstVIS "MIPI-DSI LP" decoder validated
  in free demo mode BEFORE any purchase; the decision (buy Kingst LA5016 $238 / optionally
  add DSLogic U3Pro16 $299 / decline) recorded with reason and the user's authorization —
  spend never happens without it.

- **HW-02**: Physical access achieved: Lenovo HMM teardown (battery disconnected first),
  connector pitch/pin count measured before ordering the FPC breakout + FFC extension
  (~$5-15), empirical pin ID (GND continuity → rails → LP-11 pairs at ~1.2 V → boot
  behavior), no-solder interposition in place, device on battery during captures.

- **HW-03**: Captures exist, decoded and kit-registered: A = boot GOP LP DCS (arm before
  power button, 125-500 MS/s + RLE), B = kernel resume re-probe (`rtcwake -m mem -s 20`,
  stream mode preferred), C = PMIC I2C bus 6 rails (4-8 MS/s); HS envelope timing included
  via the 0.6 V threshold trick; diffed per the research §5 observation mapping.

- **HW-04**: The wire-level verdict is recorded honestly: whether the GOP's extra TCON
  programming is on-wire (decode the extra writes → replay fix candidate), MMIO/PHY-side
  (wire exonerated → pivot), or the kernel never transmits at resume — or captures were
  not taken because the buy was declined, with the documented consequence for the hunt and
  the milestone's SC3.

## Phase mapping

| Phase | Requirements |
|-------|--------------|
| 50: TCON identification (DCS ID-read instrument, software-only) | TCON-01, TCON-02, TCON-03, TCON-04 |
| 51: Keep-panel-powered fix ladder (E1 → E2, E3 if falsified) | KEEP-01, KEEP-02, KEEP-03, KEEP-04, KEEP-05 |
| 52: Black-resume self-healing (d330-blackguard) | BLK-01, BLK-02, BLK-03, BLK-04 |
| 53: Hardware logic-analyzer probe (buy-gate, teardown, capture A vs B) | HW-01, HW-02, HW-03, HW-04 |

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| TCON-01 | 50 | Pending |
| TCON-02 | 50 | Pending |
| TCON-03 | 50 | Pending |
| TCON-04 | 50 | Pending |
| KEEP-01 | 51 | Pending |
| KEEP-02 | 51 | Pending |
| KEEP-03 | 51 | Pending |
| KEEP-04 | 51 | Pending |
| KEEP-05 | 51 | Pending |
| BLK-01 | 52 | Pending |
| BLK-02 | 52 | Pending |
| BLK-03 | 52 | Pending |
| BLK-04 | 52 | Pending |
| HW-01 | 53 | Pending |
| HW-02 | 53 | Pending |
| HW-03 | 53 | Pending |
| HW-04 | 53 | Pending |

## Success criteria (milestone)

- SC1: The panel shows an image after S3 resume via a keep-hot kernel change (eyes-on +
  X=Y held), OR the TCON is identified with GOP-init mapped and the missing-programming
  gap documented with a concrete instrument spec (never a vague "needs more research";
  FIX-01 honest-closure precedent applies).

- SC2: The blackguard safety net is deployed and validated on-device: black resume →
  hotkey → beeps → countdown → reboot, with Esc-cancel and typing-pause drills passing.

- SC3: Hardware capture A/B exists, OR the buy-gate decision is documented with reason.
