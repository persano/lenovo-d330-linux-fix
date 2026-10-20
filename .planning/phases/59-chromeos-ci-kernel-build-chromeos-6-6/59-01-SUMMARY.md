---
phase: 59-chromeos-ci-kernel-build-chromeos-6-6
plan: 01
subsystem: infra
tags: [kernel, chromeos, ci, git-apply, patches, i915]

requires:
  - phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
    provides: shallow-clone + NTFS flags + patch-gate pre-verification pattern (57-01)
provides:
  - chromeos-6.6 patches re-verified (and CCS re-adapted) against real tip a534360e / kernel 6.6.147
  - README pre-verification evidence block with per-file adaptations
affects: [59-02, phase-60-usb-boot, phase-61-release]

actuals:
  tokens: 2700
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns: [local-shallow-clone-patch-gate-predictor]

key-files:
  created: []
  modified:
    - patches/chromeos/d330_chromeos_6.6.patch
    - patches/chromeos/README.md

key-decisions:
  - "CCS patch re-adapted per file/hunk to the real chromeos-6.6 tip tree instead of an honest stop: every functional hunk kept, no force-apply, no hunk deletion (plan's documented adaptation path)"
  - "Kept the adapted 82H0 orientation entry alongside the identical upstream D330-10IGL entry already present in the tree (harmless duplicate, preserves patch scope + grep anchor)"
  - "Removed the trailing git format-patch signature (-- 2.43.0) and fixed a corrupt hunk line count — metadata fixes, not hunk deletions"

patterns-established:
  - "Gate-fails→adapt-to-real-tree→re-run full gate: the CCS patch had been written against a post-intel_display-refactor tree; adaptation re-anchored context/API per file and was re-verified end-to-end"

requirements-completed: [AUDIT-03]

coverage:
  - id: D1
    description: "Both chromeos 6.6 patches pass git apply --check against a fresh shallow chromeos-6.6 checkout (tip a534360e, kernel 6.6.147), CCS then GLK, with grep anchors proven on a real apply"
    requirement: AUDIT-03
    verification:
      - kind: other
        ref: ".git/phase59-task1-gate.log (post-adaptation: CCS exit=0, GLK exit=0; initial failure preserved in .git/phase59-task1-gate-initial.log)"
        status: pass
    human_judgment: false
  - id: D2
    description: "README carries the chromeos-6.6 pre-verification record: date, tip SHA, kernel version, patch order, per-patch results, per-file adaptations"
    requirement: AUDIT-03
    verification:
      - kind: other
        ref: "plan verify: both --check exit 0 on pristine clone + README greps + scripts/test_pitfalls_ledger.sh passed=4 failed=0"
        status: pass
    human_judgment: false

duration: 50min
completed: 2026-10-20
status: complete
---

# Phase 59 Plan 01: ChromeOS 6.6 patch pre-verification Summary

**CCS chromeos-6.6 patch was corrupt and context-mismatched against the real tip; re-adapted per file to tree a534360e (kernel 6.6.147), full gate re-run green, evidence pinned in README**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-10-20T04:15Z (approx)
- **Completed:** 2026-10-20T05:05Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fresh shallow clone of `chromiumos/third_party/kernel @ chromeos-6.6` (tip `a534360e4c71f8cfc8350614f73c7f64124c9a05`, kernel `6.6.147`) via the NTFS-safe `-c core.protectNTFS=false -c core.longpaths=true` flags
- `git apply --check` green for BOTH patches after adaptation; real CCS-then-GLK apply + all six grep anchors proven; clone restored pristine for 59-02's workflow to mirror
- Disproved the v11.0 "applies clean" claim for `d330_chromeos_6.6.patch` with verbatim evidence (`.git/phase59-task1-gate-initial.log`: `error: corrupt patch at ...:45`, CCS exit=128; GLK was clean on first run)
- README pre-verification block records date, tip SHA, kernel version, patch order, per-patch results, and a per-file adaptation table

## Task Commits

1. **Task 1: Fetch tip + run gate locally, re-adapt CCS patch** - `2c1e814` (feat)
2. **Task 2: Document pre-verification in README** - `da6532f` (docs)

_Committed via `gsd-tools query commit` per orchestrator instruction (not /gsd-ship deferred)._

## Deferred Commits

None deferred — the orchestrator instructed task-complete commits via `gsd-tools query commit`; all code changes are committed (2c1e814, da6532f). Push is still orchestrator-owned.

## Files Created/Modified

- `patches/chromeos/d330_chromeos_6.6.patch` — re-adapted to the real chromeos-6.6 tree (same behavior, tree-matching context/API)
- `patches/chromeos/README.md` — pre-verification evidence block

## Decisions Made

- Re-adaptation (not honest stop): the mismatch was context/API drift against a newer-tree basis, fully adaptable per the plan's documented path with behavior preserved and re-verified end-to-end
- Kept a duplicate (but identical, harmless) 82H0 orientation entry next to the upstream D330-10IGL entry so the patch's scope and the `lenovo_ideapad_d330_10igl_800x1280` anchor survive
- Pre-adaptation gate log preserved at `.git/phase59-task1-gate-initial.log` as red evidence

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CCS patch corrupt + written against wrong tree**
- **Found during:** Task 1
- **Issue:** `git apply --check` failed: `error: corrupt patch at ...:45` (wrong hunk line count + trailing `git format-patch` signature), and 4 of 5 files' contexts targeted a post-`intel_display`-refactor tree absent from chromeos-6.6 (`drm_dmi_panel_orientation_data[]`, named `lenovo_ideapad_d330_*` structs, `struct intel_display *` hooks, `intel_pps_init_delays()`); tree API is `orientation_data[]`, `drm_i915_private`, `pps_init_delays()`
- **Fix:** Re-anchored every hunk to the fetched tip (same added behavior; full table in README), removed the non-diff signature trailer, fixed the count; full gate sequence re-run clean (both `--check` exit 0, apply + 6 anchors, pristine restore)
- **Files modified:** patches/chromeos/d330_chromeos_6.6.patch
- **Committed in:** 2c1e814

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** No scope creep; GLK patch untouched.

## Issues Encountered

- Worktree CRLF checkout noise: unrelated netfilter files show `M` in the clone (checkout artifact, pre-existing); excluded from the generated diff via explicit pathspec — no effect on the gate

## Next Phase Readiness

- 59-02 can write the CI workflow against a known-good patch/tree pair
- Risk flagged: `chromeos-6.6` tip is mutable; CI re-verifies at dispatch time (T-59-01)

---
*Phase: 59-chromeos-ci-kernel-build-chromeos-6-6*
*Completed: 2026-10-20*

## Self-Check: PASSED

(found: 2c1e814, da6532f, d330_chromeos_6.6.patch, README.md)
