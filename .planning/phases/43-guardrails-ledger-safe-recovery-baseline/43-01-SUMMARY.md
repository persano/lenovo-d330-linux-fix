---
phase: 43
plan: 43-01
wave: 1
status: complete
commits:
  - a8b4cbc
  - 7756b88
requirements: [GUARD-01, GUARD-02]
---

# Plan 43-01 — Resume Fix Ledger + Banned-Lever Gate

## What shipped

- `docs/research/RESUME_FIX_LEDGER.md` — the binding ban ledger: 27 lever rows (header count `Lever rows: 27`), each with canonical name, case-insensitive ERE alias regex, disproof one-liner, and exact source-doc + section evidence. Content drawn from `DISPLAY_RESUME_CCS_MODIFIER.md` "Disproven theories (do not retry)" + on-device experiment sections, `DSI_RESUME_TRACE_ANALYSIS.md` "Ruled out by these traces" + disproven patch sections, and `COMMUNITY_FINDINGS.md` dead ends (display-server brute force, sleep-target masking, the three kernel-param levers). Cross-doc duplicates merged into single rows with all evidence links; corrected-VBT note carried; proven-bar note explains how a row may someday be un-banned.
- `scripts/test_pitfalls_ledger.sh` — guard suite (4 cases) + gate engine:
  - `ledger-parses`: unique sentinels, exactly-5-non-empty-cell rows (escaped `\|` in regex cells handled), header count == actual rows, count >= 22 (`MIN_LEDGER_ROWS`), every alias compiles (`grep -E` rc < 2), unique canonical names, and every alias positive-probes at least one line of the three source docs (no vacuous rows).
  - `gate-fails-on-banned-fix`: fixture probe (`--gate-probe` + `D330_LEDGER_SCAN_DIR`) proves a planted "fix black resume by setting i915.enable_psr=0" plan line makes the gate exit non-zero with a `file:line` marker; the planted line is asserted to match the lever's own alias regex first (non-vacuity).
  - `allowlist-marker-honored`: the same planted line plus a `<!-- planner-discipline-allow: <exact string> -->` marker passes clean. Exemptions are per exact string, per file; marker lines themselves are never scanned.
  - `pristine-tree-passes`: gate over the real tree is green — scan list from `git ls-files` filtered to `*-PLAN.md`/`*-SUMMARY.md` under `.planning/phases/` (tracked spelling; the `.gsd/phases` junction glob is only a fallback) plus `docs/research/*.md` minus the allowlist; plan/summary subset count asserted > 0 separately from the total (30 files scanned, 0 hits); malformed/absent/empty ledger fails closed.
- `scripts/test_storage_cellular.sh` — suite wired into the full chain: `bash -n` list and chained run after doc-parity.
- `CHANGES_AUDIT.md` — test-suite count sentence 36 → 37 (doc-parity guard re-verified green at 19 cases).
- `43-01-PLAN.md` / `43-04-PLAN.md` — carry per-exact-string `planner-discipline-allow` markers for their own instruction text that legitimately quotes ledger lever names (the gate's designed mechanism, per the plan's flagged assumption about future summaries).

## Verification

- `bash scripts/test_pitfalls_ledger.sh` → `Ledger gate suite summary: passed=4 failed=0`
- `bash scripts/test_storage_cellular.sh --dry-run` → `CHAIN_EXIT=0` (full chained harness incl. doc-parity 19/0 and this suite)
- Gate reports `Ledger gate: files=30 hits=0` on the pristine tree.

## Deviations

- Executed inline by the orchestrator instead of a dispatched executor agent: subagent execution returned empty results 6 times during wave-1 dispatch (4x gsd-executor, 1x general with the full prompt; trivial probes worked). Plan content was followed exactly; commits and this summary are honest to what ran.
- No isolated worktree: fork-base mismatch (#683) degrades isolation to none for this milestone; sequential execution on the main working tree.
- One fix during authoring caught by the suite itself and corrected before commit: the fixture case's rc capture negated status (`if ! out=...` makes `$?` = 0) and a `${rest:-]}` typo made every row parse as malformed; both were fixed before the Task 1 commit.

## Requirements touched

- GUARD-01: 27-row ledger, one row per distinct disproven lever, alias + disproof + evidence, count bar enforced at 22.
- GUARD-02: gate enforced by the full harness chain, fixture-proven non-vacuous, per-string allowlist, fail-closed parsing.
