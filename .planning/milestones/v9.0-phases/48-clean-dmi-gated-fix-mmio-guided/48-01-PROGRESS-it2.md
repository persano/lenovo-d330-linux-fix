---
plan: 48-01
phase: 48-clean-dmi-gated-fix-mmio-guided
status: iteration-2-wired
iteration: 2 of ≤5
completed: 2026-10-15
---

# 48-01-PROGRESS-it2: Iteration-2 fix patch + CI wiring

<!-- planner-discipline-allow: panel power cycle -->

## What Was Built

The iteration-2 DMI-gated fix patch
(`patches/d330_dsi_panel_power_cycle.patch`, branch commit `f1914da`):
strictly additive, in `intel_dsi_pre_enable()`, at the very TOP (before
`intel_dsi_wait_panel_power_cycle()` and the PLL work), DMI-gated to
`dmi_match(DMI_PRODUCT_NAME, "82H0")` (one static-bool helper, computed once,
same helper area as it1). The cycle replicates the working reload path's
panel teardown using the tree's own sequence executor
`intel_dsi_vbt_exec_sequence(struct intel_dsi *, enum mipi_seq)` (signature
verified in `intel_dsi_vbt.h:16`):

- `MIPI_SEQ_ASSERT_RESET` (the disable-path invocation pattern, vlv_dsi.c:926,
  mirrored exactly)
- `msleep(intel_dsi->panel_off_delay)` (the disable path's VBT delay,
  vlv_dsi.c:928)
- `MIPI_SEQ_POWER_OFF` (vlv_dsi.c:929, mirrored exactly)
- `msleep(1500)` — the reload-scale settle (mimics the unbind/bind gap; a
  power-off hold, not the banned 300 ms-after-POWER_ON variant)

The existing flow then continues unchanged: POWER_ON → panel_on_delay →
DEASSERT_RESET → INIT_OTP → DISPLAY_ON. No operational-register writes, no
post_disable changes, no PPS/DMC/power-well changes, no backlight forcing.

