# Roadmap: Lenovo D330-10IGL Linux Parity Project

## Milestones

- ✅ **v1.0 Display & Power Parity** — Phases 0-5 (shipped)
- ✅ **v2.0 Peripheral Parity & Tablet Usability** — Phases 6-9 (shipped)
- ✅ **v3.0 Vision, Ergonomics & Multimedia** — Phases 10-14 (shipped)
- ✅ **v4.0 Connectivity, Firmware & System Boot** — Phases 15-20 (shipped)
- ✅ **v5.0 CI/CD & Remastered Live ISO Distribution** — Phases 21-23 (shipped)
- ✅ **v6.0 System Resilience, Performance & Usability Polish** — Phases 24-31 (shipped)
- ✅ **v7.0 Pre-Deployment Audit Remediation** — Phases 32-42 (shipped 2026-10-08)
- ✅ **v8.0 Reverse-Engineer & Fix the D330 Resume Black Screen** — Phases 43-46 (shipped 2026-10-13: RE + differential + honest closure; **bug NOT fixed** — the fix hunt continues)
- ✅ **v9.0 Actually Fix the D330 Resume Black Screen** — Phases 47-49 (shipped 2026-10-16: DSI MMIO truth + 3 falsified DMI-gated fix candidates + honest closure; **fix proven unreachable from every kernel path tested** — recovery = reboot only; the hunt continues in v10.0)
- 🚧 **v10.0 Crack the Panel — TCON Identification and the GOP-Init Hunt** — Phases 50-53 (in progress)

## Phases

<details>
<summary>✅ v1.0 Display & Power Parity (Phases 0-5) — SHIPPED</summary>

Full detail archived to [`milestones/v1.0-ROADMAP.md`](milestones/v1.0-ROADMAP.md).

- [x] Phase 0: Project & Repository Setup (`7e4b76e`)
- [x] Phase 1: Community Research & Prior Art Ingestion (`a60bdf1`)
- [x] Phase 2: Official Lenovo Windows Driver Baseline Acquisition (`c489f88`)
- [x] Phase 3: Hardware Telemetry & ACPI Extraction (`d09d0c3`)
- [x] Phase 4: Differential Analysis & Reverse Engineering (`d5f20bc`)
- [x] Phase 5: Patch Generation & DKMS Delivery (`7c313fb`)

</details>

<details>
<summary>✅ v2.0 Peripheral Parity & Tablet Usability (Phases 6-9) — SHIPPED</summary>

Full detail archived to [`milestones/v2.0-ROADMAP.md`](milestones/v2.0-ROADMAP.md).

- [x] Phase 6: Touchscreen & Active Pen Calibration (`4126a9a`)
- [x] Phase 7: Detachable Dock & Tablet Mode Daemon (`bb7b4c5`)
- [x] Phase 8: Audio & Microphone UCM Profiles (`b2cb1e7`)
- [x] Phase 9: Battery Life & Power Governors (`1858351`)

</details>

<details>
<summary>✅ v3.0 Vision, Ergonomics & Multimedia (Phases 10-14) — SHIPPED</summary>

Full detail archived to [`milestones/v3.0-ROADMAP.md`](milestones/v3.0-ROADMAP.md).

- [x] Phase 10: Intel IPU3 Dual Camera Pipeline
- [x] Phase 11: 4GB RAM & 64GB eMMC Storage Optimization
- [x] Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)
- [x] Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)
- [x] Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)

</details>

<details>
<summary>✅ v4.0 Connectivity, Firmware & System Boot (Phases 15-20) — SHIPPED</summary>

Full detail archived to [`milestones/v4.0-ROADMAP.md`](milestones/v4.0-ROADMAP.md).

- [x] Phase 15: Early Bootloader, Console & Plymouth Orientation
- [x] Phase 16: ACPI DSDT Clean Initrd Override
- [x] Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS) Auto-Dimming
- [x] Phase 18: Touchpad & Active Pen Gestures Tuning
- [x] Phase 19: MicroSD Storage Expansion & Modular Cellular LTE
- [x] Phase 20: Critical Low-Battery Auto-Hibernate Daemon

</details>

<details>
<summary>✅ v5.0 CI/CD & Remastered Live ISO Distribution (Phases 21-23) — SHIPPED</summary>

Full detail archived to [`milestones/v5.0-ROADMAP.md`](milestones/v5.0-ROADMAP.md).

- [x] Phase 21: Native Distribution Packaging (.deb, .rpm, PKGBUILD)
- [x] Phase 22: Automated Live ISO Remaster Build Harness
- [x] Phase 23: GitHub Actions CI/CD Release Pipeline

</details>

<details>
<summary>✅ v6.0 System Resilience, Performance & Usability Polish (Phases 24-31) — SHIPPED</summary>

