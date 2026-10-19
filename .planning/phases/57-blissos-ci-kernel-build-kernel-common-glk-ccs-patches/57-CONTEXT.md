# Phase 57: BlissOS CI Kernel Build (`kernel_common` + GLK/CCS patches) - Context

**Gathered:** 2026-10-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Anyone can produce the patched BlissOS kernel from CI alone — dispatch the
workflow, get a green job, download the `bzImage`; publishing an unpatched
kernel is structurally impossible. Deliverable: a GitHub Actions workflow whose
first step re-verifies both patches with `git apply --check` against a freshly
fetched BlissRoms/android-generic `kernel_common`; a deliberately broken patch
turns the job red BEFORE any build step and no artifact is published
(BLIS-02, AUDIT-03). The ledger gate `scripts/test_pitfalls_ledger.sh` exits
4/0 green. Not in scope: BlissOS USB boot (Phase 58), ISO/image builds.

</domain>

<decisions>
## Implementation Decisions

### Kernel Source
- Tree: `android-generic/kernel_common` @ `hm/crimson` (kernel 6.6.129, last
  push 2026-03-30) — the only live BlissOS x86 tree matching our 6.6 patches;
  ROADMAP's "BlissRoms kernel_common" is stale (2023, max 6.3) and superseded
  by this research finding
- Patches: `patches/android/d330_android_x86_6.6.patch` (CCS orientation) then
  `patches/android/d330_android_glk_reset_fix_6.6.patch` (GLK resume fixup),
  applied in that order
- Ref: branch tip exposed as workflow input, default `hm/crimson`; the patch
  gate fetches fresh sources each run (AUDIT-03)

### Build Mechanics
- Config: `x86_64_defconfig` + `olddefconfig` — standalone bootable kernel for
  USB, not a full BlissOS image build
- Toolchain: Ubuntu apt gcc + flex/bison/libssl-dev/libelf-dev etc. (same
  pattern as the proven `.github/workflows/build-kernel.yml`)
- Runner hygiene: free-disk step + `timeout-minutes: 180` (mirrors
  build-kernel.yml; runner disk is the known constraint)

### Patch Gate & Artifacts
- Gate: FIRST workflow step — shallow-fetch the tree at the requested ref,
  `git apply --check` both patches, exit red on any failure before any build
  step; no artifact published on failure
- Dispatch: `workflow_dispatch` only via `gh workflow run`, no polling
  (standing process rule)
- Artifact: one `blissos-kernel` artifact containing `bzImage`,
  `System.map`, `.config`, `SHA256SUMS`

### the agent's Discretion
- Exact workflow file name, YAML structure, log/step naming
- How `git apply --check` is wired (one step with both patches, or two)
- Whether SHA256SUMS is generated in the artifact-upload step or earlier

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/build-kernel.yml` — proven kernel CI pattern: manual
  dispatch, free-disk step, apt toolchain, patch-apply-and-grep verification,
  `bindeb-pkg`, artifact upload; Phase 57 workflow mirrors its shape
- `patches/android/d330_android_x86_6.6.patch` + `d330_android_glk_reset_fix_6.6.patch`
  — source-verified against AOSP `android15-6.6` (`git apply --check` clean,
  2026-10-19); 6.6 tree family, same as crimson's 6.6.129
- `scripts/test_pitfalls_ledger.sh` — the green (4/0) gate every phase must keep

### Established Patterns
- Patch application in CI: `git apply -p1` + grep anchors proving the code
  landed (build-kernel.yml lines 105-167)
- Dispatch-only triggers; no push/schedule CI for heavy builds

### Integration Points
- Phase 58 consumes the `bzImage` artifact (USB boot); Phase 61 publishes it
  in the v12.0 release

</code_context>

<specifics>
## Specific Ideas

- AUDIT-03 is a milestone process rule: patch-apply verification must run as
  the FIRST step of both build workflows (BlissOS here, ChromeOS in Phase 59)
- CHRM-02's honest-stop principle applies to any CI failure here too: red job,
  never a truncated or fake artifact

</specifics>

<deferred>
## Deferred Ideas

- Full BlissOS ISO/image build with the kernel integrated (out of scope — this
  phase ships the `bzImage` only; USB-writing instructions come in Phase 61)

</deferred>
