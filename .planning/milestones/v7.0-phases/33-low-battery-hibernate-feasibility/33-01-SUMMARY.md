---
phase: 33-low-battery-hibernate-feasibility
plan: 01
subsystem: power
tags: [hibernate, systemd, udev, python-daemon, env-seam-tests, bash-suite, swap]

# Dependency graph
requires: []
provides:
  - "Daemon honest degradation: env-seamed /proc/swaps + /sys/power + /proc/cmdline read, swap report + readiness verdict in --dry-run, refuse-and-degrade with rc-checked systemctl hibernate/suspend"
  - "Service ExecStart aligned to install path with oneshot/SYSTEMD_WANTS re-fire rationale comment"
  - "udev glob comment protecting ATTR{capacity}==\"[0-5]\" (functional line byte-identical)"
  - "scripts/test_hibernate_guards.sh (12 cases) wired into scripts/test_storage_cellular.sh --dry-run"
affects: [33-02, 33-03]

# Actuals (#2632) — same estimateTokens scale (chars/4 over realized diff)
actuals:
  tokens: 5300
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "python env-seam fixtures (D330_PROC_SWAPS/D330_SYS_POWER/D330_PROC_CMDLINE/D330_POWER_SUPPLY_DIR) driving the daemon with no root/battery/systemd"
    - "phase-32 guard-suite skeleton reused in bash (CASE_FAIL accumulation, expect_* helpers, passed/failed summary)"
    - "list-form subprocess only in daemon (sync + systemctl), rc captured and propagated (audit N5)"

key-files:
  created:
    - scripts/test_hibernate_guards.sh
  modified:
    - tools/d330-auto-hibernate.py
    - patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service
    - patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules
    - scripts/test_storage_cellular.sh

key-decisions:
  - "Readiness reason priority: hibernation not offered by kernel -> resume not configured -> no swap present / only zram swap present (plan-pinned; one readiness() call feeds both the printed verdict and the refusal decision)"
  - "Swap report + verdict print before the battery gate in BOTH --dry-run and real mode (superset of the dry-run-only requirement; journal gets the honest picture on every udev firing)"
  - "sync invoked as list-form subprocess.run([\"sync\"]) instead of os.system(\"sync\") to satisfy threat T-33-03 (no shell-string execution anywhere)"
  - "Suspend fallback rc also propagated as exit code, same handling as hibernate rc"

patterns-established:
  - "Env-seam fixture testing for python tools: D330_* env vars with real-path defaults, fixtures in mktemp dir, assert daemon markers only (never version-dependent systemd/kernel strings, R9)"
  - "Guard-suite static case pattern: ExecStart anchored grep vs install_dkms.sh copy target as a permanent regression gate"

requirements-completed: [SC2]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "d330-auto-hibernate.py swap/resume readiness read: --dry-run prints one row per swap area (path/type/size/used/priority, zram marker) plus one readiness verdict line before the battery gate; critical path refuses hibernate when not ready with [ERROR] + suspend fallback, and checks systemctl hibernate's return code when ready (threshold policy untouched at 5% discharging)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh (fixture cases zram-only-refuse, swapfile-ready-proceed, safe-battery-report, resume-not-configured, hibernation-unavailable, empty-swaps-refuse, malformed-swaps-tolerated, no-battery-report-first)"
        status: pass
      - kind: automated_ui
        ref: "task 1 verify block (bash, TRACER OK, rc=0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Service ExecStart fixed to /usr/local/bin/d330-auto-hibernate with Type=oneshot re-fire rationale comment; udev rule gained glob-explanation comment with the functional line byte-identical"
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#execstart-matches-install-path, #type-oneshot-kept, #udev-glob-comment"
        status: pass
      - kind: automated_ui
        ref: "task 2 verify block (bash, SERVICE/UDEV OK, rc=0)"
        status: pass
    human_judgment: false
  - id: D3
    description: "New scripts/test_hibernate_guards.sh (12 cases, failed=0) delegated from scripts/test_storage_cellular.sh --dry-run alongside the phase-32 suite, with bash -n coverage in the existing syntax loop"
    verification:
      - kind: integration
        ref: "bash scripts/test_storage_cellular.sh --dry-run (rc=0, delegates hibernate suite, [OK] dry-run verification complete)"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-10-08
