---
phase: 51
plan: 51-02
status: complete
started: "2026-10-17T00:00:00Z"
completed: "2026-10-17T00:00:00-03:00"
subsystem: instrument-chain (capture script + diff tool + runbook)
tags: [capture, dsi-mmio, runbook, x=y-criterion]
requires: [51-01]
provides: [rung-capture-arms, x=y-operational-set-verdict, rung-runbook-block]
affects: [51-03]
<!-- planner-discipline-allow: 0x160018 -->
tech_stack:
  added: []
  patterns: [self-extension of proven scripts, selftest fixtures, runbook-block-not-script]
key_files:
  created: []
  modified: [scripts/capture_dsi_dumps.sh, scripts/dsi_mmio_diff.sh, docs/research/RESUME_CAPTURE_PROTOCOL.md]
decisions:
  - "X=Y check keys off the RESUME arm only (the ~4 s discriminator dump); resume DSI-range presence gates the section"
  - "Per-register X=Y lines are plain text (0xOFF expected=… actual=… match|mismatch), not table rows — keeps fixture D's zero-rows assertion and the main table's row grammar intact"
actuals:
  tokens: 3725
  tasks: 3
  commits: 3
---

# Plan 51-02: Rung-session capture tooling (resume arms + X=Y check + runbook) — Summary

## What Was Built

Rung-session capture tooling for the keep-panel-powered ladder: `resumefast`/`resumelate` echo-1 arms in the capture script (the ~0-1 s pre-KWin-commit and ~4 s post-KWin-commit dump pair inside one ≥18 s wake window), a first-class `## X=Y operational set` verdict section in `dsi_mmio_diff.sh` (six-register binary criterion, design-doc fact 10 quoted verbatim, proven by X=Y and X=Z selftest fixtures), and the rung-session runbook block in `RESUME_CAPTURE_PROTOCOL.md` (dmesg-based marker collection, two-dump window discipline, rtcwake suspend mechanism, kit registration, success-path battery block, A1 pre-check).

## Tasks

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | `resumefast`/`resumelate` echo-1 arms in `capture_dsi_dumps.sh` | ✅ | `fac6aef` |
| 2 | X=Y operational-set verdict in `dsi_mmio_diff.sh` + X/Z fixtures | ✅ | `f224c4d` |
| 3 | Rung-session runbook block in `RESUME_CAPTURE_PROTOCOL.md` | ✅ | `82948af` |

## Arm names as shipped

`resumefast` (~0-1 s post-wake, pre-KWin-commit) and `resumelate` (~4 s post-wake, post-commit — the X=Y/X=Z discriminator). Both echo-1, synchronous, triggered manually by the runbook inside one ≥18 s wake window; EBUSY = another trigger in flight. Node discovery (dri/*/i915_dsi_regs minor glob), record-floor gates (sections f-g) and the session-record echo contract are byte-identical in behavior to the pre-existing arms.

## X=Y operational-set check

Emitted iff the RESUME arm carries the DSI range (0x6b000 section readable); seven per-register lines against the verbatim literal `0x6b010=003fffff, 0x6b044=0000001d, 0x6b080/0x6b098=09051003, 0x6b088=0022000f, 0x6b094=1, 0x160018=00000115`, plus one verdict line: `verdict: X=Y` iff all seven match, `verdict: X=Z` otherwise (a missing register counts toward X=Z). Fixture X (exact X=Y values → X=Y) and fixture Z (known-broken counterparts → X=Z, 0/7) prove both directions; the five historical fixtures and determinism fixture E pass untouched.

## Runbook block

`RESUME_CAPTURE_PROTOCOL.md` §Rung-session block: one-time `dmesg | grep -c D330SEQ` pre-check (expected 0, research A1); dmesg-only marker collection (`dmesg | grep 'D330 82H0'`, compiled-in markers only, archived excerpt); `rtcwake -m no -s 45` + `systemctl suspend`, then `resumefast` → `resumelate` inside the single ≥18 s window (never shortened — a 6 s window already produced one wrong conclusion); kit registration of both dumps + marker excerpt; success-path battery block (`upower -i $(upower -e | grep BAT)` before/after one 15-min S3 keep-hot ON vs OFF, fallback `/sys/class/power_supply/BAT*`). No script invented — runbook block only, per 51-PATTERNS.

## Deviations from Plan

None of substance. One implementation note: the X=Y per-register output is plain lines (`0x6b010 expected=003fffff actual=003fffff match`) rather than a markdown table — the first table-shaped draft tripped fixture D's pinned `^\| 0x` zero-rows assertion and the section-header line tripped a match-count assertion; the plain-line shape matches the plan's "per-register expected-vs-actual lines" wording and keeps every historical fixture assertion untouched.

## Gates

`bash scripts/dsi_mmio_diff.sh --selftest` **58/0** (was 52/0; grew by exactly the 6 new X/Z assertions), `test_dsi_mmio_evidence.sh` 7/0, `test_pitfalls_ledger.sh` 4/0 — green after every task. `bash -n` clean on the capture script. `RESUME_CAPTURE_PROTOCOL.md` is allowlisted in the ledger gate, so no allow markers were needed for the runbook block.

## Requirements Touched

KEEP-02 (rung capture arms land the two post-wake dumps inside the window discipline), KEEP-03 (X=Y operational-set check is the binary diff verdict for the ~4 s dump; runbook block defines how the session produces it).

## Deferred Commits

None — all three task commits landed individually (`fac6aef`, `f224c4d`, `82948af`); no code left uncommitted by this plan. Orchestrator owns `.planning/STATE.md` / `ROADMAP.md` updates.

## Self-Check: PASSED

All three files exist; commits `fac6aef`, `f224c4d`, `82948af` verified ancestors of HEAD; ledger gate green over the SUMMARY itself.
