# Phase 59: ChromeOS CI Kernel Build (`chromeos-6.6`) - Context

**Gathered:** 2026-10-20
**Status:** Ready for planning
**Mode:** Smart discuss (auto-accepted recommendations — user asleep under the overnight-autonomy directive "fix it and have it built by morning"; decisions mirror the accepted Phase 57 pattern and ROADMAP success criteria, flagged for morning review)

<domain>
## Phase Boundary

Same CI capability for ChromeOS — a dispatched workflow that verifies the
patches, builds the `chromeos-6.6` kernel, and publishes the kernel artifact —
or an honest, documented stop if the runner cannot hold the build (CHRM-02).
Not in scope: ChromeOS USB boot (Phase 60), release tagging (Phase 61).

</domain>

<decisions>
## Implementation Decisions

### Kernel Source
- Tree: `chromiumos/third_party/kernel` @ branch `chromeos-6.6`
  (chromium.googlesource.com, tip a534360e at gather time), shallow
  single-branch `git clone --depth 1` — direct kernel-repo checkout, NOT the
  full depot_tools platform tree (ROADMAP's parenthetical mentions
  depot_tools; a shallow single-branch kernel clone IS the "freshly fetched
  shallow chromeos-6.6 checkout" the success criterion requires, and avoids
  the runner-disk blowout the depot_tools manifest would cause). Documented
  deviation; flagged for morning review.
- Patches: `patches/chromeos/d330_chromeos_6.6.patch` (CCS) then
  `patches/chromeos/d330_chromeos_glk_reset_fix_6.6.patch` (GLK), CCS
  first — source-verified against the real chromeos-6.6 tree in v11.0
  (`git apply --check` clean, 2026-10-19)
- Ref: branch name is a workflow_dispatch input, default `chromeos-6.6`

### Build Mechanics
- Config: `x86_64_defconfig` + `olddefconfig` (the chromeos tree ships
  `arch/x86/configs/x86_64_defconfig`) + DEBUG_INFO_NONE / WERROR guard
  knobs copied from the proven BlissOS workflow (WERROR here is insurance,
  not observed breakage)
- Toolchain: Ubuntu apt, same package list as build-blissos-kernel.yml
- Runner hygiene: free-disk step + `timeout-minutes: 180`

### Patch Gate & Artifacts
- Gate: FIRST step after clone — `git apply --check` both patches, red
  before any build step, no artifact on failure (AUDIT-03); grep anchors
  prove the code landed
- Dispatch: `workflow_dispatch` only via `gh workflow run`, no polling
- Artifact: single `chromeos-kernel` artifact: bzImage, System.map, .config,
  SHA256SUMS (include-hidden-files: true)
- CHRM-02: runner disk/time overrun = red job + documented stop, never a
  truncated or fake artifact

### the agent's Discretion
- Exact step naming/order details, comment wording
- Whether CCS/GLK grep anchors reuse the BlissOS anchor set (files should be
  identical — same patches, chromeos flavor)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/build-blissos-kernel.yml` — the proven shape from
  Phase 57 (dispatch-only, gate-first, defconfig build, artifact bundle,
  env-indirect input, include-hidden-files, submodule/WERROR lessons)
- `patches/chromeos/d330_chromeos_6.6.patch` + `d330_chromeos_glk_reset_fix_6.6.patch`
  — v11.0 source-verified against the real chromeos-6.6 tree
- `scripts/test_ci_workflows.sh`, `scripts/test_pitfalls_ledger.sh` — gates

### Established Patterns
- CI: manual dispatch, patch gate first, honest-stop on red
- Commits via `gsd-tools query commit`; deferred-commit mode may apply —
  dispatch requires the workflow on main, so a push is needed before the
  first dispatch (Phase 57 precedent: user-approved once, apply same)

### Integration Points
- Phase 60 boots the `chromeos-kernel` artifact on the D330 from USB
- Phase 61 publishes it in the v12.0 release

</code_context>

<specifics>
## Specific Ideas

- The Phase 57 overnight fix loop (watch → fix → re-dispatch, max 3 attempts)
  is the operating pattern for this build's first dispatch

</specifics>

<deferred>
## Deferred Ideas

- Full depot_tools/platform checkout + emerge-$BOARD image build (Phase 60
  boot needs a bootable image, not just bzImage — if a plain kernel artifact
  proves insufficient for USB boot, image assembly becomes Phase 60 scope)

</deferred>
