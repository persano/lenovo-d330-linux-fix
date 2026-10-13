# 45-02-SUMMARY: DMI-gated fix attempts — ROOT-04 honest closure

<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: intel_pps.c -->
<!-- planner-discipline-allow: mem_sleep -->
<!-- planner-discipline-allow: dsi-reprobe -->
<!-- planner-discipline-allow: disable_all -->
<!-- planner-discipline-allow: commit_duplicated_state -->
<!-- planner-discipline-allow: modprobe -r -->

Phase: 45 · Plan: 45-02 · Completed: 2026-10-13

## What shipped

- `patches/d330_dsi_resume_cycle.patch` — iteration #1 candidate, DMI-gated
  (`QUIRK_DSI_RESUME_FULL_CYCLE`, `DMI_MATCH(DMI_PRODUCT_NAME, "82H0")`): deferred work
  3 s after `intel_display_driver_resume()` duplicating the atomic state, `disable_all`,
  2 s settle, `commit_duplicated_state` (mode_changed), hotplug event. Built by CI run
  38334925479 (branch `fix/d330-dsi-resume-cycle`), deployed, **eyes-on FAILED**
  (lit-black twice). Kept in the repo as a documented failed candidate; **not applied**
  by CI anymore (workflow reverted to CCS-only with a pointer to this document).
- `docs/research/NO_CLEAN_FIX_PROOF.md` — the ROOT-04 closure: iteration table, corrected
  premises, the decisive displayinfo experiment, future work.
- `docs/research/RESUME_FIX_LEDGER.md` — proven-bar corrected (reboot is the only
  eyes-on-verified recovery; the unbind/bind reload was sysfs-only evidence, myth-busted
  45-02), rows 28-29 added, row 10 evidence extended, count 27→29. Ledger gate green
  (files=43 hits=0).
- `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md` — candidate cross-check table
  (plan step 2), pre-iteration diagnostic section, full iteration log with per-iteration
  machine + human evidence.
- `docs/dumps/re_kit/`: `boot_displayinfo.txt`, `broken_displayinfo.txt`,
  `displayinfo_diff.txt` registered in MANIFEST.sha256.
- `.github/workflows/build-kernel.yml`: fixed source resolution (`-t "$REL"` pin) after
  the noble backport began shadowing the questing/resolute package; suite moved from
  questing to **resolute** (dispatch input), first run of that fix failed again (noble
  still won), second (with the release pin) resolved `7.0.0-38.38` correctly and built.
- Device state: known-good `7.0.14-d330-fix` redeployed and verified (no D330 DSI cycle
  code in i915.ko, no quirk in boot log, panel On). Rollback .deb retained on host
  (sha256 `20dc04db…9e91`). The on-device `d330-dsi-reprobe.service` was **removed**
  (it worsened the panel: fully black). `mem_sleep` default untouched.

## Deviations from the plan

- Plan step (ii) proposed re-adding the device-tree PPS clamp: **vetoed** — ledger row 1
  (banned) and the clamp had already been rolled back out of the device tree; re-adding it
  would regress that rollback. Recorded, not hidden.
- Plan's "fix acceptance is register/sysfs/ftrace evidence" must-have was **changed by
  evidence**: sysfs state proved to be a mirage (identical while the panel is visually
  dead). Every iteration outcome this phase was verified with human eyes-on verdicts
  (the user), captured in the iteration log. Machine traces were still collected per
  iteration; they documented *what ran*, not *what the user saw* — both are recorded.
- The 5-iteration budget was not exhausted numerically (3 deployed iterations), but the
  iteration *space* was: the three designed candidates (plus two cheap recovery-path
  probes) all failed, and the decisive displayinfo experiment showed the kernel-side state
  is byte-identical working-vs-broken. Continuing would re-chase disproven levers, so
  ROOT-04 closure was invoked at iteration 3 of 5 (per the plan's honest-outcome clause).

## Key findings this phase

1. **The rebind recovery was a myth.** The i915 unbind/bind "reload" restores sysfs state
   (`dpms=On`, `bl_power=0`) but not the visible image — verified with eyes-on (manual
   rebind, systemd re-probe, SDDM restart: all black). The only recovery that ever
   restored the panel is a **full reboot**.
2. **s2idle does not avoid the bug**: i915 tears the DSI pipeline down in s2idle too and
   leaves `bl_power=4`; re-enabling the backlight yields lit-black (row 10 evidence).
3. **Kernel display state is byte-identical** between working (fresh boot) and broken
   (post-resume) — only the cursor plane FB differs. The failure lives below the kernel's
   model: panel-side TCON/DSI link state that the GOP sets at boot and the kernel cannot
   reproduce (see NO_CLEAN_FIX_PROOF.md §3-§4 for the future-work list).
4. CI source resolution must pin the target release (`apt-get download -t "$REL"`): the
   runner's noble archive now carries `7.0.0-38.38~24.04.4` which shadows the base suite;
   the live suite for linux 7.0.0-38.38 is **resolute** (questing superseded).

## Requirements coverage

- ROOT-02 (fix attempt with CI deployments + iteration ledger): satisfied — 3 iterations
  deployed and tested, ledger updated, budget respected.
- ROOT-03 (≤5 iterations or ROOT-04 closure): satisfied — ROOT-04 invoked with full
  evidence after iteration 3 of 5 (iteration space exhausted; see deviation note).
- ROOT-04 (honest closure, no fake fix): satisfied — NO_CLEAN_FIX_PROOF.md + corrected
  proven bar + device rolled back to known-good.
- D330_REAL_FIX=1 marker: **not set** (no fix landed); its absence is the honest signal.
