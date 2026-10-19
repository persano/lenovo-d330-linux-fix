---
phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
plan: 01
subsystem: infra
tags: [kernel, patches, blissos, ci, git-apply, i915, crimson]

# Dependency graph
requires: []
provides:
  - android-generic/kernel_common `hm/crimson` pre-verified 6.6 patch set (CCS + GLK) passing the exact `git apply --check` gate the Phase 57 CI workflow will run
  - crimson pre-verification evidence record in patches/android/README.md (tip SHA, kernel version, per-patch results, per-file adaptations)
affects: [57-blissos-ci-kernel-build-workflow, 58-blissos-boot-test-usb, 61-blissos-usb-publication]

# Actuals (#2632)
actuals:
  tokens: 3007
  tasks: 2
  commits: 0

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "android-generic/kernel_common @ hm/crimson as the live BlissOS x86 kernel source (supersedes stale BlissRoms kernel_common)"
    - "first-step `git apply --check` patch gate, CCS before GLK, against a fresh shallow fetch"

key-files:
  created: []
  modified:
    - patches/android/d330_android_x86_6.6.patch
    - patches/android/README.md

key-decisions:
  - "CCS patch adapted minimally to crimson deltas: pre-intel_display-refactor i915 API (struct drm_i915_private *i915), pps_init_delays() anchor, orientation quirks table re-anchor; skl_universal_plane.c (critical CCS fix) untouched — context matched crimson exactly"
  - "Crimson already ships an upstream D330-10IGL orientation quirk; the patch's re-anchored table entry duplicates it (first-match wins, identical driver_data) — kept, never deleted, documented in README"
  - "Structural defect found and fixed: committed CCS patch hunk headers had wrong line counts (failed against ANY tree, not just crimson) — headers recounted, content preserved, no force-apply anywhere"

patterns-established: []

requirements-completed: [AUDIT-03]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Crimson pre-verified 6.6 patch set (CCS + GLK) with evidence record in patches/android/README.md"
    requirement: AUDIT-03
    verification:
      - kind: other
        ref: "git apply --check gate run via git-bash against fresh shallow clone of android-generic/kernel_common @ hm/crimson (tip 447ff15184f6dd2e0d010f7fba9af1d886bd7443, kernel 6.6.129) + grep anchors + scripts/test_pitfalls_ledger.sh (passed=4 failed=0)"
        status: pass
    human_judgment: false

# Metrics
duration: 30min
completed: 2026-10-19
status: complete
deferred_commit: true
plan_head_before: 0ca259478ee9b2a1092bfd173bd92b9d41466df2
plan_head_after: 0ca259478ee9b2a1092bfd173bd92b9d41466df2
---

# Phase 57 Plan 01: Crimson Patch Pre-Verification Summary

**Both android 6.6 patches now pass `git apply --check` against android-generic/kernel_common @ hm/crimson (6.6.129) — the exact Phase 57 CI gate green locally; CCS patch adapted per file/hunk to crimson deltas and recorded in README**

## Performance

- **Duration:** 30 min
- **Started:** 2026-10-19T23:02:23Z
- **Completed:** 2026-10-19T23:32:41Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fresh shallow clone of `android-generic/kernel_common` @ `hm/crimson` obtained at `C:/Users/Familia/AppData/Local/Temp/opencode/phase57-kernel_common` — tip `447ff15184f6dd2e0d010f7fba9af1d886bd7443`, kernel **6.6.129** (matches locked decision 1).
- Task 1 gate ran exactly as the CI workflow will (CCS first, then GLK, plain `git apply --check`, no `--3way`/`-f`): GLK passed clean; CCS failed — captured verbatim (`patch fragment without header ...:44`, then `patch does not apply` in 4 of 5 files after `--recount` diagnosis) and carried into Task 2 as planned. Initial failure evidence preserved at `.git/phase57-task1-gate-initial-fail.log`; pass evidence at `.git/phase57-task1-gate.log`.
- Task 2: CCS patch adapted minimally per file/hunk to crimson (details in `patches/android/README.md` crimson pre-verification block); gate re-run green; both patches applied for real in CCS-then-GLK order; all four grep-anchor groups found (`lenovo_ideapad_d330_10igl_800x1280`, `dmi_match(DMI_PRODUCT_NAME, "82H0")` + `intel_fb_is_ccs_modifier`, `Running INIT_OTP (GPIO/delay only) as DEASSERT_RESET`, `IS_GEMINILAKE`).
- Ledger gate `scripts/test_pitfalls_ledger.sh` green: `passed=4 failed=0`.

## Deferred Commits

