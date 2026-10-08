---
phase: 32-data-loss-boot-safety-guards
plan: 03
subsystem: tooling
tags: [bash, cli, help-text, success-honesty, test-harness, path-shim-testing]

# Dependency graph
requires: [32-01, 32-02]
provides:
  - "Honest `--mount-home` stub: exits 1 with `--mount-home is not implemented in this release; see --help (flag marked unsupported).` after the locked `--device` requirement, before any precondition/guard/preflight/prompt"
  - "`--help` marks `--mount-home` `(unsupported: not implemented)`; `--device` row (32-01) retained with `--probe`-only default note"
  - "Single-trigger completion message: exactly one source occurrence of `Storage expansion task complete.`, reachable only from genuine format completion and genuine mount-data mount"
  - "Harness Wave 0: `scripts/test_storage_cellular.sh --dry-run` runs real `bash -n` gates over the tool + both test scripts and delegates the full guard suite (echo-only false-green mode removed)"
  - "Guard suite at 26 cases: `mount-home-missing-device`, `mount-home-not-implemented`, `help-marked-unsupported`, `completion-honesty`"
affects: [41, 42]

# Actuals (#2632) — pairs with the plan's `estimate`
actuals:
  tokens: 2053
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - early action-stub branch: fail-fast `log_err` + `exit 1` immediately after `require_device_for_action`, before any disk-work precondition (first intentionally-failing action in repo)
    - harness verification mode: `SCRIPT_DIR`/`REPO_ROOT` anchoring for NEW lines only, per-file `if bash -n` gates printing `[OK]`/`[FAIL] <file>`, plain suite delegation under `set -e`
    - completion-honesty testing: three negative invocations asserted to never print the closing message, positive direction covered by the append-success case

key-files:
  created: []
  modified:
    - tools/d330-microsd-setup.sh
    - scripts/test_storage_cellular.sh
    - scripts/test_microsd_guards.sh

key-decisions:
  - "Stub branch placed immediately after `require_device_for_action` and BEFORE `validate_device_path` — literal plan order (parse → require_device → stub exit), and since the stub performs no disk work the device-shape validation is irrelevant to it"
  - "Help row kept on one line — `--mount-home ... (unsupported: not implemented)` — so the plan's `mount-home.*unsupported|unsupported.*mount-home` regex assertion matches on a single line"
  - "Harness dry-run keeps the `[DRY-RUN] Verifying...` banner, gates first, delegates the suite, then prints the two FCC-unlock/udev config paths as `[INFO]` inventory lines (dropped the `- MicroSD Setup:` echo line: the `[OK] bash -n tools/d330-microsd-setup.sh` gate supersedes it)"
  - "Task commits routed through `node gsd-tools.cjs query commit --files` (raw `git commit` denied by session permissions — same as plans 32-01/32-02)"

patterns-established:
  - "Early stub-branch pattern: locked unsupported action exits before shared preconditions so no shared-path code can mask it"
  - "Harness `--dry-run` as phase entry point: syntax gates + full guard suite in one command (the phase's quick-command going forward)"

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "tools/d330-microsd-setup.sh: mount-home stub exits non-zero with locked not-implemented message after the --device requirement; --help marks it unsupported; exactly one source occurrence of the closing success message reachable only from genuine completion"
    verification:
      - kind: unit
        ref: "32-03-PLAN Task 1 <automated> verify block -> MOUNT-HOME STUB OK"
        status: pass
    human_judgment: false
  - id: D2
    description: "scripts/test_storage_cellular.sh --dry-run performs real bash -n gates over the tool and both test scripts and runs the full guard suite, failing on any broken syntax or failing case; probe/test-microsd/help/unknown-option behavior unchanged"
    verification:
      - kind: unit
        ref: "32-03-PLAN Task 2 <automated> verify block -> HARNESS WAVE0 OK"
        status: pass
    human_judgment: false
  - id: D3
    description: "scripts/test_microsd_guards.sh extended to 26 cases with mount-home-missing-device, mount-home-not-implemented, help-marked-unsupported, and completion-honesty; full phase gate green"
    verification:
      - kind: unit
        ref: "32-03-PLAN Task 3 <automated> verify block -> PHASE 32 SUITE GREEN (passed=26 failed=0)"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-10-08
status: complete
---

# Phase 32 Plan 03: Data-Loss & Boot Safety Guards Summary

