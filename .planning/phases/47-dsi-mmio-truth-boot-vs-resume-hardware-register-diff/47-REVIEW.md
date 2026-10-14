---
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
reviewed: 2026-10-14T17:19:34-03:00
depth: standard
files_reviewed: 8
files_reviewed_list:
  - .github/workflows/build-kernel.yml (main + branch 30f077c diff)
  - patches/d330_dsi_dump.patch (via git show 30f077c)
  - scripts/capture_dsi_dumps.sh
  - scripts/dsi_mmio_diff.sh
  - scripts/test_dsi_mmio_evidence.sh
  - docs/research/DSI_MMIO_DIFF.md
  - docs/dumps/re_kit/MANIFEST.sha256 (+ all 27 kit artifacts hash-verified)
  - docs/dumps/re_kit/dsi_regs_diff.txt (+ 4 dump files format/citation-checked)
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 47: Code Review Report

**Reviewed:** 2026-10-14T17:19:34-03:00
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the phase-47 instrumentation set: the kernel dump-node patch (branch `instrument/d330-dsi-dump` @ 30f077c), the CI workflow change on that branch, the capture/diff/test bash scripts, the DIFF research doc, and the registered evidence kit. Reviewed read-only; suite binaries were executed as evidence (selftest, fixtures, real-mode guard, fresh diff rebuild).

**Verified clean (executed, not just read):**

- **Patch security surface holds.** debugfs node created with mode `0600` (root-only); the write handler is trigger-only (`kstrtobool_from_user`, false → no-op); every `intel_de_*` call in the patch is a read — **zero register writes**, no mode changes. Read/write are serialized on `d330_dsi_dump_lock` (write resets+rebuilds the frozen buffer under the lock; reader can never observe a half-built snapshot); concurrent trigger returns `-EBUSY`; buffer-full writes return early. Word math matches the pinned contract: 1024+4096+1024+128+1024 = 7296 records/arm.
- **Kit integrity:** all 37 MANIFEST lines hash-match the on-disk artifacts (`sha256sum -c` and an independent PowerShell `Get-FileHash` pass, 0 mismatches). The 5 newly registered entries (`boot_dsi_regs.txt`, `broken_dsi_regs.txt`, both session-1 dumps, `dsi_regs_diff.txt`) match the sha256s quoted in the doc.
- **Dump format vs pinned contract:** all four dump files parse as 5 `# RANGE` headers, 7296 record lines, 0 skip markers, 0 warnings — exactly the 47-01/47-02 format.
- **Doc evidence is real.** Every one of the 14 §4.1 rows and all §4.2 values were checked against the actual dump bytes at the cited lines (boot/broken lines 3, 6, 19, 34, 36, 39, 40, 1033, 1060, 6306, 6307, 6344, 6369, 6381 — all match; session-1 positions likewise). The "two all-ones constants" claim (0x6b008, 0x138080) is exact (1 all-ones word in each block, all four arms). 0x6b104 session columns (d4000003 → d0000003) verified. Identical counts (1017/4094/1024/128/1019 = 7282 + 14 = 7296) reconcile.
- **Executed suites:** `dsi_mmio_diff.sh --selftest` 26/26 OK; `test_dsi_mmio_evidence.sh` real mode 7/7 OK; `--fixtures` mode 8/8 OK including the non-vacuity backstop. A fresh `dsi_mmio_diff.sh` run over the registered dumps is deterministic (two rebuilds `cmp`-identical).
- **CI anchors (branch diff):** the two new greps are additive; both pre-existing CCS-fix anchors remain, so no existing proof was weakened. `git apply` failure is loud (set -euxo pipefail).

No critical findings. Three warnings below, all fixable without re-capturing hardware.

## Warnings

### WR-01: Arm-global PLL-off skip flag misclassifies corrupted non-DSI sections as "PLL off"