status: complete
---

# Phase 33 Plan 01: Low-Battery Hibernate Feasibility (Wave 1) Summary

**Daemon now honest about hibernate readiness: env-seamed swap/resume report in --dry-run, refuse-and-degrade with rc-checked systemctl calls, ExecStart aligned to install path, 12-case guard suite green**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-10-08
- **Tasks:** 3 / 3
- **Files modified:** 5 (1 created)

## Accomplishments

- `tools/d330-auto-hibernate.py` reads swap/resume state through four env seams (real-path defaults): parses `/proc/swaps` defensively (missing/malformed/empty never crash), classifies zram by the systemd `/dev/zram*` path rule, checks `disk` in `/sys/power/state` and `resume` config, and prints a per-swap-area report + exactly one `hibernate readiness:` verdict line before the battery gate — success criterion 2 (SC2).
- Critical battery + not-ready now prints `[ERROR] hibernate skipped: <reason>` and falls back to `sync` + `systemctl suspend` (list form, rc propagated); ready path invokes `systemctl hibernate` through list-form `subprocess.run` and checks its return code — audit N5 at old line 48 and audit C3's false safety net are both closed at source.
- Service `ExecStart` now equals the installer's contract path `/usr/local/bin/d330-auto-hibernate`, with a comment documenting why `Type=oneshot` re-fires per udev `SYSTEMD_WANTS` event; udev rule functional line untouched, protected by a udev(7) glob comment.
- `scripts/test_hibernate_guards.sh` (12 cases) proves all of it fixture-driven (no root, no battery, no systemd, no real systemctl), and `scripts/test_storage_cellular.sh --dry-run` syntax-checks and delegates it.
- Threshold policy untouched: `CRITICAL_THRESHOLD_PERCENT = 5`, discharging-only gate, `[OK] Battery level safe.` and `[INFO] No battery power supply detected` behave as before (asserted by suite + verify).

## Task Commits

Each task was committed atomically via `gsd-tools query commit`:

1. **Task 1: End-to-end swap situation report + honest refuse-and-degrade (tracer)** - `d74d08b` (feat) — verify rc=0, printed `TRACER OK`
2. **Task 2: Service ExecStart alignment, oneshot rationale comment, udev glob comment** - `7c62661` (fix) — verify rc=0, printed `SERVICE/UDEV OK`
3. **Task 3: Fixture-driven guard suite + harness delegation** - `65148e3` (test) — verify rc=0, printed `HIBERNATE SUITE OK`, suite `passed=12 failed=0`

## Files Created/Modified

- `tools/d330-auto-hibernate.py` — env seams, `read_proc_swaps`/`classify_swap`/`readiness`/`print_swap_report`, refuse-and-degrade + rc-checked hibernate, `with`-block file reads (unclosed `open()` at old :30-31 fixed)
- `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` — `ExecStart=/usr/local/bin/d330-auto-hibernate`, oneshot/SYSTEMD_WANTS re-fire comment
- `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` — comment-only: udev glob `[0-5]` explanation + `TAG+="systemd"` necessity; functional line byte-identical (asserted)
- `scripts/test_hibernate_guards.sh` — NEW: 12-case fixture + static guard suite (phase-32 skeleton)
- `scripts/test_storage_cellular.sh` — added `scripts/test_hibernate_guards.sh` to the `bash -n` loop and the delegate call beside `test_microsd_guards.sh`

## Verify Raw Outputs

**Task 1 verify** (`bash w33_01_t1.sh`, exact plan block body):

```
TRACER OK
RC=0
```

**Task 2 verify** (`bash w33_01_t2.sh`):

