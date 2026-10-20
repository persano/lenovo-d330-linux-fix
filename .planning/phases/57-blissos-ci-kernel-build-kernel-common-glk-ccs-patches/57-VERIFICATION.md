---
phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
verified: 2026-10-19T23:57:35Z
status: human_needed
score: 3/3 must-haves verified
covered_files: [".github/workflows/build-blissos-kernel.yml",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-PLAN.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-SUMMARY.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-PLAN.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-SUMMARY.md","patches/android/README.md","patches/android/d330_android_glk_reset_fix_6.6.patch","patches/android/d330_android_x86_6.6.patch"]
covered_digest: "v3:sha256:d16afec43771cd07f94863a26c2f0143cc1988b4b1ad76889b8a888e2c42b9ab"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Dispatch the workflow: `gh workflow run build-blissos-kernel.yml -f ref=hm/crimson` (from a machine with gh auth), then check the run when you choose (no polling per standing rule)"
    expected: "Green run publishing one artifact `blissos-kernel` containing bzImage, System.map, .config, SHA256SUMS; `sha256sum -c SHA256SUMS` passes post-download (also closes REVIEW IN-02: first end-to-end run)"
    why_human: "Live CI dispatch is a user action by standing process rule (never agent-executed); green run + artifact download cannot be machine-produced here. Workflow structure, gate ordering, and the local gate predictor are machine-verified; the build/configure/upload steps have never run end-to-end."
  - test: "Optionally: temporarily corrupt one hunk of a patch, dispatch, observe"
    expected: "Job red at the patch-gate step before any build step; no artifact published"
    why_human: "Requires a live dispatch on a mutated tree; structural guarantee is machine-verified (set -e + gate-first + upload on success only) and a local red-on-broken predictor exists (.git/phase57-task1-gate-initial-fail.log), but the CI negative test itself is a user-triggered action."
---

# Phase 57: BlissOS CI Kernel Build Verification Report

**Phase Goal:** Anyone can produce the patched BlissOS kernel from CI alone — dispatch the workflow, get a green job, download the `bzImage`; publishing an unpatched kernel is structurally impossible.
**Verified:** 2026-10-19T23:57:35Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior 57-VERIFICATION.md)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1 machine-checkable portion: `gh workflow run` dispatches the BlissOS build workflow; workflow is dispatch-only and structurally correct; dispatch command documented | ✓ VERIFIED | `.github/workflows/build-blissos-kernel.yml:15-21` — `on: workflow_dispatch` only, one `ref` input default `hm/crimson`; `scripts/test_ci_workflows.sh` green 5/5; `patches/android/README.md:108` documents `gh workflow run build-blissos-kernel.yml -f ref=hm/crimson`. Live green run = user action → Human Verification 1 |
| 2 | SC2: first step after fetch re-verifies both patches with `git apply --check` against freshly fetched tree; broken patch turns job red BEFORE any build step; no artifact on failure | ✓ VERIFIED | Workflow lines 51-82: fresh shallow clone per dispatch, gate step runs both `--check`s (CCS then GLK) before either apply, all under `set -euxo pipefail`; gate step precedes Configure (84) / Build (100) / Upload (110); upload-artifact has no `if:` → default `success()` only. Local predictor: `.git/phase57-task1-gate.log` (`CCS exit=0`, `GLK exit=0` vs crimson tip 447ff151, kernel 6.6.129); red-on-broken predictor `.git/phase57-task1-gate-initial-fail.log` (`error: patch fragment without header ... :44`, `CCS exit=128`) |
| 3 | SC3: `scripts/test_pitfalls_ledger.sh` exits 4/0 green | ✓ VERIFIED | Run this session: `passed=4 failed=0`, EXIT=0 (raw output below) |
| 4 | 57-01: patches pass the exact CI gate; adaptation documented per file/hunk in README; never force-applied | ✓ VERIFIED | `patches/android/README.md:26-47` — crimson block with tip SHA `447ff15184f6dd2e0d010f7fba9af1d886bd7443`, kernel 6.6.129, per-patch results, per-file adaptations; no `--3way`/`-f` anywhere in workflow or record; both patches present in `patches/android/` |
| 5 | 57-02: single `blissos-kernel` artifact with bzImage/System.map/.config/SHA256SUMS; build outputs feed SHA256SUMS + upload | ✓ VERIFIED | Workflow lines 100-122: build copies to `$BUILD/out`, hashes there, `upload-artifact@v7` name `blissos-kernel`, 4 files, `include-hidden-files: true` (REVIEW WR-02 fix) from `${{ runner.temp }}/kbuild/out/` = `$BUILD` path |

