<!-- planner-discipline-allow: 0x160018 -->

---
plan: 47-04
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
status: complete
deferred_commit: true
completed: 2026-10-14
subsystem: dsi-mmio-analysis
tags: [mmio-01, mmio-02, dsi, s3-resume, mechanism-claim, evidence]
requires:
  - 47-02 diff tooling + evidence guard (scripts/dsi_mmio_diff.sh, scripts/test_dsi_mmio_evidence.sh)
  - 47-03 registered dump pair (boot/broken + session-1 contrast, kit manifest)
provides:
  - docs/dumps/re_kit/dsi_regs_diff.txt — canonical cited diff (script output + classification annex), manifest-registered (sha256 f3aea7f2…7e2a7)
  - docs/research/DSI_MMIO_DIFF.md — diff recorded, exclusions, ONE testable mechanism claim, Phase-48 restore/replicate handoff
affects:
  - Phase 48 fix plan (handoff list is its input; dump node stays in CI baseline for at-wake re-verification)
tech-stack:
  added: []
  patterns: [tree-grep-name-resolution, ssh-device-grep, cited-diff-annex, single-claim-discipline]
key-files:
  created:
    - docs/dumps/re_kit/dsi_regs_diff.txt
    - docs/research/DSI_MMIO_DIFF.md
  modified:
    - docs/dumps/re_kit/MANIFEST.sha256 (1 line added: dsi_regs_diff.txt)
decisions:
  - Claim landed on the 3-way contrast branch of the Pattern-4 decision tree: operational state (0x160018 + the five DSI operational registers) reached or failed-to-reached by sequencing — never value-restore (rows 3/18 engaged in their own subsection)
  - Tree-grep resolved 0x138108 = GEN6_GT_GFX_RC6 (counters family) and 0x13816c = GEN9_GT_PM_CONFIG; 0x160018/0x160084/0x13819c unnamed in the 7.0.0 tree → cited by address (else-cite-by-address branch)
  - Diff artifact = scripts/dsi_mmio_diff.sh output (with tree-verified --names) + appended classification annex — ONE canonical file, full-pipeline rebuild byte-identical
  - 0x160084 recorded as boot-to-boot variance (s1 boot arm read 00000000 with the panel lit), NOT claimed as a bug signature; 0x13816c bits 24/25 recorded as bug-associated (identical in the working pair)
  - 0x46000 reconciliation = not-reproduced (identical 0080013b on all four arms — a third value); pipe/RC6 prior rows marked out-of-scope; nothing from 2026-era evidence re-discovered as new
metrics:
  duration: ~40 min
  completed: 2026-10-14
actuals:
  tokens: 6500
  tasks: 2
  commits: 0
---

# Phase 47 Plan 04: Diff the Pair, Name the Mechanism, Hand Off to Phase 48 Summary

One canonical cited diff (14 rows: 10 reconfirmed-prior, 4 new) plus DSI_MMIO_DIFF.md ending in ONE testable mechanism claim — broken resume leaves the DSI operational state degraded (0x160018 00000115→00000001 + five DSI operational rows + timeout status), working resume re-reaches the exact boot set; static config byte-identical everywhere; DPHY calibration area all-ones on all arms (honestly unreachable); all gates green.

## What Was Built

- `docs/dumps/re_kit/dsi_regs_diff.txt` — `scripts/dsi_mmio_diff.sh` output on the registered session-2 pair (parse summary 7296/arm, 0 warnings, 0 state rows; per-range identical counts 1017/4094/1024/128/1019; 14 cited rows) + Task-1 classification annex (reconfirm-prior / new / not-reproduced / out-of-scope vs the prior 21-row table) + tree-verified names (GEN6_GT_GFX_RC6, GEN9_GT_PM_CONFIG). Deterministic: full-pipeline rebuild byte-identical.
- `docs/research/DSI_MMIO_DIFF.md` — 7 sections: provenance (hashes, CI run, session timelines, eyes-on verdicts), scope (node + trigger + locked 5-range table), canonical exclusion table mirrored verbatim (+ state-row reasons), diff results with the 3-way contrast table, the ONE mechanism claim (D-05) with the rows-3/18 engagement subsection, the Phase-48 what-to-restore/replicate list (D-08), machine-evidence appendix.
- `docs/dumps/re_kit/MANIFEST.sha256` — 1 new line (`dsi_regs_diff.txt`); `--verify` exits 0 (37 artifacts OK).

## Tasks