**Resume-window gate (why `init_wakeref`):** modeset DOES hit pre_enable
(the in-tree broxton block comments "Add MIPI IO reset programming for
modeset"), so the cycle needed a resume condition. Tree survey:
`display_core_suspended` is cleared at the START of
`intel_power_domains_resume()` (intel_display_power.c:2161) — before any
encoder hook runs, unusable; `pm_resume_via_firmware()` does not exist in
7.0.0; i915 does no `pm_runtime_*` status games during system PM (no
force_suspend/set_active anywhere), so `pm_runtime_suspended()` is flat.
The winner: `display->power.domains.init_wakeref` — set by
`intel_power_domains_init_hw()` (called from `intel_power_domains_resume()`,
which runs in resume_early: i915_driver.c:1173 →
`intel_display_power_resume_early()` → intel_display_power.c:2289) and
dropped ONLY by `intel_power_domains_enable()` at i915_driver.c:1313 — AFTER
the resume display re-commit at :1301. So it is non-NULL exactly across the
system-resume recommit (target case), plus the driver-load window (cold
boot), where on the D330 pre_enable never runs (i915 fast-boots on GOP
handover, machine-evidenced v8.0 D330MARK; and a panel power cycle before
first init would be harmless there anyway). Plain modesets and dpms cycles
run long after `intel_power_domains_enable()` → gate false. Precedent for
reading it as a window predicate: intel_display_power.c:2337 uses
`!power_domains->init_wakeref` as a boolean state test.

## Patch self-greps (device-tested file)

- banned operational offsets (0x6b000/0x6b010/0x6b044/0x6b080/0x6b088/
  0x6b094/0x160018/0x160084): **0 hits**
- `dmi_match(DMI_PRODUCT_NAME, "82H0")`: exactly **1**
- diff-body removal lines: **0** (48 insertions, 0 deletions)
- banned aliases (DEVICE_READY / ULPS / "panel power cycle" literal): **0**
- `msleep(1500)` present (patch line 93)

## Device compile proof (santiago-D330, ~/d330-kernel/linux-7.0.0)

- patch sha256: `a6deb9445bd951daac6418ad4532684549a8a522bb9d0bcb761bad7dcb77719d`
  (identical local vs device-staged copy)
- `git apply --check --verbose`: OK; `git apply`: "aplicado limpiamente";
  vlv_dsi.c md5 during test `26edc89fac057713efc3c3119b8aaff4`
- `make M=drivers/gpu/drm/i915 modules`: **exit 0** (`CC [M]
  display/vlv_dsi.o` → `LD [M] i915.o` → `MODPOST` → `LD [M] i915.ko`)
- `git apply -R`: OK; vlv_dsi.c md5 back to
  `b9338cdf49a092489b8fa932086b0844` — byte-identical to the pre-patch tree
  (same baseline it1 verified); 0 new .rej/.orig from this apply
- staged patch removed from `/home/santiago/` (verified absent)

## CI wiring (commit `65c0b01`)

In `.github/workflows/build-kernel.yml`, "Apply the display fixes and prove
they landed" step: REPLACED the it1 apply
(`d330_dsi_device_ready_fix.patch` + its 4 comment lines) with the it2 apply
(`d330_dsi_panel_power_cycle.patch` + 9-line comment, noting the it1 patch
is disproven ledger row 30 and stays in git history but is no longer applied
by CI). KEPT: the dump-node patch application + its 2 anchors, the 2
skl_universal_plane anchors (4 pre-existing anchors total), and the
DMI-gate grep anchor for `vlv_dsi.c` (it2 is also DMI-gated in vlv_dsi.c),
whose comment block was retargeted to the it2 mechanism. Workflow diff: 5
removed lines (it1 apply + comment), 10 added lines (it2 apply + comment);
anchor line itself unchanged. Branch pushed: origin
`122a75c..65c0b01`.

## Key Hashes

- Branch instrument/d330-dsi-dump: `f1914da` (patch), `65c0b01` (CI wiring);
  pushed to origin. /gsd-ship must now merge 8 commits
  (fdafc43, fb86c6a, 30f077c, b753d39, 1418a8b, 122a75c, f1914da, 65c0b01).
- It1 patch file `patches/d330_dsi_device_ready_fix.patch` remains tracked
  (history of the disproven lever) but is NOT referenced by CI anymore.

## Risks / Notes for 48-02

- Device tree is NOT pristine upstream: it still contains the phase-45
  FAILED `QUIRK_DSI_RESUME_FULL_CYCLE` delayed-work patch applied in
  `intel_display_driver.c` (plus stray `intel_pps.c.orig` / `vlv_dsi.c.orig`
  leftovers from that era, pre-dating this session). The device compile
  check therefore proves apply+build in the DEVICE's context; CI builds
  clean 7.0.14 source + dump patch + it2 patch only. Same situation it1
  compiled under; CI context matching for the new hunk at the top of
  pre_enable is the same stable upstream region it1 matched (its hunk-1
  context bytes are reused verbatim).
- The `init_wakeref` gate adds one cold-boot caveat: during the driver-load
  window the flag is held; if a machine ever ran pre_enable inside that
  window, the cycle would run at cold boot too. On THIS device pre_enable
  does not run at cold boot (GOP handover fastboot, machine-evidenced), and
  the cycle there would be a redundant-but-harmless panel re-power before
  init. Documented in the patch comment.
- Resume latency grows by ~1.5 s + VBT panel off delay (the reload-scale
  settle) — acceptable on a single-user tablet; it mimics the proven-working
  unbind/bind gap.
- CI was NOT dispatched (48-02 owns dispatch). No artifact exists yet.

## Ledger Gate

`bash scripts/test_pitfalls_ledger.sh`: passed=4 failed=0, exit 0 (run
before and after this file was added; markers: `panel power cycle`).

## Self-Check

- Patch committed (`f1914da`) sha256 `a6deb944…7719d` == device-tested
  sha256 — match.
- CI commit `65c0b01` pushed: origin `122a75c..65c0b01` — verified in push
  output.
- No deletions in either commit (`git diff --diff-filter=D HEAD~2 HEAD`
  empty).
- Device tree md5 restored post-revert (`b9338cdf…`), staged patch removed.
- Ledger gate 4/4 green after all writes.
- `## Self-Check: PASSED`