Full detail archived to [`milestones/v6.0-ROADMAP.md`](milestones/v6.0-ROADMAP.md).

- [x] Phase 24: Intel VA-API Hardware Video Acceleration (iHD / Firefox / Chromium)
- [x] Phase 25: Fanless Thermal Tuning & RAPL Power Limits (PL1 5.0W, PL2 8.0W, thermald)
- [x] Phase 26: Out-Of-Memory Prevention (earlyoom on 4GB RAM)
- [x] Phase 27: Tablet Mode OSK Auto-Summon & Long-Press Right-Click
- [x] Phase 28: PipeWire RNNoise Neural AI Microphone Denoising
- [x] Phase 29: Wi-Fi & Bluetooth Coexistence & S2idle Sleep Stability
- [x] Phase 30: Fast Boot Optimization for eMMC Storage
- [x] Phase 31: Desktop GUI System Tray Hardware Applet (`d330-tray.py`)

</details>

<details>
<summary>✅ v7.0 Pre-Deployment Audit Remediation (Phases 32-42) — SHIPPED 2026-10-08</summary>

Full detail archived to [`milestones/v7.0-ROADMAP.md`](milestones/v7.0-ROADMAP.md).
Audit report: [`milestones/v7.0-MILESTONE-AUDIT.md`](milestones/v7.0-MILESTONE-AUDIT.md).

- [x] Phase 32: Data-Loss & Boot Safety Guards (Audit C1, C2) (completed 2026-10-08)
- [x] Phase 33: Low-Battery Hibernate Feasibility (Audit C3) (completed 2026-10-08)
- [x] Phase 34: Deliver the Actual PPS / Display Resume Fix (Audit C4) (completed 2026-10-08)
- [x] Phase 35: Installer & Uninstaller Symmetry (Audit M1, M2, M11, N6) (completed 2026-10-08)
- [x] Phase 36: Desktop Session Wiring - Tray Applet & Tablet Daemon (Audit M3, M6) (completed 2026-10-08)
- [x] Phase 37: No-Op Tools Made Real or Removed - PWM & Sensor Filter (Audit M4, M5) (completed 2026-10-08)
- [x] Phase 38: PipeWire DSP Activation (Audit M7) (completed 2026-10-08)
- [x] Phase 39: udev / hwdb / Wireless Match Correctness (Audit M8, M9, M10, M15, M16) (completed 2026-10-08)
- [x] Phase 40: Power Stack Reconciliation (Audit M13, M14) (completed 2026-10-08)
- [x] Phase 41: Test Harness Trustworthiness (Audit M12, N8) (completed 2026-10-08)
- [x] Phase 42: Documentation Parity & Repository Polish (Audit M17, N1-N5, N7, N9, N10) (completed 2026-10-08)

</details>

<details>
<summary>✅ v8.0 Reverse-Engineer & Fix the D330 Resume Black Screen (Phases 43-46) — SHIPPED 2026-10-13</summary>

Full detail archived to [`milestones/v8.0-ROADMAP.md`](milestones/v8.0-ROADMAP.md).
Outcome: ROOT-04 honest closure — the bug was **NOT fixed**; the fix hunt continued in v9.0.

- [x] Phase 43: Guardrails, Ledger & Safe Recovery Baseline (completed 2026-10-12)
- [x] Phase 44: Community & Upstream Survey + Cheap Levers (completed 2026-10-12)
- [x] Phase 45: Windows/GOP Binary RE + On-Device Resume-vs-Probe Differential (completed 2026-10-13 — ROOT-04 honest closure)
- [x] Phase 46: Verification, Delivery & Upstream (conditional) (completed 2026-10-13 — upstream clause skipped)

</details>

<details>
<summary>✅ v9.0 Actually Fix the D330 Resume Black Screen (Phases 47-49) — SHIPPED 2026-10-16</summary>

Full detail archived to [`milestones/v9.0-ROADMAP.md`](milestones/v9.0-ROADMAP.md); close-out in [`milestones/v9.0-close-out.md`](milestones/v9.0-close-out.md).
Outcome: honest closure — 3 DMI-gated fix candidates eyes-on-falsified, then machine falsification (working-lit MMIO == broken-wake MMIO, `DSI_MMIO_DIFF` §5.1/§5.2); mechanism lives below host MMIO on the panel TCON side; **recovery = reboot only** (proven bar, ledger rows 30-32).

- [x] Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff) (completed 2026-10-14)
- [x] Phase 48: Clean DMI-Gated Fix (MMIO-Guided) (completed 2026-10-15 — FIX-01 falsified, honest closure)
- [x] Phase 49: Delivery, No-Regression & Closure (completed 2026-10-16 — honest closure branch)