**Score:** 3/3 roadmap success criteria verified (their machine-checkable portions); 5/5 plan truths verified. Live CI evidence outstanding by standing rule → human_needed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/build-blissos-kernel.yml` | dispatch-only BlissOS kernel CI, gate first, single artifact | ✓ VERIFIED | 122 lines, read in full; no stubs; `permissions: contents: read`; injection-safe (`env: REF`, REVIEW WR-01 fix) |
| `patches/android/d330_android_x86_6.6.patch` | CCS patch, crimson-adapted, gate-clean | ✓ VERIFIED | Hunk headers recounted (57-01); anchors `quirk_lenovo_d330_pps` verified as `+`-added lines (patch lines 91, 114) |
| `patches/android/d330_android_glk_reset_fix_6.6.patch` | GLK patch, gate-clean | ✓ VERIFIED | Anchor `glk_fixup_mipi_sequences` verified as `+`-added (patch lines 59, 104) |
| `patches/android/README.md` pre-verification record + CI/dispatch docs | adaptation record + dispatch command | ✓ VERIFIED | Lines 26-47 (crimson block), 100-117 (CI build section, no-polling rule, honest-stop) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Patch gate step | Build step | Step ordering in same job | ✓ WIRED | Gate (line 68) strictly precedes Configure (84) / Build (100) / Upload (110); `set -e` guarantees red-before-build |
| Build outputs | SHA256SUMS + upload | `$BUILD/out` shared path root | ✓ WIRED | `BUILD="$RUNNER_TEMP/kbuild"` exported at fetch (line 56-60); build copies to `$BUILD/out` (105-106); upload reads `${{ runner.temp }}/kbuild/out/` (119-122) — same directory |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Ledger gate 4/0 (SC3) | `scripts/test_pitfalls_ledger.sh` | `passed=4 failed=0`, EXIT=0 | ✓ PASS |
| Workflow structure gate | `scripts/test_ci_workflows.sh` (python3 shim on PATH — host's WindowsApps python3 alias broken, pre-existing, repo untouched) | `build-blissos-kernel.yml [OK]` … 5/5 workflows, EXIT=0 | ✓ PASS |
| Gate red-on-broken predictor | prior run evidence `.git/phase57-task1-gate-initial-fail.log` | `CCS exit=128`, `error: patch fragment without header ...:44` | ✓ PASS (recorded evidence) |
| Added-only grep anchors | `grep -n '^+.*quirk_lenovo_d330_pps' …patch` etc. | 4 hits, all `+` lines | ✓ PASS |

Raw ledger output:

```
  [OK] ledger-parses
  [OK] gate-fails-on-banned-fix
  [OK] allowlist-marker-honored
Ledger gate: files=38 hits=0
  [OK] pristine-tree-passes
 Ledger gate suite summary: passed=4 failed=0
EXIT=0
```

Raw CI-workflow output (with shim):

```
Found 5 workflow file(s):
  [OK] build-blissos-kernel.yml (name, triggers, jobs defined)
  [OK] build-iso.yml (name, triggers, jobs defined)
  [OK] build-kernel.yml (name, triggers, jobs defined)
  [OK] build-packages.yml (name, triggers, jobs defined)
  [OK] lint-workflows.yml (name, triggers, jobs defined)
All GitHub Actions workflows validated.
EXIT=0
```

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` probes declared by this phase; the repo's named gates (`test_pitfalls_ledger.sh`, `test_ci_workflows.sh`) were run directly above.

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| BLIS-01 (workflow builds kernel from `kernel_common`, publishes `bzImage` artifact) | 57-02 | ✓ SATISFIED (structurally; live green run pending user dispatch) | Workflow build+upload steps verified; artifact wiring verified; dispatch documented |
| BLIS-02 (build fails loudly if either patch fails; unpatched kernel never published) | 57-02 | ✓ SATISFIED | Gate-first + `set -e` + upload-on-success-only; red-on-broken local predictor log |
| AUDIT-03 (CI re-verifies both patches via `git apply --check` at build time vs fresh fetch) | 57-01, 57-02 | ✓ SATISFIED | Fresh shallow clone per dispatch (workflow:51-61), both `--check`s in gate step (72-73) |

Note: REQUIREMENTS.md/ROADMAP say "BlissRoms `kernel_common`"; the phase deliberately uses `android-generic/kernel_common @ hm/crimson` per locked decision 1 (recorded tree correction, 57-02-SUMMARY key-decisions). Documented correction, not drift.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| (none) | `TBD|FIXME|XXX` grep over all 4 phase-touched files: 0 hits | — | — |

REVIEW IN-02 (workflow never run end-to-end) remains informational and is subsumed by Human Verification 1.

### Human Verification Required

1. **Live dispatch + green run + artifact download** — run `gh workflow run build-blissos-kernel.yml -f ref=hm/crimson`, check the run when you ask (no polling).
   - Expected: green run, one `blissos-kernel` artifact with `bzImage`, `System.map`, `.config`, `SHA256SUMS`; `sha256sum -c SHA256SUMS` passes.
2. **(Optional) Negative CI test** — corrupt a patch hunk, dispatch.
   - Expected: red at patch gate, before any build step, no artifact.

### Gaps Summary

None. All machine-checkable success criteria hold in the working tree: workflow exists and is dispatch-only with the patch gate as the first step after fetch, gate-before-build + upload-on-success-only makes an unpatched artifact structurally impossible, local predictor evidence is green at crimson tip 447ff151, and both repo gates pass now (ledger 4/0, CI workflows 5/5). Status is `human_needed` solely because the live green run and artifact download are user actions by standing process rule.

---

_Verified: 2026-10-19T23:57:35Z_
_Verifier: the agent (gsd-verifier)_
