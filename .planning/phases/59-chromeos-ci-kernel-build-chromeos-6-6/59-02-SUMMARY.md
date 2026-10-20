---
phase: 59-chromeos-ci-kernel-build-chromeos-6-6
plan: 02
subsystem: infra
tags: [github-actions, ci, kernel, chromeos, workflow-dispatch, artifact]

requires:
  - phase: 59-chromeos-ci-kernel-build-chromeos-6-6 (plan 01)
    provides: chromeos-6.6 patches proven green against real tip a534360e (kernel 6.6.147)
provides:
  - .github/workflows/build-chromeos-kernel.yml (dispatch-only, gate-first, chromeos-kernel artifact)
  - README CI/dispatch documentation incl. depot_tools deviation
affects: [phase-60-usb-boot, phase-61-release]

actuals:
  tokens: 2250
  tasks: 2
  commits: 2

tech-stack:
  added: [github-actions build-chromeos-kernel workflow]
  patterns: [workflow-dispatch-only, patch-gate-before-build, single-artifact-honest-stop]

key-files:
  created:
    - .github/workflows/build-chromeos-kernel.yml
  modified:
    - patches/chromeos/README.md

key-decisions:
  - "Mirrored build-blissos-kernel.yml exactly (action majors v7, free-disk list, apt list, env-indirect ref input, include-hidden-files) — only tree URL/paths/LOCALVERSION/artifact name differ"
  - "No submodule step on the chromeos kernel clone (Phase 57 lesson); every step under set -euxo pipefail so a missing file is an honest red"
  - "Added intel_fb_is_ccs_modifier grep anchor (plan's 6-anchor set) beyond the BlissOS 5-anchor gate"

patterns-established:
  - "Second kernel CI workflow follows the proven Phase 57 shape verbatim; future kernel workflows copy it"

requirements-completed: [CHRM-01, CHRM-02, AUDIT-03]

coverage:
  - id: D1
    description: "build-chromeos-kernel.yml: workflow_dispatch-only with ref input default chromeos-6.6, patch gate first, x86_64_defconfig build, single chromeos-kernel artifact (bzImage/System.map/.config/SHA256SUMS, hidden files included)"
    requirement: CHRM-01
    verification:
      - kind: other
        ref: "scripts/test_ci_workflows.sh lists build-chromeos-kernel.yml [OK]; python shape assertion: chromeos workflow shape OK"
        status: pass
    human_judgment: false
  - id: D2
    description: "Honest-stop contract: red gate or overrun = red job, zero artifacts (CHRM-02); depot_tools deviation documented"
    requirement: CHRM-02
    verification:
      - kind: other
        ref: "workflow header comment + README 'CI build (Phase 59)' section (grep -qF depot_tools + dispatch doc present)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Green CI run publishes chromeos-kernel on first dispatch (AUDIT-03 predictor: local gate pre-verified green in plan 59-01)"
    requirement: AUDIT-03
    verification:
      - kind: other
        ref: "phase-level: orchestrator dispatch after push (not run by this plan)"
        status: unknown
    human_judgment: true
    rationale: "First live dispatch happens post-push at phase level; green-run check is the orchestrator/user's to observe"

duration: 25min
completed: 2026-10-20
status: complete
---

# Phase 59 Plan 02: ChromeOS kernel CI workflow Summary

**Dispatch-only build-chromeos-kernel.yml mirroring the proven BlissOS workflow: patch gate first, x86_64_defconfig build, single honest-stop chromeos-kernel artifact; both repo gates green**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-10-20T04:50Z (approx)
- **Completed:** 2026-10-20T05:05Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `.github/workflows/build-chromeos-kernel.yml` created: `workflow_dispatch`-only, `ref` input default `chromeos-6.6` through env indirection, free-disk + `timeout-minutes: 180`, same apt toolchain, shallow single-branch clone of `chromiumos/third_party/kernel`, patch gate as FIRST step after fetch (both `--check`s, CCS-then-GLK apply, 6 grep anchors), `x86_64_defconfig` + hygiene knobs + `olddefconfig`, `make -j$(nproc) bzImage LOCALVERSION=-d330-chromeos`, single `chromeos-kernel` artifact with `include-hidden-files: true`
- Both repo gates green: `scripts/test_ci_workflows.sh` all `[OK]` (6 workflows incl. build-chromeos-kernel.yml), `scripts/test_pitfalls_ledger.sh` `passed=4 failed=0`
- README gained the "CI build (Phase 59)" section: dispatch command, no-polling rule, artifact contents, gate/honest-stop behavior, depot_tools deviation, overnight dispatch plan; stale "intel_display struct pointers" line corrected post-59-01

## Task Commits

1. **Task 1: build-chromeos-kernel.yml (tracer)** - `72b8496` (feat) — ⚡ Tracer verified end-to-end (automated verify re-run green) before proceeding
2. **Task 2: gates + dispatch documentation** - `3285e21` (docs)

_Committed via `gsd-tools query commit` per orchestrator instruction (not /gsd-ship deferred)._

## Deferred Commits

None deferred — orchestrator instructed task-complete commits via `gsd-tools query commit`; all changes committed (72b8496, 3285e21). Push + first dispatch are orchestrator-owned.

## Files Created/Modified

- `.github/workflows/build-chromeos-kernel.yml` — the Phase 59 CI workflow
- `patches/chromeos/README.md` — CI build / dispatch section

## Decisions Made

- Exact mirror of build-blissos-kernel.yml shape (locked decision 4): only URL, paths, LOCALVERSION, artifact name, and the extra CCS anchor differ
- WERROR disabled as insurance (not observed breakage), comment updated to say so
- actionlint: not on PATH locally — runs in CI via lint-workflows.yml on push (nothing fetched/installed, per plan)

## Deviations from Plan

None — plan executed as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration.

## Next Phase Readiness

- Orchestrator: push to `main`, then `gh workflow run build-chromeos-kernel.yml -f ref=chromeos-6.6` (overnight directive; Phase 57 fix loop, max 3 attempts)
- Phase 60 consumes the `chromeos-kernel` artifact; Phase 61 publishes it
- Flagged for morning review: shallow kernel clone instead of depot_tools full checkout (locked decision 1)

---
*Phase: 59-chromeos-ci-kernel-build-chromeos-6-6*
*Completed: 2026-10-20*

## Self-Check: PASSED

(found: 72b8496, 3285e21, build-chromeos-kernel.yml, README.md)
