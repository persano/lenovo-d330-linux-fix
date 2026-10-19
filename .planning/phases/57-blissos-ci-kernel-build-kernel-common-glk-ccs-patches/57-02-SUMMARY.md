---
phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
plan: 02
subsystem: infra
tags: [kernel, blissos, ci, github-actions, workflow-dispatch, patch-gate, artifact]

# Dependency graph
requires:
  - android-generic/kernel_common `hm/crimson` pre-verified 6.6 patch set (CCS + GLK) passing the exact `git apply --check` gate (from 57-01)
provides:
  - `.github/workflows/build-blissos-kernel.yml` — dispatch-only BlissOS kernel CI: patch gate first, `x86_64_defconfig` build, single `blissos-kernel` artifact (bzImage/System.map/.config/SHA256SUMS)
  - documented dispatch command + gate/artifact behavior in patches/android/README.md
affects: [58-blissos-boot-test-usb, 61-blissos-usb-publication]

# Actuals (#2632)
actuals:
  tokens: 1600
  tasks: 2
  commits: 0

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "workflow_dispatch-only heavy build, one `ref` input defaulting to hm/crimson, no push/schedule triggers"
    - "patch gate as FIRST step after fetch: both `git apply --check`s, ordered applies (CCS then GLK, never --3way/-f), grep-anchor proofs; upload-artifact only on job success"

key-files:
  created:
    - .github/workflows/build-blissos-kernel.yml
  modified:
    - patches/android/README.md

key-decisions:
  - "TREE CORRECTION (locked decision 1, milestone-audit record): ROADMAP/REQUIREMENTS historically said 'BlissRoms kernel_common'; the live tree is android-generic/kernel_common @ hm/crimson (6.6.129). The workflow hardcodes that clone URL; only the branch varies. Deliberate correction, not drift."
  - "Both `--check`s run before either apply inside one gate step — a failure of EITHER patch turns the job red before any build step (BLIS-02/AUDIT-03)"
  - "No release publishing in this workflow (permissions: contents: read); Phase 61 owns publication"
  - "AOSP debug-info/signing-key hygiene copied from build-kernel.yml since x86_64_defconfig seeds no distro config"

patterns-established: []

requirements-completed: [BLIS-02, AUDIT-03]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Dispatch-only BlissOS kernel workflow with the patch gate as first step after fetch, single blissos-kernel artifact"
    requirement: BLIS-02
    verification:
      - kind: other
        ref: "scripts/test_ci_workflows.sh lists build-blissos-kernel.yml [OK]; python shape assertion (dispatch-only, gate-before-build, artifact wiring) passed; workflow step ordering reviewed — gate step precedes configure/build/upload"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-10-19
status: complete
deferred_commit: true
plan_head_before: fbd322e878dfacdb64c286648c48d7ec16cfa404
plan_head_after: fbd322e878dfacdb64c286648c48d7ec16cfa404
---

# Phase 57 Plan 02: BlissOS CI Kernel Workflow Summary

**Dispatch-only GitHub Actions workflow ships the patch gate as its first step after fetch (CCS-then-GLK `git apply --check` + grep anchors), builds a standalone `x86_64_defconfig` bzImage from android-generic/kernel_common @ hm/crimson, and publishes one `blissos-kernel` artifact — an unpatched kernel cannot be published**

## Performance

- **Duration:** 25 min
- **Started:** 2026-10-19T20:36:00Z
- **Completed:** 2026-10-19T21:01:00Z
- **Tasks:** 2
- **Files created/modified:** 2

## Accomplishments