</details>

---

### 🚧 v10.0 Crack the Panel — TCON Identification and the GOP-Init Hunt (In Progress)

**Milestone Goal:** v9.0 closed honestly: every kernel-visible display state is
byte-identical working-vs-broken, the failure lives below host MMIO on the panel TCON side,
and only the GOP's boot-time firmware init (unreachable from every kernel path tested)
produces an image — recovery is a reboot. v10.0 attacks the panel from two new angles, plus
a safety net and an instrument buy: (1) **identify the TCON software-only** via a DCS ID
read on the existing `i915_dsi_regs` dump node (block 55 closed as a negative result; the
glass is AUO, FRU 5D11A20220, bare TCON model unknown); (2) **stop tearing the panel down
at suspend at all** — the keep-panel-powered ladder (E1 skip panel-side teardown → E2
warm-resume enable → E3 DCS rail-survival discriminator) so the resume path never needs the
unreachable re-init; (3) **ship the `d330-blackguard` self-healing safety net** regardless
of fix outcome (black resume → hotkey → beeps → countdown → reboot); (4) **gate a cheap
hardware logic-analyzer probe** (Kingst LA5016, MIPI-DSI LP decode) behind a demo-mode
buy-gate. SC1 bar: the panel shows an image after S3 resume via a keep-hot kernel change
(eyes-on + X=Y held), OR the TCON is identified with GOP-init mapped and the
missing-programming gap documented with a concrete instrument spec.

**Process rules (v8.0/v9.0 lessons + standing constraints, binding):** user-authorized
eyes-on verdicts gate every device session; the user triggers every suspend/resume test
themselves and reports the verdict in their own time; one test per session; machine evidence
(`i915_dsi_regs` dumps, ftrace) runs alongside every verdict; all kernel patches DMI/DMO-gated
`82H0`; one fix candidate per CI iteration; sha-verified rollback `.deb` retained before every
deploy; the ledger gate stays green in every phase; code/data commits deferred to `/gsd-ship`
(docs commit via `commit_docs`); honest closure is an acceptable outcome (FIX-01 precedent) —
never a fake fix.

**Phase Ordering Rationale:** Phase 50 runs first — it is software-cheap (one CI build + one
user-authorized capture session) and the same DCS read at the black-resume arm doubles as the
ladder's E3 discriminator, so its output feeds Phase 51 regardless of the TCON hunt's own
outcome. Phase 51 is the actual fix attempt and consumes Phase 50's capability. Phase 52
(blackguard) is deliberately independent of the fix outcome — the safety net ships whether
the ladder lands or falsifies. Phase 53 is the gated end phase: the buy-gate decision and
captures slot in after the ladder's outcome is known, because the hardware probe is the
documented escalation path if (and only if) the ladder falsifies; the purchase itself is
user-gated.

**Phases:**

- [ ] **Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only)** - Extend `i915_dsi_regs` with an `echo 2` DCS read mode, capture boot (X=Y) vs black-resume (X=Z) ID reads, rule the I2C sideband in/out, correct the DSI_MMIO_DIFF §6 label (TCON-01, TCON-02, TCON-03, TCON-04)
- [ ] **Phase 51: Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified)** - Hold the panel rails/TCON alive through S3 so resume never needs the unreachable re-init — the actual fix attempt, DMI-gated `82H0`, one candidate per CI iteration (KEEP-01, KEEP-02, KEEP-03, KEEP-04, KEEP-05)
- [ ] **Phase 52: Black-Resume Self-Healing (d330-blackguard)** - Hotkey → beeps → countdown → reboot safety net + stand down the legacy display-resume hook + tests + one rtcwake on-device validation (BLK-01, BLK-02, BLK-03, BLK-04)
- [ ] **Phase 53: Hardware Logic-Analyzer Probe (Buy-Gate, Teardown, Capture A vs B)** - KingstVIS MIPI-DSI LP demo-mode buy-gate, FPC teardown + empirical pin ID, capture A (boot GOP LP DCS) vs B (kernel re-probe) + PMIC I2C bus 6 rails (HW-01, HW-02, HW-03, HW-04)

### Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only)

**Goal**: Identify the D330 panel's TCON controller (or prove the software read path dead)
using only the running kernel — extend the existing dump node with a DCS ID-read trigger,
capture the ID reads in both operational states (X=Y boot, X=Z black-resume), rule the I2C
sideband in or out, and correct the DSI_MMIO_DIFF §6 register label.

**Depends on**: Nothing (first phase of Milestone v10.0; direct inputs: `v10.0-tcon-hunt.md`
§4 instrument design, `DSI_MMIO_DIFF.md` §5.2/§6 corrections)

