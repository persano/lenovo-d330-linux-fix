---
phase: 49-delivery-no-regression-closure
title: Delivery & Closure — Inventory + Protocol Research
generated: 2026-10-15
researcher: gsd-phase-researcher (inline fallback — subagent infra degraded all session)
model: opus (orchestrator)
---

# Phase 49 Research: What ships, what runs, what closes

## 1. The 3-cycle protocol (DONE-01, unreachable-proof branch)

Per session (repeat 3×, one suspend/resume each, user-triggered
rtcwake — method re-authorized per session per the v9.0 rules):

1. Boot arm: `/usr/local/bin/capture_dsi_dumps.sh boot <dir N>` (panel lit,
   fresh boot after the deploy reboot — no deploy needed this phase; the
   device already runs the it3 kernel sha C2C2CD89…1073).
2. User-authorized rtcwake 45 s session (device-side script, session-N
   pattern), capture at-wake arm ≤18 s post-wake (automatic, wake+1 s).
3. Fetch both arms into the kit as closeN_boot/closeN_resume; diff each
   against the same-session boot arm.
4. Reload workaround for the user (panel restore) + lit arm capture
   (`closeN_lit`); diff lit-vs-wake — EXPECTED result: DSI block identical,
   delta = GT counters (the §5.1 identity). If any DSI row DIFFERS here,
   that is a NEW falsifier → stop, escalate back to the fix ladder.
5. Register all files, ledger-gate run; verdicts recorded verbatim.

## 2. Ship inventory (area B: merge branch as-is)

- Branch instrument/d330-dsi-dump: 8 commits (fdafc43 → 550cb55), CI-green
  on every run (anchors: 2× CCS, 2× dump-node, DMI gate, it3 pulse marker).
  Merge to main at /gsd-ship. it1 patch history-only (row 30).
- Deferred uncommitted files (ship via /gsd-ship): re-kit dumps + diffs +
  MANIFEST (15 files), scripts (capture_dsi_dumps.sh, dsi_mmio_diff.sh,
  test_dsi_mmio_evidence.sh, prepare_safety_kit.sh, deploy_d330_kernel.sh,
  session/debug helpers), docs/research/DSI_MMIO_DIFF.md, PROGRESS docs.
- Main is 35 local commits ahead of origin/main (docs); push at ship.
- `.planning/config.json` modification (use_worktrees=false) is a deliberate
  machine setting — commit it at ship.
- `.gsd/*` sentinels + `.planning/milestone.lock`: NOT committed (runtime).

## 3. DONE-02 close-out checklist

- Guard chain green: `test_pitfalls_ledger.sh` (rows 30-32 = final truth;
  no new rows needed — the 3 cycles are CONFIRMATION captures, not new
  levers), `test_dsi_mmio_evidence.sh` (7/7 + 8/8),
  `prepare_safety_kit.sh --verify`, evidence selftest (35/35).
- Ledger reflects final truth: rows 1-32 stand; row 32 carries the
  falsification. No appends expected unless a cycle contradicts §5.1.
- UPSTREAM_HANDOFF.md: optional update — mechanism-unreachable summary +
  pointer to DSI_MMIO_DIFF §5.1 / NO_CLEAN_FIX_PROOF §7. Filed by the user
  whenever convenient; blocks nothing (FIX-03).

## 4. Device end-state (decision area C)

- it3 kernel stays deployed (sha C2C2CD89…1073); rollback chain on device:
  `deploy_incoming_fea98e575ad2.deb` (it2) + `d47_dump_kernel.deb` — both
  sha-verified; the manual reload script remains the only recovery,
  documented in the close-out (no automation — row 29).
- The deploy script keeps its hardened discipline (sha-keyed incoming
  upload names, overridable rollback target, no rm of rollback assets).

## Validation Architecture

Not applicable as a standard section — the phase IS the validation (device
sessions + guard chain). No new unit-level harness; the kit + ledger gate +
evidence suites are the machine-checkable close-out bars.
