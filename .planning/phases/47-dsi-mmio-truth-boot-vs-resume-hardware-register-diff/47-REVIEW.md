---
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
reviewed: 2026-10-14T18:05:48-03:00
depth: standard
iteration: 2
files_reviewed: 8
files_reviewed_list:
  - .github/workflows/build-kernel.yml (main + branch; re-checked unchanged by b753d39)
  - patches/d330_dsi_dump.patch (via git show b753d39 — the WR-02 fix commit on instrument/d330-dsi-dump)
  - scripts/capture_dsi_dumps.sh
  - scripts/dsi_mmio_diff.sh
  - scripts/test_dsi_mmio_evidence.sh
  - docs/research/DSI_MMIO_DIFF.md
  - docs/dumps/re_kit/MANIFEST.sha256 (+ kit verify incl. dsi_regs_diff.txt, dsi_regs_diff_names.txt)
  - docs/dumps/re_kit/dsi_regs_diff.txt (rebuild-proven byte-identical, lines 1-32)
findings:
  critical: 0
  warning: 0
  info: 6
  total: 6
status: issues_found
---

# Phase 47: Code Review Report (iteration 2 — re-review after fix loop)

**Reviewed:** 2026-10-14T18:05:48-03:00
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found (info-only; all three warnings from iteration 1 verified fixed)

## Summary

Iteration-2 re-review of the phase-47 instrumentation set after the fix loop closed WR-01, WR-02, WR-03. Every fix was **executed, not just read**: selftest 35/35, fixtures 8/8, real-mode guard 7/7, ledger gate 4/4, kit verify green (now 38 lines incl. the registered names file), fresh WR-03 rebuild `cmp`-clean, and the b753d39 patch blob parse/hunk-count/marker checks all clean. No regressions found in the pinned contracts (record regex, header format, marker wording, manifest verify), and no regression to the CI anchors (b753d39 touches only `patches/d330_dsi_dump.patch`). No critical or warning findings remain. Six info items: IN-01…IN-05 carried forward unchanged (out of the critical+warning fix scope), plus one new IN-06.

## Fix verification (all executed this iteration)

### WR-01 — VERIFIED FIXED

`scripts/dsi_mmio_diff.sh:219-220` keys each skip marker to exactly its own range: `sk = (skip[arm] == 1 && p[1] == dsi_lo && p[2] == dsi_hi)`, `skp = (skipphy[arm] == 1 && p[1] == phy_lo && p[2] == phy_hi)` — the exact prescribed classification order (skipped-pll-off only when `n == 0`; marker-with-records → `parse-warning`; no marker + empty → `parse-warning`). Executed: selftest **35/35** including fixture H (`dsi_mmio_diff.sh:607-627`: marker on resume + boot-only 0x46000 range → DSI row `DSI block skipped: PLL off`, 0x46000 row `malformed dump … parse-warning`, zero "PLL off" wording on 0x46000) and fixture I (both markers on one arm, both state rows, per-range marker-line citation, marker-free range stays joinable).

### WR-02 — VERIFIED FIXED

Patch blob `b753d39` (parent `30f077c`, only file changed: `patches/d330_dsi_dump.patch`):
- `d330_dsi_dump_walk()` moves the PHY walk (`0x160000-0x164000`) inside the `else` (dsi_ok) branch and emits the second marker `# SKIPPED: DSI PLL off - PHY reads skipped` when `!dsi_ok` (blob lines 183-194).
- `d330_dsi_dump_overlay()` gates all five PHY-area reads (0x160018, 0x162000, 0x16218c, 0x162198, 0x161000) behind `if (dsi_ok)` (blob lines 133-149). No ungated DSI/MIPIO-area read remains in the patch; the residual unconditional reads (0x46000 block, 0xc7200, 0x138000, 0x46070/0x46080) are outside the MIPI/MIPIO hazard region and were read fine by the deployed kernel on all four captures.
- Marker strings byte-match the scripts: patch `# SKIPPED: DSI PLL off - DSI block reads skipped` / `# SKIPPED: DSI PLL off - PHY reads skipped` ≡ `SKIP_MARKER` / `PHY_SKIP_MARKER` (`dsi_mmio_diff.sh:56-57`); capture script's prefix `# SKIPPED: DSI PLL off` (`capture_dsi_dumps.sh:61`) counts both spellings.
- Consistency of the three accepted shapes: header contract lists both markers and 7296/6272/2176 (`capture_dsi_dumps.sh:32-42`); floor gate keys off SKIPCOUNT (2 markers → 2176 records stays warning-only, rc 0); `[MISS]` surfaces a missing PHY section without failing when markers present; diff script classifies the PHY marker as its own `skipped-pll-off` row with the distinct `DSI PHY block skipped: PLL off` wording (`dsi_mmio_diff.sh:192-194, 219-228, 261-262`).
- Executed: `git apply --numstat` on the blob parses cleanly (276/0, 6/0, 1/0); hunk-1 body = 276 lines ≡ `@@ -0,0 +1,276 @@`; 0 CR bytes; both markers present. Kernel compile remains the human/CI gate on next branch push (unverifiable on this machine — documented in the fix report).

### WR-03 — VERIFIED FIXED (executed byte-compare)