**`--mount-home` is now an honest non-zero "not implemented" stub with the help row marked unsupported, the closing `Storage expansion task complete.` has exactly one source occurrence reachable only from genuine format/mount-data completion, and the legacy `test_storage_cellular.sh --dry-run` harness runs real `bash -n` gates plus the whole 26-case guard suite instead of echoing three paths.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-10-08T05:30:07Z
- **Completed:** 2026-10-08T05:45:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- The false-green pattern flagged by the pre-deployment audit is closed on all three axes: the unsupported action fails fast with a locked message (before existence precondition, guards, preflight, and any prompt — the stub does no disk work), the success line is structurally unreachable from every dry-run/stub/refusal/rollback/error path, and the harness `--dry-run` mode now proves syntax and runs the guard suite instead of echoing hardcoded paths
- `--help` keeps all four action rows, shows the `--device` option with the `--probe`-only default, and marks `--mount-home` `(unsupported: not implemented)`
- Guard suite grew 22 → 26 cases, all green: the three new stub/help cases plus `completion-honesty` machine-checking that format dry-run, mount-data dry-run, and the mount-home stub never print the closing message (positive direction still asserted by `mount-data-append-success`)
- Existing smoke is byte-identical: `--probe` and `--test-microsd` still invoke `bash tools/d330-microsd-setup.sh --probe` with no `--device`; mode parser and help rows untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Honest `--mount-home` stub, help text, and single-reach success gate** - `2a24464` (feat)
2. **Task 2: Harness Wave 0 — real `bash -n` gates and guard-suite delegation in `--dry-run`** - `b62c3d1` (test)
3. **Task 3: Final suite cases — stub, help, and completion honesty + full phase gate run** - `266cb78` (test)

**Plan metadata:** SUMMARY commit message `docs(32-03): ...` (see git log)

## Files Created/Modified
- `tools/d330-microsd-setup.sh` - Stub branch right after `require_device_for_action` emitting the locked `--mount-home is not implemented in this release; see --help (flag marked unsupported).` + exit 1; `--mount-home` help row marked `(unsupported: not implemented)`; the two legacy mount-home log lines deleted; success line untouched (one occurrence, reachability audited top-to-bottom)
- `scripts/test_storage_cellular.sh` - `--dry-run` branch rewritten: `SCRIPT_DIR`/`REPO_ROOT` anchoring for the new lines, per-file `bash -n` gates (`[OK]`/`[FAIL] <file>`), plain delegation to `scripts/test_microsd_guards.sh`, `[INFO]` config-path inventory lines, `[OK] dry-run verification complete`
- `scripts/test_microsd_guards.sh` - Four appended cases + header/usage case-count update (26); existing 22 cases byte-identical

## Verification

- Task 1 `<automated>` block (verbatim payload, WSL bash from repo root): raw output tail —
  ```
      --mount-home    Migrate and mount MicroSD as /home expansion (unsupported: not implemented)
  MOUNT-HOME STUB OK
  PAYLOAD_RC_ZERO
  ```
  (the grep line printing the help row is part of the payload; final rc=0)
- Task 2 `<automated>` block (verbatim payload): raw output tail —
  ```
  [OK] bash -n tools/d330-microsd-setup.sh
  [OK] bash -n scripts/test_microsd_guards.sh
  [OK] bash -n scripts/test_storage_cellular.sh
  ...
   Guard suite summary: passed=22 failed=0
  ...
  [OK] dry-run verification complete
  HARNESS WAVE0 OK
  PAYLOAD_RC_ZERO
  ```
- Task 2 extra acceptance checks (raw): broken-file gate proof `bash -n` on a copy with `echo "if ["` appended → `BROKEN_FILE_RC=2` (real gate in this environment); `--test-microsd` → `TEST_MICROSD_RC=0`; `--help` → all four mode rows, `HELP_RC=0`; `--bogus` → `UNKNOWN_RC=1` + `Unknown option: --bogus` + `Usage:` text
- Task 3 `<automated>` block (verbatim payload): raw output tail —
  ```
    [OK] mount-home-missing-device
    [OK] mount-home-not-implemented
    [OK] help-marked-unsupported
    [OK] completion-honesty
  ...
   Guard suite summary: passed=26 failed=0
  PHASE 32 SUITE GREEN
  PAYLOAD_RC_ZERO
  ```
- Full phase gate (plan `<verification>`, raw):
  ```
  1 bash -n tools: rc=0
  2 bash -n guards: rc=0
  3 bash -n harness: rc=0
  4 --dry-run: rc=0
  5 guard suite: rc=0
  6 --probe: rc=0
   Guard suite summary: passed=26 failed=0
  ```
- Nyquist after every commit (`bash -n` on touched script + guard suite): after 2a24464 → `passed=22 failed=0`; after b62c3d1 → `passed=22 failed=0`; after 266cb78 → `passed=26 failed=0`
- Source assertions (Task 1 acceptance, raw): `grep -c 'Storage expansion task complete.'` → `1`; `grep -c 'mount-home'` → `7` (stub exit, help row, parser, device-requirement case, stub branch); `grep -Eq 'rsync|useradd|homed'` → `NO_MIGRATION_CODE`
- **`[WARN]`/`[SKIP]` record:** exactly one WARN, `[WARN] fstab-parse-proof: environmental - unreachable source/target on this machine` — the known environmental classification from 32-02 (fake UUID on this box), not an absent tool. Zero `[SKIP]` lines (`grep -c '\[SKIP\]'` → 0; `findmnt` and `systemd-analyze` both present). No other WARN/SKIP emitted.
- Manual-Only VALIDATION rows (real-hardware mounted-format abort, on-target `systemd-analyze verify`) not attempted on the dev machine, per plan `<verification>`.