All code changes uncommitted — will be committed by /gsd-ship (deferred_commit_mode, single-commit-at-ship).

- `feat(57-01)`: pre-verify android 6.6 CCS/GLK patches against crimson hm/crimson, adapt CCS patch to crimson deltas, record pre-verification in README — files: patches/android/d330_android_x86_6.6.patch, patches/android/README.md

(Task 1 modified no repo files — gate evidence lives under `.git/` and in this summary.)

## Files Created/Modified
- `patches/android/d330_android_x86_6.6.patch` - CCS patch: hunk headers recounted, 4 of 5 files re-anchored/adapted to crimson context + pre-refactor i915 API; `skl_universal_plane.c` hunks byte-identical (context matched crimson exactly)
- `patches/android/README.md` - crimson pre-verification block: date, tree, tip SHA, kernel version, per-patch check results, per-file/per-hunk adaptation record

## Decisions Made

- **Re-anchor, never delete:** the plan forbids deleting hunks to pass the gate. Where crimson already ships equivalent functionality (native D330-10IGL orientation quirk), the patch entry was re-anchored to land after it and documented as behaviorally inert instead of being removed.
- **Pre-refactor API adaptation:** crimson's i915 predates the `intel_display` refactor, so added lines use `struct drm_i915_private *i915` / `&dev_priv->drm` rather than the AOSP `display` API; `pps_init_delays()` replaced AOSP's `intel_pps_init_delays()`.
- **`git apply --recount` used as diagnosis only:** it proved which failures were header-count defects (all files) vs genuine crimson context deltas (4 of 5 files); the shipped fix is corrected headers in the patch file itself, since CI runs plain `--check`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CCS patch hunk headers carried wrong line counts**
- **Found during:** Task 1 (crimson gate run)
- **Issue:** Committed `d330_android_x86_6.6.patch` hunk headers declared line counts that did not match their hunk bodies (e.g. quirks.c hunk 1: header `-192,6 +192,11` over a 7-context/12-line body). `git apply --check` failed with `patch fragment without header` against **any** tree — the patch was never apply-clean as committed, contradicting the v11.0 "source-verified" claim for this specific file.
- **Fix:** All hunk headers recounted from hunk bodies (mechanical, added/context lines preserved); then genuine crimson deltas in 4 files adapted per plan Task 2 (see README block, items 1-6).
- **Files modified:** patches/android/d330_android_x86_6.6.patch
- **Verification:** `git apply --check` exits 0 for both patches against fresh crimson clone; real apply + all grep anchors land; ledger gate 4/0.
- **Committed in:** deferred (see Deferred Commits)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Fix is exactly the plan's anticipated Task 2 adaptation path; no scope creep, no force-apply, no hunk deleted.

## Issues Encountered

- **Windows checkout of the kernel tree failed on clone** (`unable to checkout working tree`): Windows NTFS reserves `aux.c`-style device names. Fixed in the temp clone only with `core.protectNTFS=false` + `core.longpaths=true`, then `git reset --hard HEAD` to repair the index. 13 unrelated netfilter/`litmus` files show as modified after checkout (Windows smudge artifacts) — pre-existing in the clone, unrelated to patch targets, untouched.
- **Task 2 verify ran after Task 1's real apply** — re-`--check` failed against the already-patched working tree (expected; patches do not apply twice). Resolved by restoring the clone to pristine (`git checkout -- .`) before the final verify; Task 2 verify then passed end-to-end.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 57-02 (workflow) can wire the same gate command sequence; the local predictor for its first step is green at tip `447ff15184f6dd2e0d010f7fba9af1d886bd7443`.
- Branch tip is mutable (threat T-57-01, transferred): CI re-verifies against a fresh fetch each dispatch — local evidence is pinned to the recorded SHA only.
- Clone kept in place at `C:/Users/Familia/AppData/Local/Temp/opencode/phase57-kernel_common` (pristine, patches restored) for any verify re-run.

## Threat Flags

None — no security-relevant surface beyond the plan's threat model (read-only consumption of the third-party clone; no scripts executed from it).

## Self-Check: PASSED

- FOUND: patches/android/d330_android_x86_6.6.patch (adapted, gate-clean)
- FOUND: patches/android/README.md (crimson pre-verification block, `hm/crimson` present)
- FOUND: both `git apply --check` green + ledger gate `passed=4 failed=0` (TASK2-VERIFY-PASS)
- commits: 0 with code changes = deferred by design (deferred_commit_mode) — planned messages recorded under Deferred Commits; code committed by /gsd-ship

---
*Phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches*
*Completed: 2026-10-19*
