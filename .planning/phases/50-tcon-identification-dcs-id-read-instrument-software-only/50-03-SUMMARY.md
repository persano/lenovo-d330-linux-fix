---
phase: 50-tcon-identification-dcs-id-read-instrument-software-only
plan: 50-03
subsystem: docs
tags: [dsi, tcon, research-doc, register-decode, anomalies]

requires:
  - phase: 49
    provides: "corrected DSI_MMIO_DIFF §5.2 evidence chain (X=Y/X=Z discrimination) the §6 row must stay cross-consistent with"
  - phase: 50-02
    provides: "evidence + ledger gates green baseline (dsi_mmio_diff selftest 52/0, evidence suite 7/0, ledger suite 4/0)"
provides:
  - "DSI_MMIO_DIFF §6 0x6b004 row carries the bit-accurate decode (SPL_PKT_SENT | HS_TX_TIMEOUT | LOW_CONTENTION; LP_RX_TIMEOUT bit 22 NOT set; 'HS video stream never accepted by panel')"
  - "0x6b010 and 0x6b080 anomalies pinned open in §6 with documented reasons (register NAME corrected to tree-verified MIPI_HS_TX_TIMEOUT(A); values untouched)"
affects: [50-04, 50-05, 53]

actuals:
  tokens: 6500
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "planner-discipline-allow markers quoting decode-context substrings (HS_TX_TIMEOUT (bit 21), MIPI_HS_TX_TIMEOUT(A)) — per-string, per-file gate exemptions"

key-files:
  created: []
  modified:
    - docs/research/DSI_MMIO_DIFF.md
    - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-02-SUMMARY.md

decisions:
  - "0x6b010 label corrected from 'LP RX timeout' to MIPI_HS_TX_TIMEOUT(A): tree-verified factually wrong name (47-RESEARCH line 252 cites vlv_dsi_regs.h: MIPI_HS_TX_TIMEOUT 0x6b010); ladder-locked discipline permits name-only correction, values byte-identical"
  - "§4.2 line 153 and RESUME_FIX_LEDGER.md left byte-identical per CONTEXT locked scope"

---

<!-- planner-discipline-allow: HS_TX_TIMEOUT (bit 21) -->
<!-- planner-discipline-allow: MIPI_HS_TX_TIMEOUT(A) -->
<!-- planner-discipline-allow: dmesg PMIC/controller lines -->

# Phase 50 Plan 03: DSI_MMIO_DIFF §6 label correction + open-anomaly record Summary

Status: **complete — TCON-04 doc-correction arm delivered.** §6's 0x6b004 row is
now bit-accurate (was mislabeled as an LP_RX_TIMEOUT status), and both open
anomalies (0x6b010, 0x6b080) are pinned with documented reasons, so the §6
hand-off table cannot misdirect Phase 53's wire-level probe.

## Accomplishments

- **Baseline gate repair (pre-existing red, Rule 3).** Ledger gate was red at
  task start: `50-02-SUMMARY.md:99` matched ledger row 12's `PMIC` alias in its
  I2C-sweep documentation line. Fixed with the gate's designed per-string
  exemption (`<!-- planner-discipline-allow: dmesg PMIC/controller lines -->`),
  marker not text deletion, per 49-01/44-01 precedent.
- **Task 1 — §6 0x6b004 row corrected.** Old role cell ("status: no
  LP_RX_TIMEOUT marking" — wrong: bit 22 is NOT the set bit) replaced with the
  bit-accurate decode of the recorded broken value `40280000`
  = bits 30|21|19 (vlv_dsi_regs.h verbatim definitions, 50-RESEARCH:356-364):
  `0x40280000 = SPL_PKT_SENT (bit 30) \| HS_TX_TIMEOUT (bit 21) \| LOW_CONTENTION (bit 19); LP_RX_TIMEOUT (bit 22) NOT set — "HS video stream never accepted by panel"`.
  Cross-consistent with §5.2 ("0x6b004 timeout-marked 40280000") and
  NO_CLEAN_FIX_PROOF §7.1 ("timeout-marked 0x6b004"); no contradiction.
  Narrow marker `HS_TX_TIMEOUT (bit 21)` added beside the file's marker block.
- **Task 2 — 0x6b010/0x6b080 anomalies pinned open.** The 0x6b010 role cell's
  register name ("LP RX timeout") was factually wrong — the register is
  `MIPI_HS_TX_TIMEOUT(A)` (tree-verified: 47-RESEARCH:252 cites
  vlv_dsi_regs.h, `MIPI_HS_TX_TIMEOUT 0x6b010`; v10.0-tcon-hunt.md:295).
  Name-only correction per the ladder-locked rule; values byte-identical
  (`003fffff` / `0000b8ea` untouched). Cell now flags the `0xb8ea` anomaly open:
  matches neither the kernel-computed txbyteclkhs timeout (~0xEF8AA) nor the
  GOP/VBT 0x3fffff, and a write/read-back probe would settle it but is a
  register WRITE — violates this instrument's read-only contract, own gated
  change if ever needed. 0x6b080 likewise flagged open (matches neither VBT
  nor kernel values; no action this phase). Narrow marker
  `MIPI_HS_TX_TIMEOUT(A)` covers the label literal (row 18 + row 2 aliases).
- **No value rewrites anywhere**; §4.2 line 153 and RESUME_FIX_LEDGER.md
  byte-identical (verified by diff).

## Deviations

**1. [Rule 3 - Blocking] Pre-existing ledger-gate red repaired in 50-02-SUMMARY.md**
- **Found during:** task start (baseline gate run)
- **Issue:** ledger gate `pristine-tree-passes` case failed on `50-02-SUMMARY.md:99` (`PMIC` alias hit) — pre-existing, committed by plan 50-02
- **Fix:** one per-string `planner-discipline-allow: dmesg PMIC/controller lines` marker added to 50-02-SUMMARY.md (gate's designed remedy; precedent 49-01-PLAN Task gate discipline, 44-01/43-04 summaries)
- **Files modified:** .planning/phases/50-.../50-02-SUMMARY.md
- **Commit:** `3306b49`

None other — plan executed as written; the 0x6b010 label correction was the plan's tree-verified conditional branch, taken.

## Gate results (after final commit)

- `bash scripts/dsi_mmio_diff.sh --selftest` → passed=52 failed=0
- `bash scripts/test_dsi_mmio_evidence.sh` → passed=7 failed=0
- `bash scripts/test_pitfalls_ledger.sh` → passed=4 failed=0

## Task Commits

Each task was committed atomically:

1. **Baseline gate repair (50-02-SUMMARY marker)** - `3306b49` (fix)
2. **Task 1: §6 0x6b004 bit-accurate decode** - `535848f` (docs)
3. **Task 2: 0x6b010/0x6b080 anomaly pins** - `973a5bd` (docs)

## Requirements

- **TCON-04** — doc-correction arm: COMPLETE. §6 0x6b004 row bit-accurate; both anomalies flagged open with reasons; §4.2 and ledger byte-identical; all gates green. (The instrument arm — echo-2 node/capture/diff tooling — was 50-01/50-02; TCON_IDENTIFICATION.md verdict is 50-04/50-05.)

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data introduced.

## Self-Check: PASSED

- FOUND: docs/research/DSI_MMIO_DIFF.md (§6 rows corrected)
- FOUND: .planning/phases/50-02-SUMMARY.md (marker repair)
- FOUND: commits 3306b49, 535848f, 973a5bd (ancestors of HEAD)
- Ledger + §4.2 byte-identity: git diff empty for docs/research/RESUME_FIX_LEDGER.md; line 153 unchanged
