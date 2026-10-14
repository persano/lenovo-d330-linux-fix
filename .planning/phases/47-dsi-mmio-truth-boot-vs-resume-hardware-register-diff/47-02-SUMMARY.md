---
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
plan: 02
subsystem: testing
tags: [bash, mmio, diff-tooling, evidence-guard, static-analysis, i915-dsi]

# Dependency graph
requires:
  - phase: 45 (RE kit pipeline)
    provides: scripts/prepare_safety_kit.sh --verify contract and the docs/dumps/re_kit manifest the suite verifies against
  - phase: 43 (banned-lever gate)
    provides: scripts/test_pitfalls_ledger.sh gate + the narrow planner-discipline-allow marker mechanism
provides:
  - scripts/dsi_mmio_diff.sh — dump-pair diff (join on offset, per-range exclusion table, 0xffffffff / PLL-off classification, file:line cited markdown rows, --selftest, optional --names mapping)
  - scripts/test_dsi_mmio_evidence.sh — 7-case phase evidence guard (kit verify pristine-first, manifest coverage, D-07 citation bar, D-06 exclusion table, D-05 single-claim, D-08 handoff heading, allow-markers) with --fixtures proving mode and a contract-violating backstop
affects: [47-03 (kit registration), 47-04 (DSI_MMIO_DIFF.md writer consumes the citation format + canonical exclusion table), phase 48 (fix plan)]

# Actuals (#2632)
actuals:
  tokens: 9500        # chars/4 over the two changed scripts (~38.1 KB diff)
  tasks: 2
  commits: 0          # deferred-commit mode — code left uncommitted for /gsd-ship

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "line-oriented awk dump parser keyed on the 47-01 format contract (record regex ^0x[0-9a-f]+=[8-hex]$, # RANGE headers, exact skip-marker string)"
    - "per-arm range-state classification (skipped-pll-off / unreadable-0xffffffff / parse-warning / readable) hardened so a zero-record section can never classify readable"
    - "sort -t<TAB> -k2,2 + cmp determinism check; parse-time line tracking as the citation source (D-07)"
    - "45-suite evidence-guard conventions: check() helper, passed/failed counters, non-zero exit on failure, kit verify pristine-first"

key-files:
  created:
    - scripts/test_dsi_mmio_evidence.sh
  modified:
    - scripts/dsi_mmio_diff.sh   # found on disk from an interrupted prior run; verified + 3 defect fixes + selftest extension

key-decisions:
  - "Diff rows carry 6 columns (offset | boot | resume | interpretation | verdict | citation) — matches the D-07 truth and 47-RESEARCH Pattern 3, which include interpretation; the plan action's 5-column list is a subset"
  - "excluded-volatile is the single de-prioritization verdict; true semantics live in the reason string (no separate verdict class for config-family rows 0x6b094 / 0x6b074)"
  - "Evidence suite stays RED in plain mode until 47-03/47-04 land (Nyquist RED->GREEN), with --fixtures + a contract-violating backstop proving the case logic both directions"

patterns-established:
  - "Dump format contract enforcement: non-record lines inside a section become counted parse warnings, never data (T-47-06)"
  - "State rows replace per-register rows for non-readable/mismatched-arm ranges; every row cites file + line taken from parse-time tracking"

requirements-completed: [MMIO-01]

coverage:
  - id: D1
    description: "dsi_mmio_diff.sh — dump-pair diff with per-range exclusion table, 0xffffffff/PLL-off state classification, file:line cited rows, deterministic output, --selftest proving every classification branch"
    requirement: MMIO-01
    verification:
      - kind: unit
        ref: "command: bash scripts/dsi_mmio_diff.sh --selftest (26/26 assertions, exit 0)"
        status: pass
      - kind: unit
        ref: "command: bash -n scripts/dsi_mmio_diff.sh (exit 0)"
        status: pass
      - kind: unit
        ref: "command: bash scripts/test_pitfalls_ledger.sh (exit 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "test_dsi_mmio_evidence.sh — 7-case phase evidence guard; --fixtures mode proves cases 3-7 against a satisfying fixture AND a contract-violating fixture (suite can actually fail); plain mode RED by design until 47-03/47-04 evidence lands"
    requirement: MMIO-01
    verification:
      - kind: unit
        ref: "command: bash scripts/test_dsi_mmio_evidence.sh --fixtures (8/8, exit 0)"
        status: pass
      - kind: other
        ref: "command: bash scripts/test_dsi_mmio_evidence.sh (plain mode exits non-zero with [FAIL] lines naming missing artifacts — designed red)"
        status: pass
      - kind: unit
        ref: "command: bash -n scripts/test_dsi_mmio_evidence.sh (exit 0)"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 18m
completed: 2026-10-14
status: complete
deferred_commit: true
---

# Phase 47 Plan 02: Diff Tooling + Static Evidence Guard Summary

