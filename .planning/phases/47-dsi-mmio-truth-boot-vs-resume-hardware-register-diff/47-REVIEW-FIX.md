---
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
fixed_at: 2026-10-14T18:55:00-03:00
review_path: .planning/phases/47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff/47-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 47: Code Review Fix Report

**Fixed at:** 2026-10-14T18:55:00-03:00
**Source review:** `.planning/phases/47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff/47-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (WR-01, WR-02, WR-03; fix_scope=critical_warning)
- Fixed: 3
- Skipped: 0

**Mode note (DEFERRED COMMIT):** per this machine's deferred-commit mode, the
WR-01/WR-02/WR-03 fixes are left UNCOMMITTED in the main checkout; planned
commit messages + files are in the ledger below. One exception, documented:
WR-02's patch fix was committed on its own branch (see WR-02 section) because
`patches/d330_dsi_dump.patch` exists only on `instrument/d330-dsi-dump` and a
modified tracked file that main does not track cannot be carried across a
branch switch uncommitted. Main received no commits.

## Fixed Issues

### WR-01: Arm-global PLL-off skip flag misclassifies corrupted non-DSI sections as "PLL off"

**Files modified:** `scripts/dsi_mmio_diff.sh`
**Status:** fixed: requires human verification (classification-logic change; all embedded assertions pass, but the logic warrants human eyes)
**Applied fix:** The state classifier now keys the DSI PLL-off marker to its
own range only: `sk = (skip[arm] == 1 && p[1] == dsi_lo && p[2] == dsi_hi)`,
exactly as the review prescribed. A corrupted/missing section header on any
other range of a marker arm now classifies `parse-warning` ("malformed dump")
instead of the benign `skipped-pll-off`. Added selftest fixture H proving the
reclassification: marker on resume + boot-only second range (0x46000) whose
header is missing on resume → DSI range stays `skipped-pll-off` (cited at the
marker line), 0x46000 row is `parse-warning`, and the 0x46000 range never
inherits the "PLL off" interpretation.

### WR-02: Patch's BSpec machine-hang gate does not cover the DSI PHY range or overlay reads

**Files modified:** `patches/d330_dsi_dump.patch` (branch `instrument/d330-dsi-dump`), `scripts/dsi_mmio_diff.sh`, `scripts/capture_dsi_dumps.sh`, `docs/research/DSI_MMIO_DIFF.md` (§2/§3)
**Status:** fixed: requires human verification (kernel C gating change; cannot compile the kernel here — parse-validated only, CI build on next push is the real gate)
**Applied fix (option b — the safe alternative; no unverified BSpec claim):**
Since no BSpec clause available to this session proves PHY/MIPIO
(0x160000-0x164000) reads are safe with the DSI PLL off, the gate was EXTENDED
rather than the hazard documented away:

- Patch (committed on `instrument/d330-dsi-dump` as `b753d39`, parent
  `30f077c`): `d330_dsi_dump_walk()` now emits a second, distinct skip marker
  `# SKIPPED: DSI PLL off - PHY reads skipped` and moves the PHY walk
  (0x160000-0x164000) inside the `else` (dsi_ok) branch; the five PHY-area
  overlay reads (0x160018, 0x162000, 0x16218c, 0x162198, 0x161000) in
  `d330_dsi_dump_overlay()` are gated behind the same `dsi_ok` condition. The
  file-header output-contract comment and the walk's BSpec comment document
  the extended gate and why (rule's scope not proven to exclude PHY/MIPIO;
  PHY reads with the PLL off unproven on this hardware).
- `scripts/dsi_mmio_diff.sh`: parses the PHY marker as its own `S … PHY` rep
  line, keys it to the PHY range only (`skipphy[arm]` + `seen` seeding for
  0x160000-0x164000), classifies it `skipped-pll-off` for an absent/empty PHY
  section, cites the per-range marker line, and emits the distinct
  interpretation wording `DSI PHY block skipped: PLL off` for the PHY range
  (DSI block keeps `DSI block skipped: PLL off`). Selftest fixture I covers
  both markers on one arm, both state rows, per-range marker-line citation,
  and a marker-free joinable range staying joinable.
- `scripts/capture_dsi_dumps.sh`: header contract now lists both markers;
  expected-counts comment documents the three accepted shapes (7296 records /
  6272 with the deployed 30f077c DSI-only skip / 2176 once the post-review
  gate also skips the PHY walk); the SKIPCOUNT warning names both gated
  sections. The existing floor gate already keys off the marker count (which
  counts both spellings, since the PHY marker shares the `# SKIPPED: DSI PLL
  off` prefix) and the per-section [MISS] report already surfaces a missing
  PHY section — no further changes needed.
- Patch validation performed (blob-level, no kernel tree in this repo):
  `git apply --numstat` parses cleanly (276/0 new file; i915_debugfs.c 6/0;
  Makefile 1/0), hunk-1 body count re-measured against the `@@ -0,0 +1,276 @@`
  header, LF-only byte check (0 CR), old marker preserved verbatim, both
  markers present. **Human verification required:** compile + CI run on next
  branch push; the deployed 30f077c kernel is unaffected until rebuilt.