```
SERVICE/UDEV OK
RC=0
```

**Task 3 verify** (`bash w33_01_t3.sh`):

```
==========================================================
 Lenovo D330 Hibernate Guard Suite (env-seam fixtures)
==========================================================
  [OK] zram-only-refuse
  [OK] swapfile-ready-proceed
  [OK] safe-battery-report
  [OK] resume-not-configured
  [OK] hibernation-unavailable
  [OK] empty-swaps-refuse
  [OK] malformed-swaps-tolerated
  [OK] no-battery-report-first
  [OK] execstart-matches-install-path
  [OK] type-oneshot-kept
  [OK] udev-glob-comment
  [OK] daemon-syntax-gates

==========================================================
 Guard suite summary: passed=12 failed=0
==========================================================
HIBERNATE SUITE OK
RC=0
```

**Full gate block** (plan `<verification>`, all six items): `GATE_RC=0`, ending `ALL GATES GREEN` — bash -n both suites OK, py_compile OK, ExecStart/install grep consistency OK, `test_auto_hibernate.sh --dry-run` prints `Logic verified successfully.`, harness rc=0, new suite `passed=12 failed=0`.

**Final full gate run** (`bash scripts/test_storage_cellular.sh --dry-run` rc=0, then `bash scripts/test_hibernate_guards.sh` rc=0) — tail -15:

```
  [OK] swapfile-ready-proceed
  [OK] safe-battery-report
  [OK] resume-not-configured
  [OK] hibernation-unavailable
  [OK] empty-swaps-refuse
  [OK] malformed-swaps-tolerated
  [OK] no-battery-report-first
  [OK] execstart-matches-install-path
  [OK] type-oneshot-kept
  [OK] udev-glob-comment
  [OK] daemon-syntax-gates

==========================================================
 Guard suite summary: passed=12 failed=0
==========================================================
```

## Decisions Made

- Refusal-reason priority pinned by the plan is implemented in one `readiness()` call so the printed verdict and the real-path decision can never diverge (plan `key_links`).
- Report-first ordering is enforced in code (report + verdict print before any battery read), so the no-battery path still shows the swap picture.
- Kept the original `[CRITICAL] Battery at N%! Initiating system hibernate...` wording (plan: gate byte-for-byte); the immediate `[ERROR] hibernate skipped:` line clarifies the actual outcome.

## Deviations from Plan

None material — plan executed as written (all acceptance criteria and verify blocks pass unmodified; no test contract changed).

Minor documented choices (within plan discretion, not scope changes):

1. **[Rule 2/clarification]** `sync` runs as `subprocess.run(["sync"])` (list form) instead of the old `os.system("sync")` — required by threat T-33-03 ("subprocess calls stay in list form... no shell-string execution anywhere"), which the plan's threat register mandates as a correctness requirement.
2. **Report prints in real mode too**, not only `--dry-run` (plan pinned it for dry-run; printing always is a strict superset, gate behavior unchanged).
3. `python3 -m py_compile` generates `tools/__pycache__/` — already covered by existing `.gitignore` lines 10-11 (`__pycache__/`, `*.pyc`), so no generated file is left untracked.

## Issues Encountered

- WSL git reports the `.planning/` junction as "all files deleted" (junction traversal artifact of WSL git). Windows git status — used for all commits — is clean and unchanged from session start; no action taken, no files deleted. Recorded so future waves don't misread it.
- None other; no auto-fix attempts were needed (0 deviations by rule).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 33-02 (swapfile unit + resume activation plumbing + enable sites) builds on the seam/readiness functions landed here; `run_power_action` and `readiness` are the integration points.
- Plan 33-03 (on-device round trip) must prove real `systemctl hibernate` rc + power-cycle resume (research risk R1) — real-mode refusal/hibernate paths are construction-asserted only (list-form + rc propagation), as the plan anticipated.
- No blockers.

---
*Phase: 33-low-battery-hibernate-feasibility*
*Completed: 2026-10-08*