**Requirements**: TCON-01, TCON-02, TCON-03, TCON-04

**Why it matters**: The block-55 VBT mystery is closed as a negative result (DSC compression
parameters, never parsed by the kernel); panel glass is AUO (VBT block 42 PnP 0xaf06/6104)
but the bare TCON model is unknown and no public FRU 5D11A20220 → glass cross-reference
exists. The TCON identity is the last software-reachable unknown: it gates the datasheet hunt
(documented wake/reset requirements), and the same DCS read at the black-resume arm is the
ladder's E3 discriminator — this phase's output feeds Phase 51 regardless of its own outcome.

**Must do** (research-grounded):
- Extend `i915_dsi_regs`'s write side: `echo 2` performs the normal MMIO walk then DCS reads
  0x04 (Get Display ID) / 0xDA / 0xDB / 0xDC + a generic 0x83 read, LP mode
  (`MIPI_DSI_MODE_LPM`), VC 0, port A, appended as an annotated section — feasible because
  `mipi_dsi_dcs_read()` → `intel_dsi_host_transfer()` implements the RX path and BTA is
  enabled (VBT block 52) (`v10.0-tcon-hunt.md` §4)
- The VBT sequence executor cannot do reads (`mipi_exec_send_packet()` returns
  `-EOPNOTSUPP` for READ packet types) — extend the existing node rather than adding a new
  one (`v10.0-tcon-hunt.md` §4, §3.3)
- Capture protocol mirrors the 47/49 discipline: boot arm (X=Y) + black-resume arm (X=Z),
  both registered in the RE kit (`MANIFEST.sha256`), diffed; reads succeeding at boot but
  failing at wake = TCON state loss; succeeding in both = TCON alive-but-misconfigured
  (`v10.0-tcon-hunt.md` §4)
- Same-session I2C sweep + tracepoints: bus inventory + per-bus `i2cdetect`, `gpioinfo`
  rail claims, `i2c:i2c_write/read/reply/result` tracepoints during the instrument run;
  expect PMIC on bus 6 and no TCON sideband (block 53 has zero I2C/SPI/PMIC elements)
  (`v10.0-tcon-hunt.md` §3.1-3.2)
- Cross-check the ID against the candidate fingerprints (AUO G101EAN01.x, ILI9881C,
  ST7701/ST7703, HX8394(F), NT36672(a)) and the machine's own data (AUO PnP 0xaf06/6104,
  FRU 5D11A20220) (`v10.0-tcon-hunt.md` §2)
- Correct DSI_MMIO_DIFF §6: `0x6b004=0x40280000` = SPL_PKT_SENT | HS_TX_TIMEOUT |
  LOW_CONTENTION (LP_RX_TIMEOUT, bit 22, NOT set); signature = "HS video stream never
  accepted by panel" (`v10.0-tcon-hunt.md` §5.2; `v10.0-SUMMARY.md`)
- Flag the honest anomalies for the record, do not paper over: `0x6b010=0xb8ea` matches
  neither the kernel-computed value (~0xEF8AA) nor GOP/VBT 0x3fffff — write/read-back probe
  question left open with a documented reason (`v10.0-tcon-hunt.md` §5.2)

**Expected artifact**: CI-built kernel with the `echo 2` mode; `docs/research/TCON_IDENTIFICATION.md`
(identity or proven dead end + I2C sweep conclusion + datasheet-gated candidate notes);
kit captures (X=Y/X=Z ID reads + I2C sweep outputs) registered in `MANIFEST.sha256`; corrected
DSI_MMIO_DIFF §6.

**Check**: machine (dump output contains the annotated ID-read section; ledger gate +
`test_dsi_mmio_evidence.sh` exit 0; re-kit verify passes) + eyes-on (one user-authorized
device session for the black-resume arm).

**Success Criteria** (what must be TRUE):

  1. `echo 2 > .../i915_dsi_regs` performs DCS ID reads (0x04/0xDA/0xDB/0xDC + generic
     0x83) in LP mode and appends an annotated section to the dump; built by CI, deployed
     with the sha-verified rollback retained, and the capture/diff scripts handle the new
     section
  2. ID-read captures exist for both states (boot X=Y, black-resume X=Z), are
     kit-registered, and the TCON identity is stated — or the read path is proven dead with
     the failure mode documented — cross-checked against AUO PnP 0xaf06/6104 and FRU
     5D11A20220
  3. The I2C sweep + tracepoint session is archived with a written conclusion: which buses
     exist, PMIC presence on bus 6, and whether any panel-TCON sideband exists on any bus
  4. DSI_MMIO_DIFF §6's 0x6b004 row carries the bit-accurate decode (SPL_PKT_SENT |
     HS_TX_TIMEOUT | LOW_CONTENTION; bit 22 not set) and the ledger gate stays green

