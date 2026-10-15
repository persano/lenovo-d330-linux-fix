---
plan: 48-01
phase: 48-clean-dmi-gated-fix-mmio-guided
status: complete-falsified
completed: 2026-10-15
iterations: 3 of ≤5 (honest closure, DSI_MMIO_DIFF §5.1)
fix_branch: instrument/d330-dsi-dump
fix_branch_commits: [1418a8b, 122a75c, f1914da, 65c0b01, 18c12f7, 41325d1, 550cb55]
---

# 48-01-SUMMARY: The iteration ladder (it1-it3) — all DMI-gated, all falsified by evidence

## What Was Built

Three DMI-gated (82H0) sequence-state candidates on branch
instrument/d330-dsi-dump, each CI-built, device-deployed behind a verified
rollback, and tested with one user-authorized rtcwake session:

| # | Patch (commit) | Variant | CI sha | Verdict (user, verbatim) | Ledger row |
|---|---|---|---|---|---|
| 1 | patches/d330_dsi_device_ready_fix.patch (1418a8b) | Clear retained ULPS_STATE_MASK + DEVICE_READY before the cold-boot probe (fresh-probe branch, reload ordering) | 43b2e7c2…8932 | "Still black" | 30 |
| 2 | patches/d330_dsi_panel_power_cycle.patch (f1914da) | Full panel power cycle at top of pre_enable (assert reset + MIPI_SEQ_POWER_OFF + 1.5 s hold + full re-init) | FEA98E57…C876 | "black but lit" | 31 |
| 3 | patches/d330_dsi_mipio_reset.patch (41325d1) | DSI-block MIPIO reset pulse (drop + re-assert MIPIO_RST_CTRL, ending released) | C2C2CD89…1073 | "Black but lit" | 32 |

<!-- planner-discipline-allow: Clear retained ULPS_STATE_MASK + DEVICE_READY before the cold-boot probe (fresh-probe branch, reload ordering) -->
<!-- planner-discipline-allow: Full panel power cycle at top of pre_enable (assert reset + MIPI_SEQ_POWER_OFF + 1.5 s hold + full re-init) -->
<!-- planner-discipline-allow: DSI-block MIPIO reset pulse (drop + re-assert MIPIO_RST_CTRL, ending released) -->
<!-- planner-discipline-allow: the tree proves SET=release/CLEAR=reset for MIPIO_RST_CTRL -->

Instrument fix riding along (18c12f7): the dump node now re-creates its
debugfs file on every probe (the once-guard kept only for the snapshot
buffer) — an unbind/bind no longer kills the node, which enabled the
decisive working-lit capture.

CI wiring (122a75c → 65c0b01 → 550cb55): each iteration replaced the
previous fix patch's CI application (it1 is git-history-only, ledger row
30); the dump patch and all 5 anchors (2× CCS, 2× dump-node, DMI gate +
it3's unique anchor) proven green in every run.

## The Falsification (the ladder's outcome)

After it3, with the node surviving an unbind/bind, the working-lit state
was captured (panel SHOWING THE IMAGE, post-reload-workaround,
`docs/dumps/re_kit/reload_lit_dsi_regs.txt`). Versus the broken-wake arm:
DSI block 1024/1024 registers IDENTICAL; whole-file delta = 5 GT
monotonic-counter rows. **The MMIO state of the image-showing panel equals
the MMIO state of the black panel** (DSI_MMIO_DIFF §5.1; NO_CLEAN_FIX_PROOF
§7). The mechanism is below host MMIO (panel TCON side); no host register
write or enable-path sequence can fix it. Iterations stopped at 3 of ≤5 per
the disproof discipline — every remaining register-level lever is disproven
BY this evidence, not by budget exhaustion.

## Ledger Gate

`bash scripts/test_pitfalls_ledger.sh` exit 0 (4/4) after every iteration
(row additions 30/31/32, Lever rows 32; markers per the gate's sanctioned
mechanism).

## Key Hashes

- Branch HEAD on origin: 550cb55 (8 commits ahead of the v9.0 start:
  fdafc43, fb86c6a, 30f077c, b753d39, 1418a8b, 122a75c, f1914da, 65c0b01,
  18c12f7, 41325d1, 550cb55). /gsd-ship merges to main.
- CI runs: 38665460355 (it1), 38743898749 (it2), 38789067483 (it3) — all
  SUCCESS, polled inline (FIX-03 strategy).
- Device currently runs the it3 kernel (sha C2C2CD89…1073); rollback chain
  on device: it2 deb (FEA98E57…C876) + d47 dump kernel (ba47df8d…87be),
  both sha-verified on device.

## Deviations from Plan (aggregated across iterations)

1. Plans were authored inline (planner subagent failures, documented at
   plan time); the checker verified them (2 fix rounds, 3rd check PASSED).
2. Research authored inline (3 researcher-spawn 504s) — documented in
   48-RESEARCH.md header.
3. Rollback-asset clobber on the first it1 deploy (upload-name collision)
   — detected by post-deploy sha check, asset re-established (d47 dump
   kernel), script hardened (sha-keyed incoming upload name + overridable
   rollback target). Documented in 48-02-SUMMARY.
4. WSL networking broke mid-session (it2 deploy) — deploy completed via
   git-bash + pwsh-native ssh; session/deploy discipline unchanged.
5. it3 polarity: the tree proves SET=release/CLEAR=reset for MIPIO_RST_CTRL;
   implemented drop+re-assert ending released (research §3's own wording).
6. The device kernel tree carries phase-45 leftovers
   (QUIRK_DSI_RESUME_FULL_CYCLE in intel_display_driver.c + .orig files) —
   untouched throughout; CI builds clean source.

## Self-Check

- Every iteration: patch sha256 recorded, device compile exit 0, CI grep
  anchors green, artifact sha verified host+device, rollback verified
  BEFORE install, one session, verbatim verdict, at-wake dump registered,
  ledger row appended, gate green.
- `## Self-Check: PASSED`
