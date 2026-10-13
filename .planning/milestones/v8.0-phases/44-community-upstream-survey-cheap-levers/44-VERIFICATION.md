---
phase: 44
status: passed
verified_at: 2026-10-12
---

# Phase 44 Verification — community-upstream-survey-cheap-levers

**Phase goal:** settle the cheap upstream questions (SURVEY-01/02/03) before Phase 45's costly RE/differential.
**Verified:** 2026-10-12 — goal-backward against deliverables, commits, and the live harness (not SUMMARY claims).

## Goal assessment per requirement

| Req | Requirement (REQUIREMENTS.md) | Status | Evidence |
|-----|------------------------------|--------|----------|
| SURVEY-01 | Documented survey of upstream/community state confirms whether GLK DSI resume is a fixed regression anywhere | **SATISFIED** | `docs/research/UPSTREAM_SURVEY.md`: 9-source table with URLs + per-source status; ChromeOS marked UNREACHABLE (not evidence of absence); drm/intel marked bot-walled (browser-only). Conclusion answers the question: no tracked-and-fixed GLK DSI resume-black regression upstream, qualification (absence rests on mail-archive mirror + GitHub history + search snippets) stated. Jinman Ma Aug-2026 quote confirms DSI resume-blank is a live, unowned problem class. |
| SURVEY-02 | Test kernel checked against known GLK DSI fixes (`615c8ec48621`) and mainline sweep yields a good/bad pair if one exists | **SATISFIED (with noted limitation)** | Survey §3: commit analyzed (v6.18, fastset cleanup, not a resume fix, no stable backport); device-side check `has_dsic_clock` at `vlv_dsi_pll.c:266,293,367,526` in the device source tree; both bootable kernels share the Ubuntu 7.0.0-38.38 base, v7.0.x > v6.18 ⇒ fix present in every bootable kernel while the failure persists ⇒ pair impossible on that axis. Sweep executed on-device on BOTH bootable kernels (`docs/research/KERNEL_SWEEP_EVIDENCE.md`: verbatim cmdlines, boot ids, S3 timestamps, clean dmesg/journalctl excerpts, sysfs state). Wider mainline sweep honestly ruled out (no candidate version carries a GLK DSI resume fix). **Limitation:** kernel-axis good/bad pair NOT established — panel verdicts unreliable (see Deviations). Recorded honestly, not hidden. |
| SURVEY-03 | Correctly-formed i915 bug report (trace + reproducer) filed or updated on the upstream tracker | **SATISFIED per documented handoff** | `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md`: self-contained report (hardware 82H0 block, kernel versions, mainline-only `rtcwake -m mem -s 30` reproducer, real sweep trace excerpt, ruled-out list, maintainer ask). Literal filing NOT done: tracker is bot-walled for scripts and no credentials exist on this machine — filing is a documented user handoff (issue 6619 update-or-new, paste-and-submit header), resolved in 44-CONTEXT.md grey area 1 during planning. Filing remains an open user action. |

## Evidence inspected

- **246635d** — creates `docs/research/KERNEL_SWEEP_EVIDENCE.md` (114 lines) + plan marker fix.
- **155f17f** — creates `docs/research/UPSTREAM_SURVEY.md` (91 lines) + sweep-doc markers.
- **8c6a563** — creates `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md` (125 lines).
- **2849796** — summary + validation rows (panel-verdict manual row honestly flipped to NOT SATISFIED) + roadmap.
- All three deliverables committed clean (working tree shows only GSD bookkeeping, no `docs/` modifications).
- Deliverable contents verified by reading, not by SUMMARY claims: both docs carry the honest verdict-retraction record, the dpms=Off confound, and the no-inhibit-hold method deviation.

## Harness result

- **CHAIN_EXIT=1 at initial verification** (ledger gate `passed=3 failed=1`, see gap 1). Post-fix re-run: `Ledger gate suite summary: passed=4 failed=0` and full chain `CHAIN_EXIT=0` with all 38 suites green.
- First invocation also hit a transient WSL VM failure (0x8007054f, mirrored-networking fallback — known machine quirk); subsequent runs executed the real suite.

## Gaps (blocking)

1. **RESOLVED — ledger gate red on the final tree (banned-lever alias quoted without a marker).**
   - Initial state: `scripts/test_pitfalls_ledger.sh` → `passed=3 failed=1`, `[FAIL] pristine-tree-passes`; hit was ledger row 17's bare `rescan` alias at `.planning/phases/44-community-upstream-survey-cheap-levers/44-01-SUMMARY.md:19`.
   - Fix applied: `<!-- planner-discipline-allow: rescan -->` added to the SUMMARY; re-ran the ledger gate (`passed=4 failed=0`) and the full chain (`CHAIN_EXIT=0`).

## Deviations noted (non-blocking)

- **Panel verdicts unreliable — kernel-axis good/bad pair NOT established.** User answered per arm (A "BLACK", B "LIT"), then retracted, admitted not watching continuously, could not recall, and declined a re-test with a three-state vocabulary. Recorded in the evidence doc, survey §4, VALIDATION.md manual-only row, and SUMMARY. SURVEY-02 still passes: the requirement's decisive part (pair on the `615c8ec48621` axis) is answered decisively — impossible, fix present-and-failing. Phase 45's differential will measure panel state with proper instrumentation.
- Arm A confound: pre-suspend `dpms=Off`, so the inter-arm sysfs delta is not attributable to the kernel version (recorded).
- Method deviation: no `systemd-inhibit` hold; detached `rtcwake` only (recorded in the evidence doc).
- One-time grub change (`GRUB_DEFAULT` → `saved`) was user-approved before the sweep, used for two kernel switches, and fully reverted (`update-grub` re-run, both GRUB env stores cleared, stray files removed). Cmdline and hooks untouched; display-resume hook stayed uninstalled.
- Residual human actions: file the prepared bug report (SURVEY-03 handoff); optionally re-run the panel verdict with the three-state vocabulary.

## Verdict

Phase 44's three requirements are achieved with honest, committed evidence: SURVEY-01/02 answered decisively (no tracked-and-fixed GLK DSI resume-black regression upstream; pair impossible on the 615c8ec48621 axis), SURVEY-03 prepared per the documented handoff. The one blocking gap found during verification (unmarked `rescan` alias in the phase SUMMARY) was fixed and re-verified: ledger gate `passed=4 failed=0`, full chain `CHAIN_EXIT=0`. Phase closable.
