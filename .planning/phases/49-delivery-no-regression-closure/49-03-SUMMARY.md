---
plan: 49-03
phase: 49-delivery-no-regression-closure
status: complete
completed: 2026-10-16
duration_min: ~20
subsystem: milestone-closure
tags: [guard-chain, sweep, device-endstate, ship-checklist, deferred-commit]
requires: [49-01-SUMMARY.md, 49-02-SUMMARY.md, docs/dumps/re_kit/MANIFEST.sha256, scripts/dsi_mmio_diff.sh]
provides: [49-SHIP-CHECKLIST.md (ship work order), five-bar green sweep record, device end-state verification record, DONE-02 Complete row]
affects: [/gsd-ship (work order: merge instrument/d330-dsi-dump as-is + 46-line ship-commit inventory + push), milestone v9.0 closure]
tech-stack:
  added: []
  patterns: [five-bar-fail-stop-sweep, mechanical-porcelain-inventory, root-shell-debugfs-glob]
key-files:
  created:
    - .planning/phases/49-delivery-no-regression-closure/49-SHIP-CHECKLIST.md
    - .planning/phases/49-delivery-no-regression-closure/49-03-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md (DONE-02 row only → Complete with verbatim sweep results)
decisions:
  - "Branch range recorded as measured (11 commits fdafc43→550cb55), superseding the plan's stale 8-commit figure; endpoints unchanged"
  - "Push-state recorded as measured (main 47 ahead of origin/main), superseding the stale 35 figure"
  - "Dump-node check invocation corrected: debugfs glob must run inside a root shell (non-root ssh glob exits 2)"
metrics:
  duration: ~20 min
  tasks: 2
  commits: 2
deferred_commit: true
actuals:
  tokens: ~3300
  tasks: 2
  commits: 2
---

# Phase 49 Plan 3: Final guard-chain sweep + ship/verification prep Summary

DONE-02 closed machine-green: all five guard bars exit 0 with the pinned
pass counts on the pristine tree; the device end-state re-verified over ssh
(it3 kernel, dump node, both rollback assets sha-matched); the ship work
order (49-SHIP-CHECKLIST.md) built mechanically from a fresh
git status --porcelain (52 lines, all classified, none unaccounted).

## Task 1 — the five-bar sweep (all exit codes recorded, fail-stop never tripped)

| bar | command | result | exit |
|---|---|---|---|
| 1 | `bash scripts/test_pitfalls_ledger.sh` | `Ledger gate: files=51 hits=0`; `passed=4 failed=0` | 0 |
| 2 | `bash scripts/test_dsi_mmio_evidence.sh` | `passed=7 failed=0` (7 [OK] cases) | 0 |
| 3 | `bash scripts/test_dsi_mmio_evidence.sh --fixtures` | `passed=8 failed=0` (5 fixture + 3 backstop [OK]) | 0 |
| 4 | `bash scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --verify` | 65 artifacts all `OK` incl. close1-3 dumps + diffs; `[OK] safety kit verified: all artifacts match docs/dumps/re_kit/MANIFEST.sha256` | 0 |
| 5 | `bash scripts/dsi_mmio_diff.sh --selftest` | `selftest summary: passed=35 failed=0` (A/B/B2/C/D/E/F/G/H/I) | 0 |

Ledger invariant: `## Lever rows: 32` unchanged; zero row appends (rows
30-32 final truth). The selftest flag lives in `scripts/dsi_mmio_diff.sh`
(checked its usage flags first; `test_dsi_mmio_evidence.sh` has no
--selftest), matching the plan's bar 5 command.

## Device end-state (D-12) — pwsh-native ssh, scripted sudo, read-only

- `ssh -o BatchMode=yes santiago-D330 "uname -r"` → `7.0.14-d330-fix`, exit 0.
- Dump node (root-shell glob) →
  `/sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs` present (plus driver
  aliases `dri/1`, `dri/128`), exit 0. First attempt with the glob outside
  the root shell failed (exit 2, "No such file or directory") — non-root
  glob cannot traverse debugfs; corrected invocation is documented in the
  checklist. No display state touched (panel lit; no reload/reboot).