- `dsi_regs_diff_names.txt` registered: MANIFEST.sha256 is 38 lines / 28 unique artifacts, last line `ef55677dab14ccd2ae1ca24a0137339911e437cc6e6287bf42ab4df6f7518ba6  dsi_regs_diff_names.txt`; `prepare_safety_kit.sh --verify` green incl. the names file.
- Executed rebuild from `docs/dumps/re_kit/`: `dsi_mmio_diff.sh boot_dsi_regs.txt broken_dsi_regs.txt --names dsi_regs_diff_names.txt` → lines 1-32 **byte-identical** to the canonical `dsi_regs_diff.txt` (`cmp` clean). Control rebuild without `--names` differs in exactly the two cited name cells (0x138108 / 0x13816c). This simultaneously proves the WR-01/WR-02 classifier changes did not alter canonical output.
- Doc §1 (line 22) and §7 (lines 309-322) now state the exact rebuild command, the registration, and the no-`--names` control result. Doc §2 (lines 36-41) documents the extended gate with commit hash and the honest "not yet in a deployed kernel" caveat.

## Regressions — none found

- **Pinned record regex:** `dsi_mmio_diff.sh:128` still inlines the expanded mawk-compatible `[0-9a-fA-F]`-tolerant contract; parse_arm untouched in its record handling.
- **Header format / marker wording:** exact-string marker equality preserved (see WR-02 above); `# RANGE` parsing unchanged.
- **Manifest verify:** green, 38 lines / 28 unique, doc §7 wording now exact.
- **CI anchors:** `git diff 30f077c b753d39` touches only the patch file; both pre-existing CCS greps and the two dsi greps remain in the branch workflow; `git apply -p1` still fails loudly.
- **Evidence suites (all executed):** selftest 35/35; `test_dsi_mmio_evidence.sh --fixtures` 8/8 (non-vacuity backstop green); real mode 7/7; `test_pitfalls_ledger.sh` 4/4 (files=40 hits=0); `test_re_diff_evidence.sh` 6/6 (§7 gate claim true).
- **Deferred-commit mode:** uncommitted state on main is by design; every file the ledger claims exists (`scripts/dsi_mmio_diff.sh`, `scripts/capture_dsi_dumps.sh`, `docs/dumps/re_kit/dsi_regs_diff_names.txt`, `docs/dumps/re_kit/MANIFEST.sha256`, `docs/research/DSI_MMIO_DIFF.md`, and commit `b753d39` on `instrument/d330-dsi-dump`). No missing-file flag.

## Info

### IN-01: MANIFEST.sha256 carries 10 duplicate entries (carried forward, unchanged)

**File:** `docs/dumps/re_kit/MANIFEST.sha256:14-23`
**Issue:** 38 lines, 28 unique artifacts — the 10 duplicate lines predate this phase (verified: 38 − 28 = 10, matching doc §7's honest wording). Verification still passes (identical hashes). Out of the iteration-1 fix scope (info); dedup remains available as a one-time cleanup.

### IN-02: Dead constant `RECORD_BASH_RE` (carried forward, unchanged)

**File:** `scripts/dsi_mmio_diff.sh:55`
**Issue:** defined but never used; the record regex is still re-inlined (expanded) inside `parse_arm`'s awk at line 128. Two copies of the contract regex can drift.

### IN-03: Capture script's record regex diverges from the pinned contract (carried forward, unchanged)

**File:** `scripts/capture_dsi_dumps.sh:60`
**Issue:** lowercase-hex-only (`[0-9a-f]` spelled out) vs the contract's `[0-9a-fA-F]`. Cannot bite today (kernel `%08x` emits lowercase); a one-line pinning comment would close it.

### IN-04: Patch hygiene — redundant self-declaration; node registered for all platforms (carried forward, unchanged)

**File:** `patches/d330_dsi_dump.patch` (blob line 55; `i915_debugfs.c` hunk)
**Issue:** (a) `extern const struct file_operations d330_dsi_dump_ops;` self-declared in the file that defines it. (b) `d330_dsi_dump_register()` called unconditionally — node exists on every i915 platform running this kernel. Acceptable for the single-purpose CI kernel.

### IN-05: Minor robustness nits in capture/test scripts (carried forward, unchanged)

**File:** `scripts/capture_dsi_dumps.sh:193`; `scripts/test_dsi_mmio_evidence.sh:87-96,116-117,124,128,134`
**Issue:** (a) `stat -c '%s' … || stat -f '%z' …` — the `-f` fallback reports filesystem stats (nonsense) instead of failing loudly. (b) `check()` evals conditions with unquoted `$doc`; safe today (repo-relative paths only), breaks if a spaced path ever reaches it.

### IN-06 (new): Stated rebuild command's script path doesn't resolve from the stated cwd

**File:** `docs/research/DSI_MMIO_DIFF.md:22` and `:317-318`
**Issue:** §1/§7 say the artifact is generated by "`scripts/dsi_mmio_diff.sh …` (run in `docs/dumps/re_kit/`)" — from that cwd the literal path resolves to `docs/dumps/re_kit/scripts/…` and fails (reproduced this iteration: "No such file or directory"; the correct prefix is `../../../scripts/…`). The command's inputs, order, and semantics are otherwise exact and the rebuild itself is proven byte-identical, so this only degrades the reproducibility instructions, not the provenance.
**Fix:** Change the doc wording to the literally executable form, e.g. `bash ../../../scripts/dsi_mmio_diff.sh boot_dsi_regs.txt broken_dsi_regs.txt --names dsi_regs_diff_names.txt` (run in `docs/dumps/re_kit/`), or give the repo-root invocation with kit-relative paths (output is basename-cited, so either form reproduces the artifact byte-for-byte).

---

_Reviewed: 2026-10-14T18:05:48-03:00_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard (iteration 2)_
