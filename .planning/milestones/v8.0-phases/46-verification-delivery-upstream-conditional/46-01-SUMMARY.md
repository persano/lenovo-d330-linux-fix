# 46-01-SUMMARY: Final verification & conditional upstream resolution

<!-- planner-discipline-allow: rebind -->
<!-- planner-discipline-allow: dsi-reprobe -->

Phase: 46 · Plan: 46-01 · Completed: 2026-10-13

## What shipped

- **On-device verification of the shipped kernel** (7.0.14-d330-fix, known-good build):
  - `uname -r` = 7.0.14-d330-fix; boot clean; DSI panel On (`card1-DSI-1 connected/On`,
    brightness at user level, no manual write needed at boot).
  - `lenovo_d330_fix` module loaded (1 instance); the failed-cycle candidate kernel was
    rolled back earlier in 45-02 (0 occurrences of the D330 DSI cycle strings in i915.ko).
  - CCS fix present: applied by CI (workflow grep-proofs enforce both the 82H0 DMI match
    and `intel_fb_is_ccs_modifier` in the source at build time); the panel renders daily
    with the fix active.
  - Suspend/resume journaled across the 45-02 test matrix (deep + s2idle entries in the
    boot journals).
- **No-regression**: full guard harness chain `CHAIN_EXIT=0`; ledger gate `files=45
  hits=0` at phase close.
- **docs/research/UPSTREAM_HANDOFF.md** — self-contained package for the user to file the
  upstream bug by hand (GitLab) — the phase 44 decision (filing is a user handoff).
- **Conditional resolution**: the upstream-submission clause was conditional on a landed
  clean resume fix. Condition FAILED (45-02 ROOT-04 honest closure) → upstream submission
  skipped, reason recorded here and in the roadmap. The CCS fix (a real landed fix, from
  phase 43's kernel work) was already covered by the phase 44 upstream survey.

## Requirements coverage

- ROOT-02 (fix attempt with CI deployments): satisfied across 45-02 (3 deployed
  candidates) — outcome recorded honestly.
- ROOT-05 (observable bar + no-regression at delivery): satisfied for what shipped — the
  known-good kernel's observable bar verified on-device; no-regression chain green.
- Milestone v8.0 wraps with the honest outcome: **the D330 resume black screen remains
  unfixed**; the only eyes-on-verified recovery is a full reboot; all 29 disproven levers
  are ledger-recorded; the RE kit + findings + evidence enable future work
  (NO_CLEAN_FIX_PROOF.md §4).
