# 51-06 SUMMARY: Ladder closure - proof chain overturned, fix landed from upstream

**Status**: DONE (executed 2026-10-19, user-signed closure run).
**Commit scope**: this file, `docs/research/NO_CLEAN_FIX_PROOF.md` S9,
ledger row 34 (already in tree, gate green 4/0).

## What the plan assumed vs what happened

51-06 expected one of two outcomes: ladder lands, or every rung falsified
and the closure documents the dead end + Phase 53 escalation. Both were
recorded honestly first: E1/E3 falsified (51-03, 51-05), Phase 53
escalation opened, purchase declined by user verbatim
("totally decline, do not want to spend a dime!").

A third outcome then arrived from outside the ladder: the upstream
GLK reset-order fixup from issue #13225 (note 3698515), adapted for
our v7.0 tree in `patches/d330_dsi_glk_reset_order_fixup.patch`
(sha F97F4E87, one-line dispatch change: `IS_GEMINILAKE(i915)` ->
`display->platform.geminilake`).

## The verdict that replaces "no clean fix"

The file's S7/S7.1 conclusion ("the mechanism is below host MMIO, no
clean fix exists") is **overturned, and S9 of NO_CLEAN_FIX_PROOF.md says
so in the file's own voice**:

- Root cause (vsyrjala, #13225 note 3169683): the D330 VBT is
  "kinda borked" - empty `MIPI_SEQ_DEASSERT_RESET`, panel reset pulse
  (GPIO 160) executed from `INIT_OTP` AFTER the DSI host is up.
  `vlv_fixup_mipi_sequences()` repairs this at VBT parse time but
  only for VLV + v1 blocks; GLK fell through unpatched.
- Why rows 30-33 still stand: every host-MMIO lever is genuinely
  non-discriminating (row 32 byte-identical trap unchanged). The fix
  lives in sequence *ordering* at parse time - below any register dump
  a rung could have captured. The falsification of the ladder was
  correct; only the generalization ("no clean fix") was wrong.
- Validation, eyes-on, this unit: 10/10 lit S3 resumes in a rtcwake
  loop + every reboot since shows graphics. User verbatim: "it is lit
  with graphics! all the times it booted well!!!!" Evidence: ledger
  row 34, dumps `docs/dumps/re_kit/glkfix/`.

## Ledger integrity (the plan's must-have)

- Row 34 appended; machine table = 34 rows; header line 58 counts
  machine-table only and parses clean.
- `scripts/test_pitfalls_ledger.sh` exits 0 (4/0) with the narrow
  `planner-discipline-allow` markers added in this phase's summaries
  (precedent: 51-01, 51-02).
- CI stack after E1/E3 removal: CCS baseline + dump debugfs + GLK
  fixup, 3 grep anchors (rationale comments preserved in
  `build-kernel.yml`).

## Escalation retired

Phase 53 buy-gate: purchase declined, and the content question it
existed for (what does the GOP put on the wire) no longer needs
answering - the fix does not touch the wire protocol, it reorders the
host's own sequence execution. Block 55 decoded negative
(`BDB_COMPRESSION_PARAMETERS_OLD`). Phase 53 closes dead-by-decline +
superseded. Phase 52 (self-healing hotkey) closes superseded: there is
no black resume left to heal.
