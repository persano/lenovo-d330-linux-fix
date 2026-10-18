---
phase: 51-keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified
plan: 51-03
status: complete
started: "2026-10-17T17:00:00Z"
completed: "2026-10-17T20:00:00-03:00"
subsystem: i915 DSI power-ladder / E1 keep-hot session
tags: [kernel-patch, i915, dsi, keep-hot, session, x=y-verdict]
requires: [51-01, 51-02]
provides: [e1-skip-evidence, rails-question-open]
affects: [51-04, 51-05]
tech_stack:
  added: []
  patterns: [device-session, x=y-operational-set-verdict, fail-fast-branch-routing]
key_files:
  created: []
  modified: [.planning/phases/51-keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified/51-03-SUMMARY.md]
decisions:
  - "First manual suspend (18:17) produced zero markers — arming race, not a patch defect; superseded by the 19:17 rtcwake diag run which armed correctly"
  - "Verdict branch: skip markers present + no image → middle branch, rails question open, routes to 51-05 (E3)"
  - "E1 rung artifacts fetched to /home/santiago/e1_work/ (capture dir is root-owned, santiago cannot write there)"
---

## Summary

**E1 keep-hot rung: rails question OPEN (not falsified, not success).** The
E1 skip markers fired on the 19:17 rtcwake diag suspend (both
`skip SHUTDOWN (keep-hot)` and `skip DISPLAY_OFF/ASSERT_RESET/POWER_OFF
(keep-hot)` confirmed via `journalctl -k`), the proven call chain
(`intel_display_driver_suspend` → `d330_82h0_panel` →
`intel_dsi_post_disable` ×3) was captured, and the X=Y operational-set check
returned **X=Z (0/7 registers match)** — the panel did not survive.

## Machine evidence

- E1 kernel: `7.0.14-d330-fix`, deb sha `C30E12ED…125F`, installed and
  sha-verified against the rollback (`ba47df8d…87be`).
- First manual suspend (18:17): captures written, **zero skip markers** —
  arming race, superseded.
- rtcwake diag suspend (19:17, function-traced): **both skip markers
  present** + `d330ret` kretprobes. Markers confirmed via `journalctl -k`
  (dmesg buffer is volatile across suspends; the diag run cleared it).
- X=Y verdict: `bash scripts/dsi_mmio_diff.sh` → `verdict: X=Z, 0/7`.
  All 7 operational-set registers mismatched (e.g. `0x6b010=0000b8ea`,
  `0x160018=00000001`).
- Eyes-on (user): "panel lit but in black, so no image."
- Module verification: disasm confirms `movb $0x1,0x808(%rdi)` flag-set,
  gates, and marker strings all present — the skip logic ran, the panel
  still did not survive.

## Verdict routing

Middle branch (51-03:125-127): **skip markers present + no image → rails
question open.** E1 cannot discriminate rails-cut vs
reset-destroyed-state. Routes to **51-05 (E3)** — the lazy rail-survival
probe.

## Artifacts

`/home/santiago/e1_work/{resumefast,resumelate}_dsi_regs.txt`,
`e1_ftrace.txt`, `e1_dmesg_markers.txt` (capture dir `/home/santiago/d330_dsi_capture/`
is root-owned; work moved to chowned `e1_work/`). Fetched to local temp
for the rung record.

## Ledger

No separate E1 row at this point — the rung is not falsified (markers
fired). The falsification record lands with 51-05 (row 33), which records
the keep-hot mechanism's failure to engage on the clean E1+E3 kernel.