### WR-03: Canonical `dsi_regs_diff.txt` not reproducible from registered inputs

**Files modified:** `docs/dumps/re_kit/dsi_regs_diff_names.txt` (new), `docs/dumps/re_kit/MANIFEST.sha256`, `docs/research/DSI_MMIO_DIFF.md` (§1/§2/§3/§7)
**Status:** fixed (mechanically proven by executed byte-compare)
**Choice:** option (a) — register the names file; the artifact itself is NOT
regenerated (its sha256 in doc §1/§7 and the manifest stays valid).
**Applied fix:** The original `--names` file was not preserved, so it was
recreated from the artifact's own named cells — exactly two entries
(`0x138108 GEN6_GT_GFX_RC6`, `0x13816c GEN9_GT_PM_CONFIG`, both tree-verified
names already cited in the doc) — written as
`docs/dumps/re_kit/dsi_regs_diff_names.txt`, and registered via
`prepare_safety_kit.sh --register`
(`ef55677dab14ccd2ae1ca24a0137339911e437cc6e6287bf42ab4df6f7518ba6`).
Proof (executed, WSL bash):

- Rebuild with the registered names file, using the CURRENT (post-WR-01/02)
  script: **byte-identical** to the committed artifact's script-output portion
  (lines 1-32; `cmp` clean) — so the determinism claim is now reproducible
  from registered inputs AND the classifier fixes provably did not change
  canonical output.
- Control rebuild without `--names` differs in exactly the 2 cited name cells
  (0x138108 / 0x13816c) — matching the review's executed finding.
- Doc §1 (Diff artifact row) now states the exact rebuild command
  (`dsi_mmio_diff.sh boot_dsi_regs.txt broken_dsi_regs.txt --names
  dsi_regs_diff_names.txt` run in `docs/dumps/re_kit/`); doc §7 states the
  manifest is 38 lines / 28 unique artifacts (10 duplicate lines predate this
  phase, IN-01 open) with `dsi_regs_diff_names.txt` registered, and spells out
  that the no-`--names` rebuild differs in exactly the two tree-named cells.

## Deferred-Commit Ledger (planned commits; main checkout, NOT committed)

| # | Planned commit message | Files |
|---|---|---|
| 1 | `fix(47): WR-01+WR-02 key PLL-off skip markers to their own ranges; add PHY skip-marker handling` | `scripts/dsi_mmio_diff.sh`, `scripts/capture_dsi_dumps.sh` |
| 2 | `fix(47): WR-03 register dsi_regs_diff_names.txt in the RE kit; state the exact rebuild command (doc also carries WR-02 marker-contract wording)` | `docs/dumps/re_kit/dsi_regs_diff_names.txt` (new), `docs/dumps/re_kit/MANIFEST.sha256`, `docs/research/DSI_MMIO_DIFF.md` |
| 3 | COMMITTED (branch exception, see WR-02): `b753d39` `fix(47): WR-02 gate DSI PHY walk and PHY overlay reads behind the DSI PLL gate` | `patches/d330_dsi_dump.patch` on `instrument/d330-dsi-dump` (parent `30f077c`; NOT merged to main) |

Note: the kit files (`docs/dumps/re_kit/*.txt`, `docs/research/DSI_MMIO_DIFF.md`,
`scripts/*.sh`) are untracked at this point in the phase's own history; the
ledger above records the intended commit grouping for when the phase work is
committed.

## Verification

**Where it ran:** the MAIN CHECKOUT (`workflow.use_worktrees=false` — user
opted out of worktrees; no isolated worktree was created). Bash = WSL; git
blob checks via plumbing (no branch switch, main working tree untouched by
the WR-02 commit).

| Gate | Result |
|---|---|
| `bash scripts/dsi_mmio_diff.sh --selftest` | **35/35 OK** (26 pre-existing + 9 new H/I assertions; was 26/26) |
| `bash scripts/test_dsi_mmio_evidence.sh --fixtures` | **8/8 OK** (unchanged) |
| `bash scripts/test_pitfalls_ledger.sh` | **4/4 OK, files=40 hits=0** |
| `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` | **green** (38 lines incl. `dsi_regs_diff_names.txt: OK`) |
| `bash scripts/test_dsi_mmio_evidence.sh` (real mode, extra) | **7/7 OK** |
| WR-03 rebuild proof (executed `cmp`) | **byte-identical** with registered names file; no-names control differs in exactly the 2 cited cells |
| WR-02 patch blob parse (`git apply --numstat`) | clean (276/0, 6/0, 1/0); hunk header re-measured; LF-only; markers present |
| Line-ending hygiene | 0 CR bytes in all 4 edited files |

**Not verified here (human/CI follow-up):** kernel compile + boot of the
instrument branch (no kernel tree/CI on this machine); the deployed 30f077c
kernel still runs the DSI-only gate until the branch is rebuilt and flashed.

## Skipped Issues

None.

---

_Fixed: 2026-10-14T18:55:00-03:00_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