**Plans**: 4/5 plans executed
- [x] 50-01-PLAN.md
- [x] 50-02-PLAN.md
- [x] 50-03-PLAN.md
- [x] 50-04-PLAN.md
- [ ] 50-05-PLAN.md

- [ ] `50-01-PLAN.md` — echo-2 DCS ID-read instrument (kernel node extension + CI build)
- [ ] `50-02-PLAN.md` — Userspace tooling (capture echo-2 mode, diff DCS parser, I2C sweep script)
- [ ] `50-03-PLAN.md` — DSI_MMIO_DIFF §6 label correction + open-anomaly record (TCON-04)
- [ ] `50-04-PLAN.md` — Deploy echo-2 kernel + Session A (boot arm X=Y + I2C sweep + tracepoints)
- [ ] `50-05-PLAN.md` — Session B (black-resume X=Z) + diff + TCON_IDENTIFICATION verdict

### Phase 51: Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified)

**Goal**: Attempt the actual fix: hold the panel rails / reset line / TCON state alive
through S3 so the resume path never needs the GOP's unreachable re-init — E1 skip the
panel-side teardown at suspend, E2 warm-resume enable, E3 DCS rail-survival discriminator
if E1 falsifies. Success = image after resume (eyes-on, X=Y held); any falsification is
machine-evidenced and names exactly which cut killed the attempt.

**Depends on**: Phase 50 (the DCS-read capability is E3's discriminator; the TCON identity
informs the datasheet-gated candidates)

**Requirements**: KEEP-01, KEEP-02, KEEP-03, KEEP-04, KEEP-05

**Why it matters**: v9.0 proved the kernel cannot re-init the panel — but the suspend path
itself performs a full panel power cycle (3 VBT sequences + 1 DCS in
`intel_dsi_post_disable()`), ftrace-verified. The lever is the inverse of falsified rows
30-32: don't tear the panel down at all. Host MMIO cannot survive S3 (DC9 is unconditional
on GLK, source-verified); only the external PMIC panel rails (GPIO 144 power / 160 reset)
can be held. If the TCON never loses power/reset, there is nothing to re-init — the only
kernel-side lever that does not require replicating the GOP's TCON-level init.

**Must do** (research-grounded):
- One-time infra: `d330_82h0_panel()` DMI helper + a suspend-commit flag on
  `struct intel_display` (set in `intel_display_driver_suspend()` before
  `drm_atomic_helper_suspend()`, cleared in resume) — keep-hot gates on the suspend side
  only, so KWin's post-resume modeset and any user modeset never trip it
  (`v10.0-keep-panel-powered.md` §1 suspend-only discriminator)
- E1: in `intel_dsi_post_disable()` skip MIPI_SEQ_DISPLAY_OFF / ASSERT_RESET / POWER_OFF;
  in `intel_dsi_disable()` skip the SHUTDOWN DCS; keep BACKLIGHT_OFF and ALL host-side
  teardown (ULPS, PLL off, `clear_device_ready`) — `v10.0-keep-panel-powered.md` §3 E1
- E2: in `intel_dsi_pre_enable()` skip POWER_ON + INIT_OTP behind the keep-hot flag
  (INIT_OTP is a GPIO 160 reset toggle that would throw away the kept state); keep
  DEASSERT_RESET, the GLK link bring-up, DISPLAY_ON, backlight —
  `v10.0-keep-panel-powered.md` §3 E2
- E3 (only if E1 falsifies): DCS ID read pre-INIT_OTP on the re-trained link → TCON-alive
  vs rails-cut verdict; E4 wake-order variants only if E3 shows a live TCON —
  `v10.0-keep-panel-powered.md` §3 E3/E4
- Do not spend iterations on dead experiments: host MMIO holds (DC9 wipes all display
  MMIO), defer-PPS-to-resume (ledger row 31 + v8.0 early cycle), `disable_power_well=0`,
  s2idle escape — `v10.0-keep-panel-powered.md` §3 (dead experiments) + facts 3/8
- Measurement: two dumps per session (~0-1 s and ~4 s post-exit) inside the ≥18 s window
  discipline; X=Y operational set = `0x6b010=003fffff, 0x6b044=0000001d,
  0x6b080/0x6b098=09051003, 0x6b088=0022000f, 0x6b094=1, 0x160018=00000115`; ftrace must
  show POWER_OFF absent at suspend (E1) and POWER_ON/INIT_OTP absent at resume (E2);
  eyes-on image is the verdict — `v10.0-keep-panel-powered.md` fact 10
