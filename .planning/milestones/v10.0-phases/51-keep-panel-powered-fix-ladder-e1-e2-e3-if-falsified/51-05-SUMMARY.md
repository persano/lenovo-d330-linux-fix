---
phase: 51-keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified
plan: 51-05
status: complete
started: "2026-10-17T22:00:00Z"
completed: "2026-10-18T11:20:00-03:00"
subsystem: i915 DSI power-ladder / E3 rail-survival probe
tags: [kernel-patch, i915, dsi, rail-probe, ci, fail-fast]
requires: [51-03]
provides: [e3-rail-probe-patch, e3-kernel-ci-candidate]
affects: [51-04, 53]
tech_stack:
  added: []
  patterns: [generated-diff-from-pristine-v7.0, device-compile-proof, ci-grep-anchors, fail-fast-falsification]
key_files:
  created: [patches/d330_dsi_e3_rail_probe.patch]
  modified: [.github/workflows/build-kernel.yml,
             .planning/phases/51-keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified/51-05-PLAN.md,
             .planning/phases/51-keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified/51-05-SUMMARY.md,
             docs/research/RESUME_FIX_LEDGER.md]
decisions:
  - "E3 rides the pinned E1 keep-hot baseline (CI applies E1 then E3 in order); d330_82h0_panel helper comes from E1, so E3 cannot be applied without E1"
  - "Patch anchored after MIPI_SEQ_INIT_OTP in intel_dsi_pre_enable (post link re-train, pre display-on), exact hunk offset re-derived against the post-E1 tree"
  - "One-shot LP DCS read (0x04) is zero-expectation bonus — verdict must come from GPIO 144/160 rail state + X=Y dump, per plan must_haves"
  - "Fail-fast: first falsifying machine evidence ends the rung; no same-day retry"
---

## Summary

**E3 rail-survival rung: FALSIFIED (fail-fast).** The E3 kernel (E1 keep-hot
+ one-shot LP DCS read probe) built green on CI and deployed to the device,
but the suspend session produced decisive falsifying evidence: the E3 probe
fired once (`ret=4 avail=0 data=00 00 00` — the phase-50-proven dead DCS
path, zero-expectation bonus) while both E1 skip markers (`skip SHUTDOWN
(keep-hot)`, `skip DISPLAY_OFF/ASSERT_RESET/POWER_OFF (keep-hot)`) are
**ABSENT** from dmesg for the entire boot, even though both marker strings
and the `d330_82h0_panel` symbol are provably compiled into the running
module (srcversion `461CC27A…DCA`, `nm` + `strings` confirmed). The teardown
skip never engaged; the full panel teardown ran; the probe fired because the
panel was already torn down, not because the rails were cut.

## Machine evidence

- E3 kernel: `7.0.14-d330-fix`, sha `29BDCBF1…01A`, CI run 39076173009
  (all grep-proofs green, apply step E1-then-E3 confirmed).
- Deploy: rollback deb `C30E12ED…125F` verified on device before install;
  E3 deb installed after sha-verify; reboot into E3 confirmed via `uname -r`.
- dmesg marker set this boot: **only** the E3 probe line
  `[28205.784739] i915 … e3-probe: DCS read ret=4 avail=0 data=00 00 00`.
- Skip markers: **none** (`dmesg | grep "D330 82H0"` returns the probe line
  only; journalctl boot 0 shows `PM: suspend entry (deep)` at 11:13:56 and
  `PM: suspend exit` at 11:14:12, no keep-hot markers between).
- Module verification: `strings i915.ko | grep "skip DISPLAY_OFF/…"` and
  `nm i915.ko | grep d330_82h0_panel` both hit — gating logic is present
  and compiled in, it simply never fired.

## What is proven vs what is missing

**Proven:** the E1 keep-hot teardown skip (suspend_commit_in_progress gate
on `intel_dsi_disable` / `intel_dsi_post_disable`) does not engage on a real
S3 suspend on the D330, even with the gating logic verifiably compiled into
the running kernel. This is the same skip-absent condition that falsified E1
on 17 Oct (51-03), now reproduced on a clean E1+E3 kernel where the arming
race explanation is ruled out — the gate itself never becomes true at
`intel_dsi_disable` time.

**Missing:** the session's post-capture block did not execute; no GPIO
144/160 rail state file, no fresh resumefast/resumelate dumps, no X=Y
operational-set verdict. The rails-alive vs rails-cut discriminator
(51-05's real verdict source) never ran. The rails question is technically
still open — the E3 probe was only a bonus, and the skip-absent evidence
short-circuits the rung before the rail discriminator can be reached.

## Verdict routing

The rung cannot produce a rails verdict because its precondition (E1 skip
markers firing) is falsified. Per plan 51-05 must_haves and the phase-51
ladder: the rails question is **ambiguous** (no rail evidence captured, no
skip engaged) → routes to **Phase 53 buy-gate**. This is the documented
escalation path (51-06 fully-falsified branch) — the hardware
logic-analyzer probe is the next instrument.

## Ledger

Row 33 appended to `docs/research/RESUME_FIX_LEDGER.md` as a
re-confirmation of row 11 (keep the panel powered / `intel_dsi_post_disable`
early-return) with the suspend_commit_in_progress-gated keep-hot patch,
stronger machine evidence. Count line 32 → 33. `test_pitfalls_ledger.sh`
exits 0 (4/0). One per-string marker (`0x160018`) added to 51-02-SUMMARY.md
for the pre-existing X=Y literal match against row 4.

<!-- planner-discipline-allow: intel_dsi_post_disable -->
<!-- planner-discipline-allow: 0x160018 -->
<!-- planner-discipline-allow: MIPI_SEQ_INIT_OTP in intel_dsi_pre_enable -->
<!-- historical disproof record: falsified lever mentions only, no fix proposal -->
