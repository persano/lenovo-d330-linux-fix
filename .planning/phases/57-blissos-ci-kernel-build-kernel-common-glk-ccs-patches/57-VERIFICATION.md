---
phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
verified: 2026-10-20T04:05:47Z
status: passed
score: 3/3 must-haves verified
human_validation: PASSED 2026-10-20 — user chose "Validate now" and authorized the agent-run dispatch (deviation from the user-action convention, noted here). Dispatch history: run 39362222155 red at configure (dangling drivers/kernelsu symlink → submodule init, fix cee06d6); run 39363362080 red at build (crimson CONFIG_WERROR=y × gcc -Werror=implicit-fallthrough → scripts/config --disable WERROR, fix 3710c8a); run 39365529173 SUCCESS (2026-10-20T03:40Z). Artifact blissos-kernel (14,046,854 B) downloaded; bzImage/System.map/.config hashes match SHA256SUMS; CCS symbols quirk_lenovo_d330_pps + lenovo_ideapad_d330_10igl_800x1280 present in System.map (binary-level proof); GLK landed via CI gate grep in the same green run (glk_fixup_mipi_sequences is static, correctly absent from System.map). Optional CI negative test deferred: red-on-broken is machine-proven locally (.git/phase57-task1-gate-initial-fail.log) + structurally guaranteed (gate-first + set -e + upload-on-success-only). Re-confirmed 2026-10-20T04:05Z by this refresh: gh run view 39365529173 => conclusion success; both red runs => 0 artifacts; artifact hashes + System.map symbols re-verified locally.
covered_files: [".github/workflows/build-blissos-kernel.yml",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-PLAN.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-SUMMARY.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-PLAN.md",".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-SUMMARY.md","patches/android/README.md","patches/android/d330_android_glk_reset_fix_6.6.patch","patches/android/d330_android_x86_6.6.patch"]
covered_digest: "v3:sha256:8b5961d276b80e960fcc493e234436578f6c66b6a70981901363847071ea7eb5"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 3/3
  previous_verified: 2026-10-19T23:57:35Z
  gaps_closed:
    - "Human Verification 1 (live dispatch + green run + artifact download) — closed by run 39365529173 (gh-confirmed success) and the downloaded artifact (hashes match SHA256SUMS)"
  gaps_remaining: []
  regressions: []
---

# Phase 57: BlissOS CI Kernel Build Verification Report (refresh)

**Phase Goal:** Anyone can produce the patched BlissOS kernel from CI alone — dispatch the workflow, get a green job, download the `bzImage`; publishing an unpatched kernel is structurally impossible.
**Verified:** 2026-10-20T04:05:47Z
**Status:** passed
**Re-verification:** Yes — refresh of 2026-10-19T23:57:35Z pass after covered source changed (`cee06d6` submodule init, `3710c8a` CONFIG_WERROR disable) and the formerly outstanding live CI run closed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: `gh workflow run` dispatches the workflow; the green run publishes a `bzImage` artifact downloadable from Actions | ✓ VERIFIED | Live run **39365529173** `conclusion: success`, started 2026-10-20T03:40:29Z (`gh run view`, raw JSON below); artifact `blissos-kernel` 14,046,854 B, digest `sha256:ffd4a4e9…`; downloaded copy at `C:\Users\Familia\AppData\Local\Temp\opencode\blissos-kernel-check` holds bzImage (12,940,288 B), System.map, `.config`, SHA256SUMS — all three SHA256 hashes match (recomputed this session). Dispatch-only shape: `build-blissos-kernel.yml:15-21` (`on: workflow_dispatch`, one `ref` input, default `hm/crimson`); README:108 documents the command. |
| 2 | SC2: gate step re-verifies both patches with `git apply --check` against the fresh fetch, before any build step; red = no artifact | ✓ VERIFIED | Structure: gate step at workflow:72-86 strictly precedes Configure (88) / Build (109) / Upload (119), all under `set -euxo pipefail`; both `--check`s (76-77) before either apply. **Runtime proof:** green run's step list shows `Patch gate … success` then Configure/Build/Upload all success (gh api jobs); runs 1 (39362222155, failed at Configure) and 2 (39363362080, failed at Build) each published **0 artifacts** — red job ⇒ no artifact, observed live. Red-on-broken patch itself: local predictor `.git/phase57-task1-gate-initial-fail.log` (`error: patch fragment without header …:44`, `CCS exit=128`) |
| 3 | SC3: `scripts/test_pitfalls_ledger.sh` exits 4/0 green | ✓ VERIFIED | Re-run this session: `passed=4 failed=0`, EXIT=0 (raw output below) |
| 4 | 57-01: patches pass the exact CI gate; adaptations documented per file; never force-applied | ✓ VERIFIED | README:24-87 (crimson record: tip `447ff15184f6dd2e0d010f7fba9af1d886bd7443`, kernel 6.6.129, per-patch results, per-file adaptations 1-6); `--3way`/force-`-f` absent from the workflow (only hit is the comment at line 70); grep anchors are `+`-added lines (quirks 2, quirk_lenovo_d330_pps 2, 82H0 1, GLK glk_fixup_mipi_sequences 2, INIT_OTP 1); CI gate step green in run 39365529173 re-verifies both patches against the fresh fetch |
| 5 | 57-02: single `blissos-kernel` artifact with bzImage/System.map/.config/SHA256SUMS; build outputs feed SHA256SUMS + upload | ✓ VERIFIED | Workflow:109-131 (build copies to `$BUILD/out`, `sha256sum` there, `upload-artifact@v7` name `blissos-kernel`, 4 paths, `include-hidden-files: true`); live artifact contains exactly those 4 files and `sha256` of each matches `SHA256SUMS`; `.config` shipped by the green run carries `# CONFIG_WERROR is not set` + `CONFIG_DEBUG_INFO_NONE=y` (confirms `3710c8a` landed in the built kernel) |

**Score:** 3/3 roadmap success criteria verified (live CI evidence included); 5/5 plan truths verified. `behavior_unverified: 0` — the SC2 ordering/no-artifact invariant now has runtime evidence (two red runs with 0 artifacts, gate step success on the green run), not just structure.

### Live CI Evidence (closes former Human Verification 1)

```
gh run view 39365529173 --repo persano/lenovo-d330-linux-fix --json displayTitle,conclusion,status,startedAt,updatedAt,workflowName
{"conclusion":"success","displayTitle":"Build BlissOS Kernel (kernel_common)","startedAt":"2026-10-20T03:40:29Z","status":"completed","updatedAt":"2026-10-20T03:48:23Z","workflowName":"Build BlissOS Kernel (kernel_common)"}

gh run list --workflow build-blissos-kernel.yml --limit 4  (raw JSON)
[{"databaseId":39365529173,"conclusion":"success","createdAt":"2026-10-20T03:40:29Z"},
 {"databaseId":39363362080,"conclusion":"failure","createdAt":"2026-10-20T03:15:48Z"},
 {"databaseId":39362222155,"conclusion":"failure","createdAt":"2026-10-20T03:03:03Z"}]

gh api .../runs/39365529173/jobs   (step conclusions, green run)
Set up job/Checkout/Free disk/Toolchain/Fetch/Patch gate — check, apply (CCS then GLK)/Configure/Build/Upload/Post/Complete => all success

gh api .../runs/{39362222155,39363362080}/jobs  (failed steps)
RUN 39362222155 => {"conclusion":"failure","failed":["Configure (x86_64_defconfig, no debug info)"]}
RUN 39363362080 => {"conclusion":"failure","failed":["Build kernel bzImage"]}

gh api .../runs/{39362222155,39363362080}/artifacts
RUN 39362222155 artifacts=0
RUN 39363362080 artifacts=0

gh api .../runs/39365529173/artifacts
{"digest":"sha256:ffd4a4e9c1dd5360c2502eec43bf6292ecb23eae2fa75454aad21a7bfa08a5a5","expired":false,"name":"blissos-kernel","size_in_bytes":14046854}
```

Local artifact verification (recomputed this session, `Get-FileHash -Algorithm SHA256` vs `SHA256SUMS`):

```
31990f88c6a7a277a6a6c348dceb7794d576e61c84f3364753e42d24fcc0535c  bzImage     MATCH
b06bd7f6d212e3b3a7d81b61ce9615774effa111107ca93d8d8b3ea72ae7ecd1  System.map  MATCH
5234f79282edc74c3240ddede0a4956d868b9186c4fa9557a0e47948e0dd2dd5  .config     MATCH

System.map symbols (CCS patch landed in the final binary):
ffffffff818ad6b0 t __pfx_quirk_lenovo_d330_pps
ffffffff818ad6c0 t quirk_lenovo_d330_pps
ffffffff822c3f40 d lenovo_ideapad_d330_10igl_800x1280

GLK: glk_fixup_mipi_sequences absent from System.map — expected, the function is `static`; it is proven landed by the CI gate's grep anchors (workflow:85-86), which passed as a step in the same green run.
```

Fix provenance, both documented in workflow comments:

| Fix | Commit | Evidence in run history |
|-----|--------|--------------------------|
| `git submodule update --init --depth 1` after clone (workflow:60-63) | `cee06d6` | run 1 failed at Configure (`drivers/Kconfig` can't open `drivers/kernelsu/Kconfig`) |
| `scripts/config --disable WERROR` (workflow:99-103) | `3710c8a` | run 2 failed at Build (`-Werror=implicit-fallthrough`, `arch/x86/kernel/cpu/intel.o`); shipped `.config` now reads `# CONFIG_WERROR is not set` |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/build-blissos-kernel.yml` | dispatch-only BlissOS kernel CI, gate first, single artifact, no debt markers | ✓ VERIFIED | 131 lines, read in full this session; `permissions: contents: read`; `env: REF` (injection-safe); `TBD\|FIXME\|XXX` = 0 hits; `scripts/test_ci_workflows.sh` 5/5; actionlint (lint-workflows) green on all 3 latest runs (39365528160 = same commit as the green build) |
| `patches/android/d330_android_x86_6.6.patch` | CCS patch, crimson-adapted, gate-clean | ✓ VERIFIED | 0 debt markers; anchors `+`-added; gate step green in run 39365529173 |
| `patches/android/d330_android_glk_reset_fix_6.6.patch` | GLK patch, gate-clean | ✓ VERIFIED | 0 debt markers; anchors `+`-added; gate step green in run 39365529173 |
| `patches/android/README.md` | crimson pre-verification record + CI/dispatch docs | ✓ VERIFIED | Lines 24-87 (record), 100-117 (CI build section, dispatch command, no-polling rule) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Patch gate step | Build step | Step ordering in same job | ✓ WIRED | Gate (72) before Configure (88), Build (109), Upload (119); `set -euxo pipefail` at 74; confirmed by step order/conclusions in the live green run and by both red runs' failure points |
| Build outputs | SHA256SUMS + upload | `$BUILD/out` shared path | ✓ WIRED | `BUILD="$RUNNER_TEMP/kbuild"` exported (56-64); build copies there (114-115); `sha256sum` in that dir (116-117); upload reads `${{ runner.temp }}/kbuild/out/` (127-131) — same directory; proven live by artifact contents |
| Repo patch files | crimson tree | `git apply --check` vs fresh fetch | ✓ WIRED | workflow:57-63 fresh shallow clone + submodule init, `--check` on `$GITHUB_WORKSPACE/patches/android/*.patch` (76-77); gate step success in run 39365529173 = live green link |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|----------|---------------|--------|--------------------|--------|
| `blissos-kernel` artifact | `$BUILD/out/{bzImage,System.map,.config}` | real `make bzImage` in fetched `kernel_common` (workflow:109-117) | yes — 12,940,288 B bzImage, 7,408,801 B System.map, 143,522 B `.config` from the green run | ✓ FLOWING |
| `SHA256SUMS` | `sha256sum` of the 3 build outputs | same `$BUILD/out` dir | yes — 3 hashes, each matching a recompute locally | ✓ FLOWING |
| Gate input patches | `$GITHUB_WORKSPACE/patches/android/*.patch` | repo files read from checkout | yes — gate step green/red tracks the actual patch bytes (local red predictor used the same files) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Ledger gate 4/0 (SC3) | `bash -c '… && scripts/test_pitfalls_ledger.sh'` (git-bash) | `passed=4 failed=0`, EXIT=0 | ✓ PASS |
| Workflow structure gate | `scripts/test_ci_workflows.sh` (python3 shim → `/c/Python313/python`; host WindowsApps `python3` alias broken, pre-existing, repo untouched) | 5 workflows `[OK]`, EXIT=0 | ✓ PASS |
| Green run conclusion | `gh run view 39365529173 --json …` | `conclusion:"success"` | ✓ PASS |
| Red runs publish no artifact | `gh api …/runs/{39362222155,39363362080}/artifacts` | `artifacts=0` both | ✓ PASS |
| Artifact checksums | `Get-FileHash` vs `SHA256SUMS` | 3/3 MATCH | ✓ PASS |
| CCS symbols in binary | `Select-String System.map` | `quirk_lenovo_d330_pps`, `lenovo_ideapad_d330_10igl_800x1280` | ✓ PASS |
| WERROR fix in shipped config | `Select-String .config` | `# CONFIG_WERROR is not set`, `CONFIG_DEBUG_INFO_NONE=y` | ✓ PASS |
| Added-only grep anchors | `Select-String -Pattern '^\+.*<anchor>'` on both patches | 8 hits total, all `+` lines | ✓ PASS |
| No force-apply in workflow | `grep --3way\| -f ` on workflow | 1 hit — comment line 70 only | ✓ PASS |
| Red-on-broken patch predictor | `.git/phase57-task1-gate-initial-fail.log` (recorded) | `error: patch fragment without header …:44`, `CCS exit=128` | ✓ PASS (recorded evidence) |

Raw ledger output:

```
  [OK] ledger-parses
  [OK] gate-fails-on-banned-fix
  [OK] allowlist-marker-honored
Ledger gate: files=38 hits=0
  [OK] pristine-tree-passes

==========================================================
 Ledger gate suite summary: passed=4 failed=0
==========================================================
EXIT=0
```

Raw CI-workflow output (python3 shim on PATH):

```
==========================================================
 Lenovo D330-10IGL CI/CD Workflow Verification Tool
==========================================================
Found 5 workflow file(s):
  [OK] build-blissos-kernel.yml (name, triggers, jobs defined)
  [OK] build-iso.yml (name, triggers, jobs defined)
  [OK] build-kernel.yml (name, triggers, jobs defined)
  [OK] build-packages.yml (name, triggers, jobs defined)
  [OK] lint-workflows.yml (name, triggers, jobs defined)
All GitHub Actions workflows validated.
==========================================================
 Workflow verification complete.
==========================================================
EXIT=0
```

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` declared by this phase; the repo's named gates (`test_pitfalls_ledger.sh`, `test_ci_workflows.sh`) were run directly above.

### Decision Coverage

`check.decision-coverage-verify` → `{"skipped":true,"blocking":false,"reason":"no trackable decisions","total":0,"honored":0,"not_honored":[]}` — 57-CONTEXT.md has no trackable `<decisions>` entries. Status impact: none.

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| BLIS-01 (workflow builds BlissOS kernel from `kernel_common` with GLK+CCS applied, publishes `bzImage` artifact) | 57-02 | ✓ SATISFIED | Live green run 39365529173; artifact `blissos-kernel` 14,046,854 B with bzImage/System.map/.config/SHA256SUMS; CCS symbols in System.map; GLK anchors green in gate step |
| BLIS-02 (build fails loudly if either patch fails; unpatched kernel never published) | 57-02 | ✓ SATISFIED | Gate-first + `set -e` + upload-on-success-only; both red runs observed with 0 artifacts; local red-on-broken predictor `CCS exit=128` |
| AUDIT-03 (CI re-verifies both patches via `git apply --check` at build time vs fresh fetch) | 57-01, 57-02 | ✓ SATISFIED | Fresh shallow clone + submodule init per dispatch (51-65), both `--check`s in gate step (76-77), gate step success in the green run |

Note: REQUIREMENTS.md/ROADMAP say "BlissRoms `kernel_common`"; the phase deliberately uses `android-generic/kernel_common @ hm/crimson` per locked decision 1 (recorded tree correction, 57-02-SUMMARY key-decisions). Documented correction, not drift. REQUIREMENTS.md's status table still reads `Pending` for BLIS-01/BLIS-02/AUDIT-03 — that table is flipped by the ship workflow, not by verification (ℹ️ info, not a gap).

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| (none) | `TBD\|FIXME\|XXX` over workflow, README, both patches, both SUMMARYs: 0 hits | — | — |

`advisory:` — none. This refresh is a re-verification pass: no new-scope Step 7 findings were raised; the two changed files (workflow) are in-contract changes to the prior pass's covered source, both fix-commits documented in workflow comments.

### Human Verification Required

N/A — Infrastructure/foundation phase (CI workflow + patches) with no user-facing elements. All three success criteria are machine-verified, and the one formerly outstanding human item (live dispatch + green run + artifact download) is closed by run 39365529173 as documented above.

Residual, non-blocking, user-accepted as deferred (recorded in `human_validation`): the **optional** negative CI test (deliberately corrupt a patch hunk, dispatch, observe red at the gate). Its guarantee is machine-proven three ways — local red-on-broken predictor log, gate-first + `set -e` + upload-on-success-only structure, and two live red runs publishing 0 artifacts. It was never a must-have and does not gate this phase.

### Gaps Summary

None. All three roadmap success criteria hold with live evidence: dispatch → green run 39365529173 → downloadable `blissos-kernel` artifact whose hashes verify; the patch gate re-verifies both patches against the fresh fetch (step green) and red jobs were observed publishing no artifact; ledger gate 4/0. Covered source changed since the prior pass (`cee06d6`, `3710c8a`) — both fixes are in the green run and re-verified here; both repo gates re-run green this session; fresh digest below.

---

**Fingerprint** (from `gsd_run query verification.fingerprint`, copied verbatim):

```
covered_files: [".github/workflows/build-blissos-kernel.yml",
  ".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-PLAN.md",
  ".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-01-SUMMARY.md",
  ".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-PLAN.md",
  ".planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-02-SUMMARY.md",
  "patches/android/README.md",
  "patches/android/d330_android_glk_reset_fix_6.6.patch",
  "patches/android/d330_android_x86_6.6.patch"]
covered_digest: "v3:sha256:8b5961d276b80e960fcc493e234436578f6c66b6a70981901363847071ea7eb5"
```

Note on Step 4 tooling: `gsd_run query verify.artifacts` / `verify.key-links` returned `total: 0` (57-01) and `66 NO_INPUT` (57-02) — both plans declare `must_haves.artifacts`/`key_links` as bare strings, a schema the verb does not parse. Artifact and link verification above was therefore done manually at all four levels (exists, substantive, wired, data-flow) plus live CI run evidence.

---

_Verified: 2026-10-20T04:05:47Z_
_Verifier: the agent (gsd-verifier)_