| # | Task | Status | Proof |
|---|------|--------|-------|
| 1 | Run the diff on the registered pair and register the diff artifact | DONE | Parse summary 7296/arm = 47-03's recorded counts, 0 warnings, 0 state rows → not ambiguous, no second pair (D-04). All 14 differing offsets classified (10 reconfirm-prior incl. 4 excluded-volatile; 0x138108/0x13819c tree-named/volatile counters; 0x13816c bug-associated; 0x160084 variance-not-signature); 0x46000 not-reproduced; 8 prior rows out-of-scope. Registered: kit `--verify` exit 0, manifest count 1 |
| 2 | Write DSI_MMIO_DIFF.md — exclusions, reconciliation, ONE claim, Phase-48 handoff | DONE | Evidence suite real mode 7/7 (citations ≥10: 28 anchors; exclusion table 7 reasons; exactly 1 claim heading + 0x offset; handoff heading; ≥1 narrow marker — exactly one: `0x160018`); ledger gate 4/4 + gate-probe on the untracked doc: hits=0; RE suite 6/6; kit verify green |

TDD gate (Task 2, tdd="true"): RED = real-mode suite red at start (1/7 — the doc cases failing on the absent doc, the designed RED→GREEN shape from 47-02); GREEN = doc lands, 7/7. No separate test commit (guard suite pre-exists from 47-02; this project defers all commits).

## The Mechanism Claim (one line)

Broken resume leaves the DSI link in a degraded operational state — 0x160018=00000001 (boot 00000115), 0x6b010=0000b8ea (boot 003fffff), 0x6b044=0000001e (boot 0000001d), 0x6b080/0x6b098=0a051003 bit24 (boot 09051003), 0x6b088=0014000c (boot 0022000f), 0x6b094=00000000 (boot 00000001), 0x6b004 LP_RX_TIMEOUT-marked 40280000 — with every static config register byte-identical to boot; the working resume re-reaches the exact boot set; the claim is the sequencing-reached operational state (never value restore, per rows 3/18), testable by Phase 48 replicating the GOP init step + at-wake re-dump + eyes-on.

## Deviations from Plan

1. **[Deferred-commit override]** No `git add`/`git commit` for code/data; planned messages recorded in the Deferred Commits ledger below. `/gsd-ship` commits them.
2. **[Instruction] STATE.md/ROADMAP.md untouched** — objective explicitly prohibited the standard state-update flow (no `state advance-plan` / `update-progress` / metrics / decisions writes; no ROADMAP plan-progress update). Position/counters left for the orchestrator.
3. **[Annex assembly]** Plan action allowed "re-run the script or post-process into the same artifact — keep ONE canonical diff file"; took the post-process path (script output + appended classification annex, both halves deterministic; annex source kept in the session scratch under `C:\Users\Familia\AppData\Local\Temp\opencode\47-04\annex.txt`).
4. **[Untracked-doc ledger probe]** The pristine-tree ledger scan reads `git ls-files` (tracked files only), so the brand-new untracked doc would be invisible to it — added a `--gate-probe` run over a scratch copy (`files=1 hits=0`) as the honest green proof. After /gsd-ship tracks the file, the plain gate covers it.

## Deferred Commits

All code/data changes uncommitted — will be committed by /gsd-ship.

- `feat(47-04): DSI MMIO diff artifact with classification annex, kit-registered` — files: `docs/dumps/re_kit/dsi_regs_diff.txt`, `docs/dumps/re_kit/MANIFEST.sha256`
- `docs(47-04): DSI_MMIO_DIFF.md — cited diff, exclusions, ONE mechanism claim, Phase-48 handoff` — files: `docs/research/DSI_MMIO_DIFF.md`

## Self-Check

- [x] `docs/dumps/re_kit/dsi_regs_diff.txt` exists (71 lines), sha256 `f3aea7f2…7e2a7`, registered once, kit `--verify` exit 0
- [x] `docs/research/DSI_MMIO_DIFF.md` exists; evidence suite real mode exit 0 (7/7)
- [x] Ledger gate 4/4 green; untracked-doc probe hits=0 (single narrow marker `0x160018`, derived from the ledger alias column while writing)
- [x] RE evidence suite 6/6 green
- [x] Claim cites dump rows (boot_dsi_regs.txt:1033/6/19/34/36/40/39; broken_dsi_regs.txt:1033/6/19/34/36/40/39/3) and engages ledger rows 3/18 in its own subsection
- [x] No sysfs panel-visibility claims (verdicts cite the 47-03 eyes-on record); no stubs, no skipped tests, no unrun verifies (broken-windows ledger: no entries needed)
- [x] STATE.md/ROADMAP.md not modified (per objective)

## Self-Check: PASSED