**Dump-pair diff tooling (`dsi_mmio_diff.sh`) that joins boot/resume captures into file:line-cited markdown rows with per-range exclusion and all-ones/PLL-off state classification, plus the 7-case static evidence guard (`test_dsi_mmio_evidence.sh`) proven green via fixtures and red-until-evidence in plain mode.**

## Performance

- **Duration:** ~1h 18m
- **Started:** 2026-10-14T01:45Z
- **Completed:** 2026-10-14T03:03Z
- **Tasks:** 2/2
- **Files modified:** 2 (1 created, 1 verified + fixed)

## Accomplishments

- `scripts/dsi_mmio_diff.sh`: parser keyed to the 47-01 dump format contract (record regex, `# RANGE` headers, exact `# SKIPPED: DSI PLL off - DSI block reads skipped` marker, named-overlay section never parsed as data); non-matching section lines become counted parse warnings (T-47-06). Per-arm range states: `skipped-pll-off` (marker present, section absent or empty), `unreadable-0xffffffff` (>90% all-ones, reported ONCE per range — Pitfall 2), `parse-warning` (zero records, no marker — hardened so an empty section can never classify `readable`), `readable`. Join on offset with per-range identical counts (D-06 collapse); canonical exclusion table (17 entries, true semantics per family: W1C interrupt status 0x6b004/0x6b804/0x6b090; interrupt-enable mask 0x6b094 with its own config-state reason citing the prior differing row and ledger rows 3/18; RX-FIFO pop-on-read 0x6b118-0x6b137 + 0x6b064/0x6b068; GEN-FIFO status 0x6b074; read-valid flag 0x6b138; PPS sequence state 0xc7200; compositor-volatile surface words; monotonic counters). Every row (differing/excluded/state) cites `boot_dsi_regs.txt:<line>` / `broken_dsi_regs.txt:<line>` from parse-time line tracking (D-07). Deterministic: same inputs → byte-identical output. `--selftest`: 26 assertions over 7 embedded fixtures covering every classification branch + determinism + names-mapping.
- `scripts/test_dsi_mmio_evidence.sh`: 7 real-mode cases mirroring `test_re_diff_evidence.sh` conventions (banner, `check()` helper, counters, non-zero exit on failure, kit verify pristine-first): mmio-kit-verify, mmio-kit-manifest-covers (both dumps + `dsi_regs_diff.txt`), mmio-diffdoc-citations (≥10 `file:line` anchors — D-07), mmio-exclusion-table (heading + ≥3 distinct canonical reasons — D-06), mmio-single-claim (`grep -c` == 1 heading + `0x…` offset inside the claim — D-05), mmio-handoff (`what to restore/replicate` heading — D-08), mmio-allow-markers (≥1 narrow `planner-discipline-allow:` marker). `--fixtures` mode proves all 5 doc cases against an embedded satisfying fixture (8/8, exit 0) and a `--fixtures-violating` backstop proves the suite actually fails on a contract-violating doc. Plain mode is intentionally RED in wave 1 (failed=6, exit non-zero, `[FAIL]` lines name the missing artifacts: the 47-03 kit entries and the 47-04 doc).

## Task Commits

Deferred-commit mode — no code commits made. Planned commits for `/gsd-ship`:

## Deferred Commits

- feat(47-02): add dump-pair diff tooling with exclusion table, state classification and cited rows — files: `scripts/dsi_mmio_diff.sh` (**commit as 100755** — exec bit must be set at staging: `git add --chmod=+x scripts/dsi_mmio_diff.sh`; file predates this run from an interrupted prior executor, now verified + fixed)
- feat(47-02): add phase evidence guard suite with fixtures + violating-fixture backstop — files: `scripts/test_dsi_mmio_evidence.sh` (**commit as 100755** — `git add --chmod=+x scripts/test_dsi_mmio_evidence.sh`)

All code changes uncommitted — will be committed by /gsd-ship.

## Files Created/Modified

- `scripts/dsi_mmio_diff.sh` — dump-pair diff: join, exclusion table, all-ones/PLL-off classification, cited markdown rows, `--selftest` (26 assertions)
- `scripts/test_dsi_mmio_evidence.sh` — phase evidence guard: 7 cases, `--fixtures` (8 assertions incl. violating-fixture backstop), plain mode red-until-evidence

## TDD Notes (Task 1, tdd="true")

- **RED observed:** the interrupted run left `scripts/dsi_mmio_diff.sh` on disk with its embedded selftest failing 6 of 25 assertions (first execution this session: `passed=19 failed=6`). No implementation changes were made before that failing run was captured.
- **GREEN:** after the three fixes below, selftest 26/26, exit 0; `bash -n` clean; ledger gate green.
- Deferred-commit mode collapses the RED/GREEN commits into one planned `feat(47-02)` commit (ledger above).

## Decisions Made