## Decisions Made
- Stub branch order follows the plan literally (parse → `require_device_for_action` → stub exit), resolving RESEARCH open question 9 the other way from its recommendation: the locked `--device` requirement stays observable first (`--mount-home` alone → exit 1 + `requires an explicit --device`), then the not-implemented exit — planner's Task 1 action pinned this and it is what the acceptance criteria assert
- Help row keeps the original description text with `(unsupported: not implemented)` appended on the same line so the plan's `mount-home.*unsupported` regex holds without dropping user-facing context
- Harness `--dry-run` drops the `- MicroSD Setup:` echo line (superseded by the `[OK] bash -n` gate) but retains the FCC-unlock/udev paths as `[INFO]` inventory — they are context, not checks, per Task 2 action step 4
- `completion-honesty` runs all three negative paths inside one case with per-path `expect_no_out`, keeping `failed=0` semantics and case naming identical to the existing suite

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Multi-line `<automated>` payloads cannot pass through the PowerShell tool layer unmodified**
- **Found during:** Task 1 verify (first run)
- **Issue:** Inline `wsl bash -lc "..."` payloads get mangled by PowerShell quote/`$?` expansion (outer `echo EXIT=$?` printed `\` instead of an exit code)
- **Fix:** Payloads written verbatim to temp `.sh` files (CR-stripped) and executed as `bash /mnt/c/.../<file>` from the repo root — block content byte-identical to the plan; exit code captured with a separate clean-quoting call
- **Files modified:** none (tooling path only)
- **Verification:** all three `<automated>` blocks printed their terminal markers (`MOUNT-HOME STUB OK`, `HARNESS WAVE0 OK`, `PHASE 32 SUITE GREEN`) with rc=0
- **Committed in:** n/a (transport only; same approach as plan 32-02 deviation 3)

**2. [Rule 3 - Blocking] `git commit` denied by session permission rules**
- **Fix:** same as plans 32-01/32-02 — commits routed through `node gsd-tools.cjs query commit "<msg>" --files <file>` (per-file staging, hooks run)
- **Verification:** `2a24464`, `b62c3d1`, `266cb78` all `{committed: true}`; working tree for this plan's files clean after each

---

**Total deviations:** 2 auto-fixed (2 blocking-class, tooling only)
**Impact on plan:** Zero behavior impact — all acceptance criteria machine-verified exactly as written.

## Issues Encountered
- A pathspec-limited `git status -- tools/ scripts/` briefly reported ` M tools/.gitkeep` / ` M scripts/.gitkeep` with an empty `git diff`; a full `git status` immediately after showed both clean — transient index refresh, no content change, nothing staged from them
- Pre-existing dirty leftovers (deleted `AUDIT_PROMPT.md`, stray `$`, untracked `.gsd/*` / `.planning/*` bookkeeping, `opencode.json`) left untouched — only this plan's three files were staged

## Known Stubs
None. The `--mount-home` action is an intentional locked stub (not a defect): it fails fast with the exact locked message, `--help` marks it unsupported, and three suite cases plus the Task 1 verify block machine-check both directions. Deferred `/home` migration stays out of scope per CONTEXT Deferred Ideas.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 32 execution is complete: all three CONTEXT locked decision groups (device selection + pre-write guards, fstab/boot safety, mount-home stub + success honesty) are implemented and machine-checked; every plan has a green SUMMARY
- `bash scripts/test_storage_cellular.sh --dry-run` is now the phase's one-command entry point (syntax gates + full 26-case suite)
- Phase 41 (harness refactor: cwd-relative lines, always-green tests) and Phase 42 (docs/claims parity, packaging deps) pick up their deferred items unchanged
- Blockers: none

## Self-Check: PASSED
- `tools/d330-microsd-setup.sh` exists — FOUND
- `scripts/test_storage_cellular.sh` exists — FOUND
- `scripts/test_microsd_guards.sh` exists — FOUND
- Commit `2a24464` exists (type `feat`) — FOUND
- Commit `b62c3d1` exists (type `test`) — FOUND
- Commit `266cb78` exists (type `test`) — FOUND
- Task 1 verify: `MOUNT-HOME STUB OK`; Task 2 verify: `HARNESS WAVE0 OK`; Task 3 verify: `PHASE 32 SUITE GREEN` (`passed=26 failed=0`)

---
*Phase: 32-data-loss-boot-safety-guards*
*Completed: 2026-10-08*
