# Requirements: Lenovo IdeaPad D330-10IGL Linux Display & Power Parity Project

**Defined:** 2026-10-13
**Milestone:** v9.0 Actually Fix the D330 Resume Black Screen
**Core Value:** the D330 resumes with a visible image. v8.0 reverse-engineered the
failure (GOP panel init, two-VBT handoff, 29 disproven levers, kernel state byte-identical
working-vs-broken) but did not fix it. v9.0 carries the mechanism hunt to completion with
no upstream dependency — we are the only people working on this.

**Invariant from v8.0 (binding):** `docs/research/RESUME_FIX_LEDGER.md` (29 rows) and
`docs/research/NO_CLEAN_FIX_PROOF.md` stay binding; the ledger gate
(`scripts/test_pitfalls_ledger.sh`) stays green in every phase; nothing re-proposes a
disproven lever.

## Requirements (each maps to exactly one phase)

### Mechanism (Phase 47)
- **MMIO-01**: A hardware-level display register diff between a working fresh boot and a
  broken resume exists — DSI/DPHY transcoder registers the current kernel tooling cannot
  show (no `i915_dsi_info` on this kernel). Delivered as a small CI-built debug/dump patch
  or devcoredump capture, with the diff and its interpretation recorded in
  `docs/research/DSI_MMIO_DIFF.md`.
- **MMIO-02**: The diff names the mechanism: which hardware state the GOP sets at boot
  that the kernel's resume path does not (or sets wrong), stated as a testable claim.

### Fix (Phase 48)
- **FIX-01**: A clean, DMI-gated (`82H0`) kernel-side fix makes the panel show an image
  after resume — verified by the user's own eyes (user-triggered suspend/resume, user
  reports the verdict in their own time; no SSH-triggered test ever requires their eyes)
  plus machine evidence (traces, register state).
- **FIX-02**: The fix ships through the CI `.deb` pipeline with the known-good rollback
  `.deb` retained before every deploy; ≤5 fix iterations or an updated honest-closure
  document (`NO_CLEAN_FIX_PROOF.md` gets a v9.0 section — never a fake fix).
- **FIX-03**: Self-sufficient: no step of the plan waits on an upstream reply. The
  upstream post (from `UPSTREAM_HANDOFF.md`) is optional documentation, filed by the user
  whenever convenient.

### Delivery (Phase 49)
- **DONE-01**: The observable bar is proven on-device: after resume the desktop is
  visible and usable across at least 3 consecutive user-triggered suspend/resume cycles.
- **DONE-02**: No regression: the full guard harness chain is green at milestone close,
  and the ledger gate reflects the final truth (new disproven rows appended if the fix
  fails again).

## Phase mapping

| Phase | Requirements |
|-------|--------------|
| 47: DSI MMIO truth (boot vs resume register diff) | MMIO-01, MMIO-02 |
| 48: Clean DMI-gated fix (GOP-init replication or MMIO-guided) | FIX-01, FIX-02, FIX-03 |
| 49: Delivery, no-regression & closure | DONE-01, DONE-02 |

## Success criteria (milestone)

- SC1: After Phase 48, resume shows the desktop (eyes-on, user-triggered), or the
  mechanism is proven unreachable with a documented reason and a concrete next instrument
  (never a vague "needs more research").
- SC2: The shipped kernel's resume works across repeated cycles (DONE-01) and nothing
  else regressed (DONE-02).
- SC3: Every attempt (success or failure) is ledger-recorded; the process lessons (v8.0:
  test design blamed the user; no SSH-triggered eyes-on tests; one test per session) are
  honored in every plan.