- Name the decisive risk up front: the PMIC may cut the display rail at S3 entry regardless
  of GPIO 144 (and the SoC GPIO pad may float at the power-down boundary) — E1 fails fast
  and cheap either way and doubles as the rail-survival probe; t11 rail-blip risk at wake
  documented — `v10.0-keep-panel-powered.md` §4

**Expected artifact**: CI-built DMI-gated `82H0` kernel patches (E1/E2[/E3]); ftrace + dump
evidence pairs per rung; `RESUME_FIX_LEDGER.md` rows for every rung (success or failure);
`NO_CLEAN_FIX_PROOF.md` v10.0 section if the ladder falsifies; battery-drain quantification
if E1 works.

**Check**: machine (D330SEQ/D330GPIO ftrace + dump diffs per rung) + eyes-on
(user-authorized verdict per iteration; repeated user-triggered cycles if the fix lands).

**Success Criteria** (what must be TRUE):

  1. The keep-hot infra is in place and E1's ftrace proves the suspend-side skip: suspend
     ends after BACKLIGHT_OFF with no DISPLAY_OFF/ASSERT_RESET/POWER_OFF and no SHUTDOWN
     DCS, backlight-off kept, host-side teardown intact
  2. E2's at-wake post-commit dump (~4 s, inside the window discipline) shows the X=Y
     operational set AND eyes-on confirms the image — or the rung is falsified with the
     dump/ftrace evidence archived
  3. If E1 falsifies: E3's pre-INIT_OTP DCS ID read produces a TCON-alive vs rails-cut
     verdict, recorded with the escalation decision (→ Phase 53) and the ledger updated
  4. Every rung: DMI-gated `82H0`, one candidate per CI iteration, sha-verified rollback
     deployed first, user-authorized eyes-on verdict, machine evidence alongside; on
     success X=Y holds across repeated user-triggered resume cycles + battery cost
     quantified once; on failure ledger rows appended + honest-closure doc updated — never
     a fake fix

**Plans**: TBD

### Phase 52: Black-Resume Self-Healing (d330-blackguard)

**Goal**: Ship the safety net that works regardless of the fix outcome: a deliberate hotkey
turns a black resume into a warned, cancellable, clean reboot (beeps → 10 s countdown with
pause-on-typing and Esc-cancel → `systemctl reboot`), the old strictly-harmful
display-resume hook stands down, and the whole thing is validated on-device once.

**Depends on**: Nothing technically (independent of Phases 50-51); the device session is
scheduled after Phase 51 (one test per session, user-serialized)

**Requirements**: BLK-01, BLK-02, BLK-03, BLK-04

