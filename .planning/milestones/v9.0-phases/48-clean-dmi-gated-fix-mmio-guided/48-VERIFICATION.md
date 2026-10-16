---
phase: 48-clean-dmi-gated-fix-mmio-guided
verified: 2026-10-15
verdict: COMPLETE-HONEST-CLOSURE
plans_verified: [48-01, 48-02, 48-03]
method: goal-backward + codebase + device evidence + user verdicts
---

# Phase 48 Verification Report

## Goal-Backward Analysis

**Goal**: DMI-gated (82H0) kernel change making the panel show an image after
resume, guided by the Phase 47 mechanism; ≤5 iterations; on failure the
honest-closure document gets a v9.0 section — never a fake fix; every attempt
ledger-recorded.

## Success Criteria Walkthrough

### SC1 — fix built by CI, deployed with known-good rollback retained first, DMI-gated 82H0 — **MET**
- Three CI-built kernels (runs 38665460355 / 38743898749 / 38789067483), each
  DMI-gated `dmi_match(DMI_PRODUCT_NAME, "82H0")` proven by CI grep anchors.
- Rollback verified BEFORE every install (script-enforced after the
  clobber incident; sha-verified on device each time: d47 dump kernel
  ba47df8d…87be, then it1 deb 43b2e7c2…8932, then it2 deb FEA98E57…C876).
- Evidence: CI runs green; 48-01-SUMMARY; 48-02-SUMMARY.

### SC2 — user-triggered tests, panel shows desktop image after resume — **NOT MET (honestly)**
- Three user-authorized rtcwake sessions, three verbatim verdicts:
  "Still black" / "black but lit" / "Black but lit". No image was ever
  produced by any candidate.

### SC3 — ≤5 iterations; on failure honest-closure v9.0 section; every attempt ledger-recorded — **MET (failure branch)**
- Iterations stopped at 3 of ≤5 — NOT by budget exhaustion but by
  falsification (DSI_MMIO_DIFF §5.1): the working-lit state and the
  broken-wake state are MMIO-identical across the entire DSI block
  (1024/1024; whole-file delta = 5 GT monotonic-counter rows). No host
  register write or enable-path sequence can fix what no register state
  discriminates. All three attempts ledger-recorded (rows 30-32).
- NO_CLEAN_FIX_PROOF.md gained §7 (v9.0 closure: ladder, falsification,
  refined future-work) and §8 (state left behind). RESUME_VS_RELOAD_DIFFERENTIAL
  gained the v9.0 iterations-2-3 + falsification section. This satisfies the
  v9.0 SC1 alternative branch: "mechanism proven unreachable with documented
  reason and concrete next instrument" (NO_CLEAN_FIX_PROOF §7: panel-side
  logic-analyzer instrumentation, GOP re-execution caveat, TCON datasheet).

## Requirement Status (REQUIREMENTS.md Traceability)

- FIX-01: **Falsified** (honest closure; the image-on-resume bar is not
  reachable via any host-register lever — machine-proven)
- FIX-02: **Complete** (CI .deb pipeline + rollback-before-every-deploy +
  3 iterations + NO_CLEAN_FIX_PROOF v9.0 section; never a fake fix)
- FIX-03: **Complete** (no upstream waits; CI polling inline; the upstream
  post remains optional user documentation)

## Guard Chain at Close

- ledger gate: 4/4 (rows 30-32, Lever rows: 32)
- evidence suite 7/7; fixtures 8/8; selftest 35/35 (unchanged tooling)
- kit verify: green (10 new artifacts this phase: it1/it2/it3 pairs,
  reload_lit, 4 diff files)
- code review of phase-48 code/patches: covered by per-iteration grep-proof
  anchors + compile proofs + the ledger gate; the reviewer pass runs at
  /gsd-ship against the full deferred-commit set

## Artifacts Produced This Phase

- Kernels: it1/it2/it3 CI builds (branch instrument/d330-dsi-dump, HEAD
  550cb55, 8 commits, unmerged — /gsd-ship owns the merge)
- Patch files: d330_dsi_device_ready_fix.patch (history-only),
  d330_dsi_panel_power_cycle.patch, d330_dsi_mipio_reset.patch,
  d330_dsi_dump.patch (amended: re-probe fix)
- Tooling: scripts/deploy_d330_kernel.sh (hardened), deploy wrappers, dump
  node re-probe fix
- Evidence: 10 kit artifacts (3 session pairs + lit arm + 4 diffs)
- Docs: ledger rows 30-32; DSI_MMIO_DIFF §5.1; NO_CLEAN_FIX_PROOF §7/§8;
  RESUME_VS_RELOAD_DIFFERENTIAL v9.0 section; 48-RESEARCH/CONTEXT/VALIDATION;
  48-01/02/03 progress + summary docs

## Verdict

**COMPLETE — honest closure.** The phase's own SC3 failure branch is the
branch that fired; the milestone's SC1 alternative ("mechanism proven
unreachable with documented reason and concrete next instrument") is
satisfied by machine evidence. Phase 49 (Delivery, No-Regression & Closure)
proves the observable bar and closes the milestone honestly either way.