- 6-column row layout (`offset | boot | resume | interpretation | verdict | citation`) retained — the D-07 must-have truth and 47-RESEARCH Pattern 3 both name interpretation; the plan action's 5-column list is a subset of it.
- `excluded-volatile` is the only de-prioritization verdict; the reason string carries true semantics (per the plan: no new verdict class for 0x6b094/0x6b074).
- The evidence suite's plain mode is left deliberately red (Nyquist RED→GREEN for the phase); only `--fixtures` is pinned green in wave 1, exactly as the plan's verify block states.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] dsi_mmio_diff.sh: identical-count summary label truncated**
- **Found during:** Task 1 (selftest verification of the pre-existing file)
- **Issue:** the join-processing awk lacked `-v hi="$hi"`, so IDENT meta lines carried an empty range-hi → summary printed `identical 0x6b000-0x…` instead of `identical 0x6b000-0x6c000: N register(s)`
- **Fix:** added `-v hi="$hi"` to the join awk
- **Files modified:** scripts/dsi_mmio_diff.sh
- **Verification:** selftest assertions A/D identical-count now green; determinism fixture E still byte-identical
- **Committed in:** deferred (planned feat(47-02) commit)

**2. [Rule 1 - Bug] dsi_mmio_diff.sh: state-row range label missing the 0x prefix on hi**
- **Found during:** Task 1 (selftest + fixture-B manual inspection)
- **Issue:** state rows printed the offset cell as `0x6b000-6c000` (missing `0x` on the hi bound), breaking the D-07 row format and 3 selftest branches
- **Fix:** label built as `0x<lo>-0x<hi>`
- **Files modified:** scripts/dsi_mmio_diff.sh
- **Verification:** fixtures B/B2/C state-row assertions green
- **Committed in:** deferred (planned feat(47-02) commit)

**3. [Rule 1 - Bug] dsi_mmio_diff.sh: ST field mapping off-by-one broke state-row citations**
- **Found during:** Task 1 (fixture-B manual inspection)
- **Issue:** the combine awk read `hdr_=$7`/`skl_=$8` from 9-field ST lines (fields are `st|n|f|hdr|skipline`), so a readable section with all-ones records would cite the wrong line and the PLL-off skip marker was never cited (`-` in the resume citation cell)
- **Fix:** `hdr_=$8`, `skl_=$9`; added selftest assertion `B: state row cites both arms with lines` pinning `boot_dsi_regs.txt:1; broken_dsi_regs.txt:1`
- **Files modified:** scripts/dsi_mmio_diff.sh
- **Verification:** selftest 26/26
- **Committed in:** deferred (planned feat(47-02) commit)

**4. [Rule 2 - Missing Critical] test_dsi_mmio_evidence.sh: negative backstop for the plan's backstop truth**
- **Found during:** Task 2
- **Issue:** the plan truth "The evidence suite can actually fail: its --fixtures mode … exits non-zero when a fixture violates the contract (verification: backstop)" was not proven by a satisfying-fixture-only mode
- **Fix:** added internal `--fixtures-violating` mode (a duplicate mechanism-claim heading + single citation anchor must make `mmio-diffdoc-citations` and `mmio-single-claim` fail) asserted from `--fixtures`
- **Files modified:** scripts/test_dsi_mmio_evidence.sh
- **Verification:** `--fixtures` 8/8 including the 3 backstop assertions; violating run exits non-zero
- **Committed in:** deferred (planned feat(47-02) commit)

---

**Total deviations:** 4 auto-fixed (3 Rule 1 bugs in the pre-existing partial artifact, 1 Rule 2 missing proof).
**Impact on plan:** All fixes required for the plan's own selftest/truth contract to hold; no scope creep. One ordering defect found during Task 2 (backstop mode block placed before its function definition) was caught by the fixtures run and moved below `run_doc_cases` — part of deviation 4.

## Issues Encountered

- The execution host's tool shell (pwsh) mangles inline `bash -c` argument substitution and reports unreliable `$?`; verification was restructured around script files and `if/else` exit sentinels (`PLAIN-EXITED-NONZERO` style) instead of `$?` echoes. Host quirk only — no repo impact.
- An earlier interrupted executor run had left `scripts/dsi_mmio_diff.sh` untracked on disk. Treated as a found artifact: verified against the behavior contract, fixed, extended. No commit existed for it (deferred mode), so nothing was redone in git.

## Known Stubs

None — both scripts are complete implementations; no placeholder data paths, no TODO/FIXME.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 47-03 registers `boot_dsi_regs.txt`, `broken_dsi_regs.txt`, `dsi_regs_diff.txt` in `docs/dumps/re_kit/MANIFEST.sha256` — `mmio-kit-manifest-covers` then goes green (case order: verify runs first).
- 47-04 writes `docs/research/DSI_MMIO_DIFF.md`: every row must quote the `file:line` citation format `dsi_mmio_diff.sh` emits; the exclusion table should mirror `build_exclusions()` verbatim; exactly ONE `## Mechanism claim`-shaped heading; a `what to restore/replicate` heading; ≥1 narrow `planner-discipline-allow:` marker derived from the ledger's alias column. The suite flips green when those land (plain mode red until then is the designed state).
- `/gsd-ship` must stage both new scripts with the exec bit (100755) — see Deferred Commits.

---
*Phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff*
*Completed: 2026-10-14*