**Why it matters**: v9.0 proven bar: reboot is the only recovery that ever restored a
visible image, and no machine signal distinguishes image from black (the v9.0 falsification
chain) — the user's eyes are the only working detector, so the design makes "eyes" an API.
Today that means the user must *know* to reboot; blackguard detects that moment
(human-confirmed trigger), warns on the speakers (which work when the panel can't), and
reboots cleanly with guardrails so it never reboots a working session.

**Must do** (research-grounded):
- Detection: hotkey primary (Plasma 6.1+ System Settings → Shortcuts → Add New → "Command
  or Script…" → `sudo -n /usr/local/bin/d330-blackguard --trigger`, Meta+Shift+B; KHotKeys
  is gone in Plasma 6, the KCM is Wayland-safe) + `keys` evdev-burst heuristic opt-in
  default OFF with EV_ABS/BTN_TOUCH exclusion — `v10.0-self-healing.md` §3 + facts 6-8
- Flow: `/usr/lib/systemd/system-sleep/` hook post-phase → DMI gate (82H0) → config gate →
  spawn detached child and exit fast (`user.slice` is frozen while hooks run) → settle
  15 s → arm window 900 s → trigger → beep ×1 → 10 s countdown (any EV_KEY in the last
  1.5 s pauses; Esc cancels; beep each second) → journal marker → `systemctl reboot` from
  the child, not the hook — `v10.0-self-healing.md` §4-5
- Guardrails: flock single-instance, arm TTL, master disable + DRY_RUN in
  `/etc/default/lenovo-d330-blackguard`, works wedged (root evdev reads, no GUI
  dependency), forensic journal trail (`logger -t d330-blackguard`), research-session
  quiet file so rtcwake captures can never self-reboot — `v10.0-self-healing.md` §6
- Ship tree + installer: `patches/blackguard/` (tool, hook, config, sudoers drop-in
  `santiago ALL=(root) NOPASSWD: /usr/local/bin/d330-blackguard --trigger`, README) +
  `scripts/install_blackguard_d330.sh` mirroring the deploy-script conventions (device
  alias `santiago-D330`, sha256-verified uploads, `visudo -c` before activation,
  `D330_SUDO_PW` discipline, `DRY_RUN` skips ssh/scp) — `v10.0-self-healing.md` §7
- Stand down the legacy hook: installer writes `D330_DISPLAY_RESUME=0` to
  `/etc/default/lenovo-d330-display-resume` and journals why (the unbind kills kwin and
  leaves lit-black — strictly harmful post-v9.0) — `v10.0-self-healing.md` fact 10
- Tests: `scripts/test_blackguard.sh` in the repo harness style — mocked DMI, fake configs,
  synthetic 24-byte `input_event` fixtures; assertions: DMI gate rejects non-82H0, disable
  file wins, trigger→countdown, key burst→pause, Esc→cancel, TTL expiry, flock prevents
  double-arm, DRY_RUN never emits reboot, quiet file suppresses —
  `v10.0-self-healing.md` §7

**Expected artifact**: `patches/blackguard/` ship tree + installer + test harness; README
with the KDE shortcut how-to; journaled stand-down of the legacy hook; on-device validation
journal excerpt (trigger source, pauses, cancel, AUTO-REBOOT marker).

**Check**: machine (`scripts/test_blackguard.sh` exit 0; `visudo -c`; journal markers) +
eyes-on (one user-authorized rtcwake session: black resume → hotkey → beeps → countdown →
reboot; Esc-cancel and typing-pause drills pass).

**Success Criteria** (what must be TRUE):

  1. `d330-blackguard` + hook + config + sudoers ship through the installer (sha-verified
     upload, `visudo -c` before activation) with master-disable + DRY_RUN + quiet-file
     support, and the deviceless test harness is green on all specified cases
  2. On-device rtcwake validation passes: black resume → hotkey → beep → countdown →
     reboot occurs; Esc cancels; typing pauses; the journal shows trigger source and the
     AUTO-REBOOT marker
  3. The legacy `lenovo-d330-display-resume.sh` hook is stood down (`D330_DISPLAY_RESUME=0`
     written + journaled why) and the KDE shortcut how-to is documented; keys heuristic
     ships default OFF
  4. Research sessions can't self-reboot: the capture helper writes the quiet file (or the
     manual touch is documented), verified in the same validation session

**Plans**: TBD

### Phase 53: Hardware Logic-Analyzer Probe (Buy-Gate, Teardown, Capture A vs B)

**Goal**: Answer the wire-level question with a cheap logic analyzer — validate the
KingstVIS MIPI-DSI LP decoder in demo mode BEFORE buying (the buy-gate), tear down and
identify the panel FPC pins empirically, capture boot GOP LP DCS (A) vs kernel resume
re-probe (B) plus PMIC I2C bus 6 rails (C), and record which mechanism story the evidence
supports — or document the buy-gate decision with reason.

**Depends on**: Phase 51's ladder outcome (the hardware probe is the documented escalation
path if the ladder falsifies); the purchase itself is user-gated

**Requirements**: HW-01, HW-02, HW-03, HW-04

**Why it matters**: The open wire-level questions are exactly three: does GOP send anything
on the DSI lanes beyond the block-53 LP DCS bursts (the unseen TCON programming), does GOP
toggle the PMIC rails (GPIO 144/160/145 over I2C bus 6) differently from the kernel's resume
path, and does the kernel's re-probe transmit anything at all. DSI HS (~1 Gbps/lane) is not
cheap-decodable — accepted loss, because the panel-init DCS is LP-flagged (~25× oversample
at 500 MS/s) and bus 6 carries the rails. Capture A vs B is the instrument that closes SC3
either way.

**Must do** (research-grounded):
- Buy-gate first: validate the KingstVIS "MIPI-DSI LP" decoder in free demo mode (against a
  DSI logic simulation or a captured D330 file) BEFORE any purchase; Kingst LA5016 $238
  primary (the only cheap analyzer with a built-in MIPI-DSI LP decoder — LA1010/LA2016 do
  NOT get it); DSLogic U3Pro16 $299 only if long resume streams prove painful on the
  LA5016's buffer — `v10.0-hardware-instrument.md` §1-2, §7
- Scope honesty: HS content decode is a $5k+ pro-scope capability and is NOT part of this
  milestone; the job is LP DSI + I2C + rails + HS envelope timing via the 0.6 V threshold
  trick (LP-11 reads high, HS burst reads low) — `v10.0-hardware-instrument.md` §1.1,
  §4.2-4.3
- Teardown per the Lenovo HMM (battery disconnected before any probing); measure the
  connector pitch/pin count at teardown BEFORE ordering the FPC breakout + FFC extension
  (~$5-15, generic 40-pin 0.5 mm class assumption) — `v10.0-hardware-instrument.md` §3
