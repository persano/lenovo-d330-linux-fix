---
phase: 50
plan: 50-05
status: complete
completed: "2026-10-17T02:50:00+01:00"
---

# Plan 50-05: Session B black-resume + diff + verdict — Summary

## What Was Built

The second and final device session: echo-2 capture at the black-resume arm (X=Z), the i2c wake trace, the boot-vs-resume MMIO diff, and the phase verdict document.

## Tasks

| Task | Name | Status |
|------|------|--------|
| 1 | Session B — suspend, wake, resume2 capture + trace (checkpoint:human-verify) | ✅ |
| 2 | Fetch + diff X=Y vs X=Z | ✅ |
| 3 | Verdict: `docs/research/TCON_IDENTIFICATION.md` | ✅ |

## Session B Record (X=Z)

- Suspend armed by orchestrator; first auto-wake window (10 min) expired without wake — user woke the device manually; capture ran immediately after user confirmation ("screen lit but black", eyes-on X=Z).
- `resume2` capture: trigger 2026-10-16 23:48:43 -0300, 131006 B, 7296 records, all sections 100%, DCS section validated, sha `da692043…3f24`.
- i2c wake trace: 60 lines, sha `e504f9fd…7f68` — only Goodix touchscreen (i2c-1 @0x14) + one i2c-3 write between wake and capture; **no TCON sideband**.
- Host sha256s byte-identical to device records.

## Headline Result

**X=Z DCS reads: identical dead result — `ret=4 avail=0 data=00 00 00` for all five reads.** Software DCS read path proven dead in BOTH arms (3 runs total, X=Y twice + X=Z once, byte-identical section). Verdict + falsification of the E3 discriminator recorded in `docs/research/TCON_IDENTIFICATION.md`.

## Diff

`dsi_regs_diff_tcon_boot_vs_resume.txt`: 24 rows, DCS comparison block emitted (5 read ids), written by `scripts/dsi_mmio_diff.sh` (selftest 52/0).

## Kit Registration

Nine phase-50 artifacts total registered in `docs/dumps/re_kit/MANIFEST.sha256`; `prepare_safety_kit.sh --verify` exit 0.

## Deviations

1. Task 1's auto-wake polling window (10 min) expired; wake was manual and capture ran on the user's confirmation instead of on ssh-detect. One boot, one suspend, one wake — protocol shape preserved (capture within the stable X=Z state, no re-suspend).
2. Sessions executed inline by the orchestrator (pwsh ssh + `sudo -S` via stdin) at the user's request for speed, instead of a subagent dispatch.

## Gates (final, all green)

`dsi_mmio_diff.sh --selftest` 52/0 · `test_dsi_mmio_evidence.sh` 7/0 · `test_pitfalls_ledger.sh` 4/0 · kit `--verify` exit 0.

## Requirements Touched

TCON-02 (both arms captured, kit-registered, verdict states identity NOT obtainable — read path dead with failure mode documented), TCON-03 (written conclusion: 11 buses, no PMIC by name on bus 6, no TCON sideband in either arm), TCON-01/TCON-04 already closed by 50-01/50-02/50-03.