- `sha256sum` on device, exit 0, verbatim match:
  - `deploy_incoming_fea98e575ad2.deb` =
    `fea98e575ad2d2aa5aad0728b1c3c6855e7c14be9fe4d36c0d9a62704d1dc876` ✓
  - `d47_dump_kernel.deb` =
    `ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be` ✓

## Task 2 — 49-SHIP-CHECKLIST.md (the /gsd-ship work order)

Sections (a)-(e) written: (a) DONE-02 close table with the five bars +
corrected full-suite command (with `--kit-dir docs/dumps/re_kit`) verbatim;
(b) branch merges as-is (measured 11 commits fdafc43→550cb55, CI anchors
2× CCS / 2× dump-node / DMI gate / it3 pulse marker; it1 patch stays
git-history-only, ledger row 30) + the 52-line mechanical inventory
(46 ship-commit / 4 never-commit: .gsd/* sentinels + .planning/milestone.lock);
(c) push state (main 47 ahead of origin/main; push at /gsd-ship only);
(d) post-ship device expectations; (e) escalation note (not triggered —
no 49-01 falsifier halt).

Inventory mechanics: 2 modified (.planning/config.json,
docs/research/UPSTREAM_HANDOFF.md) + 50 untracked (26 re-kit dumps/diffs,
19 scripts, 48-02-PROGRESS-task1.md, 4 runtime never-commit). The close1-3
diff files + MANIFEST.sha256 are already tracked and unmodified (verified
via git ls-files — 21 re_kit files tracked); DSI_MMIO_DIFF.md edits are
already in history (no porcelain line).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan facts stale — branch commit count and push-ahead
count corrected to measured values**
- **Found during:** Task 2 read_first (git log / git rev-list)
- **Issue:** 49-03-PLAN said the branch has 8 commits and main is 35 ahead
  of origin/main; measured truth is 11 commits (fdafc43→550cb55) and 47
  ahead. Writing stale counts would violate T-49-03-b (mechanical inventory).
- **Fix:** checklist states the measured numbers with the verbatim commit
  list; range endpoints and decisions unchanged.
- **Files modified:** 49-SHIP-CHECKLIST.md only

**2. [Rule 3 - Blocking] Dump-node check invocation corrected (check-side
only; no device change)**
- **Issue:** first ssh dump-node check (glob outside the root shell) exited
  2 — the non-root ssh user cannot traverse /sys/kernel/debug to expand the
  glob; ls-as-root received an unexpanded literal.
- **Fix:** re-ran with `sudo sh -c 'ls -la /sys/kernel/debug/dri/*/i915_dsi_regs'`
  → exit 0, node present. Read-only; display state untouched.
- **Files modified:** none (documented in checklist §d)

### Plan-requirement substitution (documented, not a deviation class)
- Plan Task 1 also listed `--selftest` as bar 5 in the executor context
  (guessing `test_dsi_mmio_evidence.sh --selftest`); usage-flag check
  confirmed the selftest lives in `scripts/dsi_mmio_diff.sh --selftest`
  exactly as the PLAN.md pinned — plan command used.

## Auth Gates

None (sudo was scripted per the established stdin echo pattern; password
never written to files/logs).

## Known Stubs

None (sweep + checklist + docs; no code paths, no UI, no data wiring).

## Deferred Commits

- None new from this plan — 49-03 modified only .planning/ files, committed
  via the gsd-tools verb (allowed for planning docs). The 46-line
  code/data ship-commit inventory (scripts + re-kit dumps + UPSTREAM_HANDOFF.md
  + .planning/config.json) is recorded in 49-SHIP-CHECKLIST.md section (b)
  and ships via /gsd-ship.

docs commits made here:
- docs(49-03): close DONE-02 from the final sweep + ship checklist work order — 7b3ed62 — REQUIREMENTS.md, 49-SHIP-CHECKLIST.md
- docs(49-03): summary commit — this commit — 49-03-SUMMARY.md

## Self-Check: PASSED

- 49-SHIP-CHECKLIST.md exists (committed in 7b3ed62)
- DONE-02 row reads Complete with verbatim sweep results
- Ledger gate re-run after all writes: exit 0, passed=4 failed=0, files=51 hits=0
- Ledger header still "Lever rows: 32"; zero row appends; zero merges/pushes/code-data commits