- Empirical pin ID (no official 82H0 schematic): GND continuity to chassis shield →
  powered rails (3V3) → DSI pairs (Dp and Dn both ~1.2 V, LP-11) → remaining single-ended
  lines by boot behavior; LA ground to chassis, device on battery (floating, safe) —
  `v10.0-hardware-instrument.md` §3
- Captures: A = power-on → ~10 s GOP boot init (arm before power button, 125-500 MS/s with
  RLE); B = suspend + wake + 30 s kernel re-probe (`rtcwake -m mem -s 20`, stream mode
  preferred); C = PMIC I2C bus 6 (4-8 MS/s, I2C decoder) —
  `v10.0-hardware-instrument.md` §4.1
- Decode and read the evidence per the §5 mapping: extra LP writes beyond block 53 = GOP's
  on-wire TCON init → decode → replay fix candidate; identical bursts = wire exonerated,
  pivot to the MMIO/PHY side; no LP bursts at resume = kernel never transmits; rail toggles
  differ = sequencing gap directly actionable in `intel_dsi_vbt`/PPS —
  `v10.0-hardware-instrument.md` §5
- Fallbacks documented, not improvised: if the KingstVIS decoder disappoints, a custom
  libsigrokdecode PD (~200 lines Python for LP escape) or manual decode; if all init turns
  out HS, shrink to the I2C-bus-only plan — `v10.0-hardware-instrument.md` §2, §4.3-4.4

**Expected artifact**: buy-gate decision doc (demo-mode validation notes + decision + user
authorization); teardown/pin-ID notes with photos; capture files A/B/C + decoder exports
kit-registered; the v10.0 hardware findings doc with the §5 verdict.

**Check**: machine (capture files + decode exports + re-kit verify) + eyes-on (teardown and
capture sessions, user-authorized); the purchase itself is user-gated.

**Success Criteria** (what must be TRUE):

  1. The buy-gate decision is documented with reason: KingstVIS MIPI-DSI LP decoder
     validated in demo mode BEFORE purchase, the decision (buy LA5016 / add U3Pro16 /
     decline) recorded with the user's authorization — or the documented decline and its
     consequence for the hunt
  2. Physical access achieved: battery disconnected first, connector pitch/pin count
     measured, empirical pin ID completed (GND → rails → LP-11 pairs → behavior), no-solder
     interposition in place
  3. Captures A (boot GOP LP DCS), B (kernel resume re-probe) and C (PMIC I2C bus 6 rails)
     exist, are decoded, kit-registered, and diffed per the §5 observation mapping with HS
     envelope timing included
  4. The verdict is written and honest: whether the GOP's extra TCON programming is
     on-wire (→ decode → fix candidate) or MMIO/PHY-side (→ wire exonerated, pivot) — or
     captures were never taken because the buy was declined, with the documented
     consequence

**Plans**: TBD

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 50. TCON Identification — DCS ID-Read Instrument (Software-Only) | 4/5 | In Progress | - |
| 51. Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified) | 0/0 | Not started | - |
| 52. Black-Resume Self-Healing (d330-blackguard) | 0/0 | Not started | - |
| 53. Hardware Logic-Analyzer Probe (Buy-Gate, Teardown, Capture A vs B) | 0/0 | Not started | - |

---

## Project Status: Milestones 1-9 Complete (Phases 0-49); Milestone v10.0 (Phases 50-53) Planned

Milestone v10.0 maps its 17 v1 requirements (TCON-01..04, KEEP-01..05, BLK-01..04,
HW-01..04) to four phases, 50-53, with the load-bearing ordering above: the software-cheap
DCS ID read lands first and doubles as the ladder's E3 discriminator; the keep-panel-powered
ladder is the actual fix attempt; the blackguard safety net ships independent of the fix
outcome; the hardware logic-analyzer probe is the user-gated end phase and the documented
escalation path.

Milestones 1-6 (Phases 0-31) executed, tested, and archived. Milestone 7 (Phases 32-42)
remediated all 4 Critical, 17 Moderate and 11 Minor findings of the external pre-deployment
audit, plus one cross-phase packaging integration gap found by the milestone audit.
Milestone 8 (Phases 43-46) reverse-engineered the failure (GOP panel init, two-VBT handoff,
disproven-lever ledger) and closed honestly. Milestone 9 (Phases 47-49) captured the
hardware-level DSI/DPHY register truth, falsified 3 more DMI-gated fix candidates, and
machine-proved the mechanism lives below host MMIO on the panel TCON side — recovery =
reboot only. v10.0 attacks the panel itself: identify its TCON software-only, never tear it
down at suspend, ship the reboot safety net, and gate the cheap wire-level probe.
