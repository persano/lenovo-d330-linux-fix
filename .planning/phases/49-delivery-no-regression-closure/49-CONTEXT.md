---
phase: 49-delivery-no-regression-closure
discussed: 2026-10-15
areas: 3
decisions: 12
status: accepted
---

# Phase 49 Smart Context (all areas accepted)

## Area A — DONE-01 on the falsified branch (decision: 3 cycles + unreachable proof)

1. The milestone closes the honest-closure branch; DONE-01 is documented as
   "unreachable, machine-proven" — proven by 3 fresh user-triggered resume
   cycles on the CURRENT it3 kernel plus the phase-48 falsification chain.
2. The 3 cycles run with the full new instrument chain: boot arm, at-wake
   arm (≤18 s), and a post-reload lit arm — each registered in the kit and
   diffed; the lit-vs-wake identity is expected to reproduce (if it does
   NOT, that is a new falsifier — escalate back to the fix ladder).
3. Verdicts stay eyes-on, user-triggered (v9.0 binding rules); the user's
   own time; one session per cycle.
4. Traceability: DONE-01 → Complete (unreachable branch, machine-proven),
   with the SC1 alternative wording; DONE-02 → Complete when the guard
   chain is green at close.

## Area B — What ships (decision: merge branch as-is)

5. Branch instrument/d330-dsi-dump merges to main AS-IS: dump node (+
   re-probe fix) + it2 (panel power cycle) + it3 (MIPIO reset pulse) —
   both DMI-gated 82H0, harmless on other machines; matches the v8.0
   failed-candidate precedent (patches stay as documented failed
   candidates).
6. it1 patch stays git-history-only (ledger row 30), never applied by CI.
7. All deferred-commit artifacts ship with /gsd-ship: scripts
   (deploy_d330_kernel.sh + wrappers + session helpers), the re-kit
   (dumps + manifests), and every doc committed during the deferred
   phases.
8. The upstream post (UPSTREAM_HANDOFF.md) is updated as OPTIONAL
   documentation (mechanism-unreachable summary); it blocks nothing.

## Area C — Workaround delivery (decision: manual, documented)

9. The user's manual reload script stays the ONLY recovery (automated
   reprobe is disproven, ledger row 29 — never re-introduce automation).
10. The milestone close documents the workaround (what it does, when to
    run it) in the closure doc; no desktop launcher, no service.
11. No regression work beyond the guard chain: ledger gate + evidence
    suites + fixtures + kit verify + selftest all green at close.
12. State left on the device after close: the it3 kernel (sha
    C2C2CD89…1073) stays deployed; the rollback chain
    (deploy_incoming_fea98e575ad2.deb / d47_dump_kernel.deb) stays in
    place, documented in the close-out.