**File:** `scripts/dsi_mmio_diff.sh:196-199` (with the marker bookkeeping at lines 178-180)
**Issue:** `skip[arm]` is keyed by arm only, but the state classifier applies it to *every* range of that arm: `sk = (skip[arm] == 1) ? 1 : 0`. The skip marker semantically belongs to exactly one range (0x6b000-0x6c000 — the code itself only seeds `seen[dsi_lo FS dsi_hi]` from it). Consequence: if the resume arm carries the DSI PLL-off marker and a *different* range (e.g. 0x46000) has a corrupted/missing section header on that arm, that range classifies `skipped-pll-off` and the diff emits the row "DSI block skipped: PLL off" for 0x46000-0x47000 instead of the intended `parse-warning` / "malformed dump". The hardening goal ("zero-record section can never classify readable") holds, but a real corruption signal is masked as the one documented, benign skip reason — on the resume arm, which is exactly the arm where a capture is most fragile. The capture script would separately warn on the per-section count mismatch, so this does not silently corrupt the claim, but the diff artifact itself would carry a wrong interpretation.
**Fix:**
```awk
# in the classification END block — honor the marker only for the DSI range:
sk = (skip[arm] == 1 && p[1] == dsi_lo && p[2] == dsi_hi) ? 1 : 0
if (sk && n == 0)         st = "skipped-pll-off"
else if (n == 0)          st = "parse-warning"
else if (sk)              st = "parse-warning"
else if (f * 10 > n * 9)  st = "unreadable-0xffffffff"
else                      st = "readable"
```
Then add a fixture: marker on resume + a boot-only second range whose header is missing on resume → expect `parse-warning`, not `skipped-pll-off`.

### WR-02: Patch's BSpec machine-hang gate does not cover the DSI PHY range or overlay reads

**File:** `patches/d330_dsi_dump.patch` (`d330_dsi_dump_walk` / `d330_dsi_dump_overlay` in `drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c`)
**Issue:** The patch's own header states the hazard: "accessing DSI registers will hang the machine" when the PLL is in a bad/off state (BSpec MIPI[BXT]). `d330_dsi_dump_walk()` gates only the 0x6b000-0x6c000 block on `bxt_dsi_pll_is_enabled()`. When `!dsi_ok` it still (a) walks 0x160000-0x164000 — the doc itself labels this "BXT/GLK DSI PHY" — and (b) the overlay unconditionally reads 0x160018, 0x162000 (`BXT_PORT_CL1CM_DW0`), 0x16218c, 0x162198, 0x161000 (`BXT_DSI_PLL_CTL`). So the only branch of the instrument never exercised (the gate never tripped on any of the four captures) is exactly the one the BSpec rule warns about, if the rule's scope includes the PHY/MIPIO region. Reads of the PLL registers themselves are safe (that is what `bxt_dsi_pll_is_enabled` does), and empirically the PHY area read fine with the PLL *on*, but PHY reads with the PLL *off* are unproven on this hardware. If the hazard extends there, the instrument hangs the machine precisely in the failure scenario it exists to capture, losing the 18 s window and the session.
**Fix:** Either (a) cite the BSpec clause that PHY/MIPIO (0x160000-0x164000) reads are safe with the DSI PLL off and record that in the patch comment and doc §2, or (b) extend the gate to the PHY range and emit a second, distinct skip marker (e.g. `# SKIPPED: DSI PLL off - PHY reads skipped`) with matching handling in `parse_arm`, the capture script's expected-counts table, and the diff classifier. Cheap to do now while the kernel is still the deployed baseline.

### WR-03: Canonical `dsi_regs_diff.txt` is not reproducible from registered inputs — contradicts the doc's determinism claim

**File:** `docs/dumps/re_kit/dsi_regs_diff.txt` (lines 18-19); claim at `docs/research/DSI_MMIO_DIFF.md:22` and `:307-308`
**Issue:** The doc claims the diff artifact was "generated by `scripts/dsi_mmio_diff.sh` from the two registered session-2 dumps (deterministic: full pipeline rebuild byte-identical)". Executed check: a fresh run of the script over the two registered dumps reproduces the artifact **except for 2 lines** — the artifact's offset cells read `0x138108 GEN6_GT_GFX_RC6` and `0x13816c GEN9_GT_PM_CONFIG`, while the script alone emits bare offsets. Those names come from a `--names` file that is **not registered** in the kit/manifest, so the "full pipeline rebuild byte-identical" claim cannot be reproduced from registered inputs; as committed, the artifact's provenance (machine-computed, deterministic) is overstated and the two name cells are the only non-reproducible content. Everything else (25/27 header lines, values, citations, summary counts) is byte-identical to a fresh rebuild, which confirms the engine itself is deterministic.
**Fix:** Register the names file in the kit + manifest and state the exact rebuild command (`dsi_mmio_diff.sh boot broken --names <file>`), or regenerate `dsi_regs_diff.txt` without names (offsets only; the doc and annex already carry the names) and update its pinned sha256. Either closes the provenance gap; do not leave the artifact as-is with the current §7 wording.