- Task 1 (tracer): `.github/workflows/build-blissos-kernel.yml` created mirroring build-kernel.yml's proven shape — `workflow_dispatch` only (one `ref` input, default `hm/crimson`), `permissions: contents: read`, `timeout-minutes: 180`, same free-disk step, apt toolchain (deb-packaging packages dropped), shallow clone of `android-generic/kernel_common`, then the PATCH GATE as the first step after fetch: both `git apply --check`s before either apply, `git apply` CCS first then GLK (no `--3way`/`-f`), four grep-anchor groups proving the code landed. Then `x86_64_defconfig` + disk-hygiene `scripts/config` + `olddefconfig`, `make -j$(nproc) bzImage`, SHA256SUMS over bzImage/System.map/.config, and `actions/upload-artifact@v7` publishing the single `blissos-kernel` artifact. Upload runs only on prior success — red gate, no artifact.
- Task 2: both repo gates green — `scripts/test_ci_workflows.sh` lists the new file `[OK]` (5/5 workflows); `scripts/test_pitfalls_ledger.sh` `passed=4 failed=0`. `actionlint` not on PATH; per plan it was neither fetched nor installed (lint-workflows.yml covers it on push). README gained a terse "CI build (Phase 57)" section documenting the dispatch command, the no-polling rule, the artifact contents, and the gate/honest-stop behavior.
- Tree correction recorded in this summary (key-decisions, above): the historical "BlissRoms kernel_common" naming in ROADMAP/REQUIREMENTS is superseded by locked decision 1's `android-generic/kernel_common @ hm/crimson` — deliberate, for the milestone audit.

## Deferred Commits

All code changes uncommitted — will be committed by /gsd-ship (deferred_commit_mode, single-commit-at-ship).

- `feat(57-02)`: add dispatch-only BlissOS kernel CI workflow (patch gate first, blissos-kernel artifact) + README CI/dispatch docs — files: .github/workflows/build-blissos-kernel.yml, patches/android/README.md

## Files Created/Modified
- `.github/workflows/build-blissos-kernel.yml` — new; 1 job, gate-before-build, single artifact
- `patches/android/README.md` — new section 2 "CI build (Phase 57)" after the patch list (later sections renumbered 3/4); wave-1 crimson pre-verification block untouched

## Decisions Made

- **`BUILD` exported alongside `SRC`** in the fetch step (mirrors build-kernel.yml) so the build/out/SHA256SUMS steps share one path root.
- **Localdebug-info hygiene applied on top of `x86_64_defconfig`** even though defconfig has no debug info by default: the SYSTEM_TRUSTED_KEYS/REVOCATION_KEYS empty-string calls keep the step robust if runner defaults change; all wrapped `|| true` exactly as in build-kernel.yml.
- **README section numbering** renumbered after inserting section 2 (no cross-references to section numbers existed — grep-verified).

## Deviations from Plan

None — plan executed exactly as written. (One in-flight bug caught before verify: the build step initially referenced an unexported `$BUILD`; fixed by exporting it in the fetch step — part of writing Task 1, not a post-hoc deviation.)

## Issues Encountered

- **git-bash `python3` resolves to the broken WindowsApps alias**, so `scripts/test_ci_workflows.sh` cannot run unmodified from git-bash on this host. Worked around with a temp `/tmp/pyshim/python3` shim delegating to the working `python` (uv shim) and prepending it to PATH for the gate runs — repo files untouched.
- **`actionlint` is not on PATH** — skipped per plan ("never fetch or install anything to make that happen").

## User Setup Required

None for setup. Phase-level verification is user-dispatched: run `gh workflow run build-blissos-kernel.yml -f ref=hm/crimson`, expect a green run publishing `blissos-kernel` (BLIS-01); optionally a deliberately broken patch should turn the job red pre-build with no artifact. The executor never dispatches or polls.

## Next Phase Readiness

- Phase 58 consumes the `blissos-kernel` artifact's bzImage; Phase 61 owns publication.
- Branch tip is mutable: every dispatch re-verifies the gate against a fresh fetch (AUDIT-03), so upstream drift turns CI red rather than shipping an unpatched kernel.

## Self-Check: PASSED

- FOUND: `.github/workflows/build-blissos-kernel.yml` (workflow-shape assertion passed: dispatch-only, `hm/crimson`, `git apply --check`, `blissos-kernel`, `timeout-minutes: 180`, no push/schedule)
- FOUND: `scripts/test_ci_workflows.sh` — build-blissos-kernel.yml `[OK]`, all 5 workflows validated
- FOUND: `scripts/test_pitfalls_ledger.sh` — `passed=4 failed=0`
- FOUND: `gh workflow run build-blissos-kernel.yml` in patches/android/README.md (DISPATCH-DOC-PRESENT)
- commits: 0 with code changes = deferred by design (deferred_commit_mode) — planned message recorded under Deferred Commits; code committed by /gsd-ship

---
*Phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches*
*Completed: 2026-10-19*
