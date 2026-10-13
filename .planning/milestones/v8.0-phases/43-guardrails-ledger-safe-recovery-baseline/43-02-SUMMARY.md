---
phase: 43
plan: 43-02
wave: 1
status: complete
commits:
  - 6ba303b
  - dc5e5a0
requirements: [RECOV-01, RECOV-03]
---

# Plan 43-02 — Hook Hardening (Real-Fix Stand-Down + Journal Triage)

## What shipped

- `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` — hardened additively, zero behavior change to the proven reload mechanism:
  - `D330_REAL_FIX` stand-down inserted between the `D330_DISPLAY_RESUME=0` disable check and the timeout-bounded reload: when the state file carries `D330_REAL_FIX=1` the hook logs "real fix active (D330_REAL_FIX=1); reload hook stands down" and exits 0 (RECOV-03 non-fighting contract; Phase 45 writes the marker).
  - Header comment documents the coexistence contract in plain prose (contract ships in Phase 43, marker written by Phase 45).
  - Distinct failure logging around the one bounded attempt: `timeout 30 "$0" _run` exit status is captured; rc=124 logs "i915 reload timed out after 30 seconds (rc=124)", any other non-zero logs "i915 reload/restart failed (rc=$rc)"; success stays silent as before. The invocation string is untouched and remains on exactly one call site; the bare no-timeout fallback stays only inside the `command -v timeout` else-branch; no retry construct anywhere.
  - All proven invariants hold byte-identical: `case "${1:-}/${2:-}"` dispatch, `DRV=/sys/bus/pci/drivers/i915`, `DISABLE_FILE=/etc/default/lenovo-d330-display-resume`, the exact `82H0` DMI literal comparison, the DM restart ladder (display-manager.service → sddm.service → logged failure), and the disable path with its log line.
- `scripts/test_display_fix_guards.sh` — extended 10 → 16 cases, all green:
  - `hook-standdown-contract`: D330_REAL_FIX present, stand-down log text present, contract comment present, stand-down line number precedes the timeout invocation line (grep -n ordering), disable path + log line intact, hook passes bash -n.
  - `hook-dmi-gate`: exact product-name literal comparison present.
  - `hook-bounded-attempt-exactly-once`: `timeout 30 "$0" _run` count == 1; bare `"$0" _run` fallback count == 1 (line-anchored so the timeout line's `_run` tail does not double-count); fallback line below the `command -v timeout` guard line; no for/while/until keyword between the guard and the fallback (single bounded attempt per the locked decision).
  - `hook-distinct-failure-logging`: both distinct log texts present; `logger -t d330-display` tag count does not drop below 7.
  - `hook-dm-ladder-intact`: display-manager → sddm fallback → failure log all present.
  - `hook-constants-unchanged`: DRV, DISABLE_FILE, and the case-dispatch line byte-identical.
- The retired-unit zero-refs case stays green; no service unit re-added.

## Verification

- `bash -n patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` → exit 0.
- `bash scripts/test_display_fix_guards.sh` → `Guard suite summary: passed=16 failed=0`.
- Full harness chain deliberately NOT run in this wave-1 plan (races 43-01's rewrite of the chain host file, per the iteration-2 checker correction); the chain is asserted once by 43-04 (wave 2).

## Deviations

- Executed inline by the orchestrator (subagent dispatch broken, disclosed at wave-1 start). Plan followed exactly; no worktree (ISOLATION=none milestone-wide).

## Requirements touched

- RECOV-01: proven auto-restoration mechanism unchanged and now machine-pinned by six new hook cases.
- RECOV-03: non-fighting stand-down implemented and ordered suite-asserted; disable path still works and logs.