## Info

### IN-01: MANIFEST.sha256 carries 10 duplicate entries; doc's "37 artifacts" phrasing is imprecise

**File:** `docs/dumps/re_kit/MANIFEST.sha256:10-23` (dup lines 1-9 vs 14-23)
**Issue:** 37 manifest lines but only 27 unique artifacts; `bios_raw_8dfae5d4.bin`, `vbt.bin`, `spi2.bin`, both `.efi` GOP/VBT files, `igdkmd64.sys`, both `.inf`, `vbt_decode.txt` each appear twice (identical hashes, so verification still passes). Pre-existing at HEAD (this phase's 5 appended lines are clean); the duplicates also mean `register_one`'s dedup (suffix match, `prepare_safety_kit.sh:122-128`) never removed them — likely they were appended outside that path in an earlier phase. Doc §7 says "37 lines; … all 37 artifacts OK" — 37 lines ≠ 37 artifacts.
**Fix:** One-time cleanup: `awk` the manifest to unique lines (hashes identical so order-safe), re-run verify, and fix the §7 wording to "27 artifacts / 37 lines". Optionally harden `register_one` to also dedupe exact-duplicate lines.

### IN-02: Dead constant `RECORD_BASH_RE`

**File:** `scripts/dsi_mmio_diff.sh:46`
**Issue:** `RECORD_BASH_RE` is defined as the pinned contract regex but never used — the record regex is re-inlined (expanded, mawk-compatible) inside `parse_arm`'s awk. Two copies of the contract regex can drift.
**Fix:** Either delete `RECORD_BASH_RE` or build the awk `valre` from it (e.g. pass `-v valre="$RECORD_BASH_RE"` and drop the `{8}`-expansion comment by expanding it here once).

### IN-03: Capture script's record regex diverges from the pinned contract

**File:** `scripts/capture_dsi_dumps.sh:55`
**Issue:** `RECORD_RE` matches lowercase hex only (`[0-9a-f]{8}` spelled out), while the pinned 47-01/47-02 contract (and the diff script at `dsi_mmio_diff.sh:46`) accepts `[0-9a-fA-F]{8}`. The kernel's `%08x` always emits lowercase, so this cannot bite today — but if a future dump source (or hand-merged dump) used uppercase, capture would under-count records and could spuriously fail the 5000 floor while diff accepts the same file.
**Fix:** Make both scripts derive the regex from one contract definition (uppercase-tolerant), or add a one-line comment in the capture script pinning "kernel emits lowercase; contract tolerates uppercase".

### IN-04: Patch hygiene — redundant self-declaration; node registered for all platforms

**File:** `patches/d330_dsi_dump.patch` (top of `intel_dsi_dump_debugfs.c`; `i915_debugfs.c` hunk)
**Issue:** (a) `extern const struct file_operations d330_dsi_dump_ops;` is declared in the same file that defines it a few lines later — redundant. (b) `d330_dsi_dump_register()` is called unconditionally from `i915_debugfs_register()`, so the node exists on every i915 platform running this custom kernel, not just the D330. Acceptable for a single-purpose CI kernel, but anyone reusing the kernel elsewhere gets a root-only node that walks raw display MMIO on `echo 1`.
**Fix:** Drop the redundant extern; optionally gate registration on the 82H0 DMI match the project already uses, or leave as-is with a comment stating the kernel is D330-only by policy.

### IN-05: Minor robustness nits in capture/test scripts

**File:** `scripts/capture_dsi_dumps.sh:188`; `scripts/test_dsi_mmio_evidence.sh:87-96,116-117,124,128,134`
**Issue:** (a) `SIZE=$(stat -c '%s' … || stat -f '%z' …)` — on Linux (the only target) the `-f` fallback means filesystem stats, so if `stat -c` ever failed the fallback would report nonsense rather than fail loudly. (b) The evidence suite's `check()` evals condition strings built with unquoted `$doc`; safe for the current relative paths and mktemp dirs, but any path containing spaces (this repo's own root does) would break the quoted-ness — currently unreachable, since `doc` is always repo-relative.
**Fix:** Drop the `stat -f` fallback (fail on error instead); quote `$doc` inside the eval'd conditions (double-quote in the template strings).

---

_Reviewed: 2026-10-14T17:19:34-03:00_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
