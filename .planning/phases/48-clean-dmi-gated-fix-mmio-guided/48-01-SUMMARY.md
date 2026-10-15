---
plan: 48-01
phase: 48-clean-dmi-gated-fix-mmio-guided
status: complete
completed: 2026-10-14
duration_min: 12.5
fix_branch: instrument/d330-dsi-dump
fix_branch_commits: [1418a8b, 122a75c]
pushed_to_origin: true (30f077c..122a75c)
artifact_free: true (no CI dispatch, no artifact download; 48-02 owns dispatch)
---

# 48-01-SUMMARY: Iteration-1 fix patch + CI wiring

## What Was Built

The iteration-1 DMI-gated fix patch (`patches/d330_dsi_device_ready_fix.patch`,
branch commit `1418a8b`): strictly additive, in `intel_dsi_pre_enable()`, right
after the panel VBT power-on and before the `glk_dsi_enable_io()` cold-boot
probe, DMI-gated to `dmi_match(DMI_PRODUCT_NAME, "82H0")` (one static-bool
helper, computed once): when a DSI port is observed with retained DEVICE_READY
(the S3-resume state), clear `ULPS_STATE_MASK + DEVICE_READY` (device off) so
the cold-boot probe reports fresh like the working reload path (`cold_boot=1`,
`intel_dsi_prepare()` before `intel_dsi_device_ready()`) and the existing
plain `!(DEVICE_READY)` branch of `glk_dsi_device_ready()` re-arms it — the
whole pre_enable then matches the reload-probe ordering. Sequencing only: no
operational register values written. CI wiring (`122a75c`): the fix patch is
applied in the "Apply the display fixes and prove they landed" step and one new
grep anchor proves the DMI gate in `vlv_dsi.c`. Branch pushed to origin.

## Tasks

| # | Task | Status | Proof |
|---|------|--------|-------|
| 1 | Author iter-1 fix patch on the fix branch | DONE | commit `1418a8b` (patch sha256 `27965072…2B65F68F`, byte-identical to the device-tested file); device compile on `santiago-D330` `~/d330-kernel/linux-7.0.0`: `git apply --check` OK → `git apply` OK → `make M=drivers/gpu/drm/i915 modules` **exit 0** (`CC [M] display/vlv_dsi.o`, `i915.ko` linked, vlv_dsi.o 872,392 B) → `git apply -R` revert, tree byte-identical to pre-patch (md5 `b9338cdf…` match); patch greps: banned offsets 7/7 zero hits, `dmi_match(DMI_PRODUCT_NAME, "82H0")` exactly 1, diff-body removal lines 0 |
| 2 | Wire CI grep anchor for the DMI gate + push | DONE | commit `122a75c`: 1 added anchor line `grep -R 'dmi_match(DMI_PRODUCT_NAME, "82H0")' drivers/gpu/drm/i915/display/vlv_dsi.c` adjacent to the 4 pre-existing anchors (unchanged); branch pushed, origin fast-forward `30f077c..122a75c` |

## Ledger Gate

`bash scripts/test_pitfalls_ledger.sh` exit 0 (4/4) — see Deviations: the gate
was RED before any executor change; fixed via the gate's own sanctioned
planner-discipline-allow markers.

## Key Hashes

- Fix-branch (instrument/d330-dsi-dump) commits: `1418a8b` (fix patch), `122a75c` (CI apply + anchor). b753d39 dump-node baseline untouched and now also on origin.
- Branch HEAD on origin: `122a75c`. /gsd-ship must merge instrument/d330-dsi-dump into main (now 6 commits: fdafc43, fb86c6a, 30f077c, b753d39, 1418a8b, 122a75c).

## Deviations from Plan

<!-- planner-discipline-allow: 0x160018 -->
<!-- planner-discipline-allow: intel_dsi_post_disable -->
<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: glk_cold_boot = glk_dsi_enable_io() -->

1. **[Rule 3 - Blocking] Ledger gate red before execution started (pre-existing).**
   `test_pitfalls_ledger.sh` exited 1 at session start: pristine scan hit
   `48-01-PLAN.md:41/:47` (lever-4 alias via the banned-offset list in the
   acceptance criteria; lever-11 alias via the "no changes to
   intel_dsi_post_disable" prohibition) and `48-03-PLAN.md:41/:56` (lever-4 via
   the diff-row list; lever-20 via the iteration-ladder text). These are prose
   mentions of banned levers inside ban-verification text, not proposals; the
   gate's own remedy ("add a per-string planner-discipline-allow marker") was
   applied: markers `0x160018` + `intel_dsi_post_disable` in 48-01-PLAN.md,
   `0x160018` + `panel power cycle` in 48-03-PLAN.md (per-string, per-file, the
   same mechanism DSI_MMIO_DIFF.md already carries). Gate re-run: 4/4 green.
   Files touched: the two PLAN.md files only (uncommitted; orchestrator
   commits planning docs).
2. **[Plan gap, Rule 1] Task 2 needed one extra line beyond the named anchor.**
   The plan action says "add exactly one grep anchor line", but the anchor greps
   `$SRC` (fetched kernel source); without applying the new patch in CI the
   anchor would fail the next build. Added the 47-01-established
   `git apply -p1 …/patches/d330_dsi_device_ready_fix.patch` line + 4-line
   comment next to the anchor (workflow diff: 6 added lines, 0 removed;
   pre-existing anchors untouched). Without it, 48-02's dispatch would fail.
3. **Insertion-point choice (documented, no behavioral scope change).** The plan
   offers "top of glk_dsi_device_ready() — or equivalently in
   intel_dsi_pre_enable() immediately before intel_dsi_device_ready()". The
   clear block sits in `intel_dsi_pre_enable()` immediately BEFORE the
   `glk_cold_boot = glk_dsi_enable_io()` probe instead, because the plan's own
   requirement "with the state cleared the probe now reports fresh like
   reload" only holds there; it also yields the research §3 iteration-1
   "prepare-before-device_ready" consistency, i.e. the whole pre_enable
   matches the reload ordering, not just the device_ready branch. Existing
   `glk_dsi_device_ready()` code is untouched (it then takes its fresh-probe
   branch naturally).

## Risks / Notes for 48-02

- CI applies the fix patch to Ubuntu resolute 7.0.14 source; context matching
  was proven on the device 7.0.0 tree (stable upstream region, git apply
  context-tolerant). If CI fails at apply, that is a patch-context issue to fix
  before any iteration verdict.
- CI was NOT dispatched (plan 48-02 owns dispatch). No CI waits, no artifact.
- Device tree left byte-identical to its pre-task state; staged patch removed
  from `/home/santiago/`.

## Self-Check

- Committed patch sha256 equals the device-tested file sha256: `27965072BCD066646B0B6710374F2CBB16F5A513D4F04FCC7BAEB68E2B65F68F` — match.
- Both branch commits exist and are pushed: `30f077c..122a75c` on origin.
- No deletions in either commit (`git diff --diff-filter=D` empty).
- Ledger gate final run: `passed=4 failed=0`, exit 0.
- `## Self-Check: PASSED`
