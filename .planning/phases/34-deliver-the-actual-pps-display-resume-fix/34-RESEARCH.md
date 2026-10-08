# Phase 34: Deliver the Actual PPS / Display Resume Fix - Research

**Researched:** 2026-10-08
**Domain:** Linux PM notifier ordering, i915 PPS clamp delivery, kernel cmdline `video=` semantics, DKMS packaging honesty
**Confidence:** HIGH (kernel/dkms sources read this session; hardware-dependent items flagged)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Add optional `--kernel-src /usr/src/linux` step to `scripts/install_dkms.sh` that applies `patches/d330_display_resume_fix.patch` with `patch -p1 --dry-run` FIRST; on context mismatch against the running kernel: loud `[WARN]`, do not fail the install (roadmap-locked)
- The patch remains optional: default install stays DKMS-module + `enable_psr=0 enable_fbc=0` (Option 1); docs must say the clamp needs Option 2
- Research decides between the two roadmap options: (a) move the delay from `PM_POST_SUSPEND` to `PM_SUSPEND_PREPARE`/pre-modeset where it can affect TCON sequencing, or (b) reduce the module to an honest DMI-matched banner + `dmesg` breadcrumb. Recommended default (auto-accepted): option (a) if research shows `PM_SUSPEND_PREPARE` timing can precede panel power-on on this i915/DSI stack; otherwise option (b). The choice and its evidence live in 34-RESEARCH.md
- **delete the unit plus its enable/disable/copy pair** — current `ExecStart` only `echo`s connector status; a real DRM connector-detect + forced modeset recovery cannot be built or validated without hardware. If research finds an existing repo tool already does connector recovery, revisit in PLAN; otherwise deletion is the honest fix
- `README.md:54-67` rewritten so each Option states exactly what it does: Option 1 = `i915 enable_psr=0 enable_fbc=0` + DKMS module (DMI banner, no PPS clamp); Option 2 = adds the 600 ms clamp patch via `--kernel-src`; "will now work reliably" claims become accurate, non-guaranteeing statements
- `video=efifb:nobgrt` removed from `50-lenovo-d330-boot.cfg` (not a documented efifb option) — **[RESEARCH CONTRADICTS THIS PREMISE — see Finding 3a; recommendation: KEEP the param]**
- `CHANGES_AUDIT.md` §2.2: ADD the claimed `video=eDP-1:panel_orientation=right_side_up` / `video=DSI-1:...` params to the grub.d snippet (low risk: absent connectors are ignored by the kernel) so the shipped set matches the audit doc; if research shows the params are harmful/no-op on this stack, correct the doc instead and record why
- `patches/dkms/lenovo-d330-fix/Makefile` + `dkms.conf`: add `BUILT_MODULE_LOCATION[0]="."` and a `MAKE_MATCH[0]` guard (roadmap-locked, mechanical)

### the agent's Discretion
- Exact `[WARN]`/`[OK]` wording, README prose layout, whether the module banner prints one line or two
- Test-suite naming for the new static cases (`scripts/test_resume_loop.sh` exists per SC2 — extend or wrap as research dictates)

### Deferred Ideas (OUT OF SCOPE)
- Real DRM connector-detect + forced modeset recovery in the resume service (needs hardware validation; deletion chosen instead)
- Upstreaming the clamp as a proper quirk, i915 driver changes
- Tray applet / tablet daemon session wiring (Phase 36), installer symmetry (Phase 35)
- Changing Option 1's kernel params (`enable_psr=0 enable_fbc=0` stays as documented)
</user_constraints>

## Executive Summary

This phase has one hard technical question (where a PM delay can legally sit relative to panel power) and one hard truth question (does the advertised clamp/patch/service actually exist). Answers, all backed by source read this session:

1. **PM handler: option (b) wins.** Kernel `v6.6 kernel/power/suspend.c` shows `PM_SUSPEND_PREPARE` fires *before* `suspend_freeze_processes()` and long before `dpm_suspend_start()` — i.e. while the panel is still powered ON — and `PM_POST_SUSPEND` fires in `suspend_finish()` *after* `dpm_resume_end()` — i.e. after the panel is re-energised. The notifier event set (`include/linux/suspend.h:484-489`) has **no event between panel-off and panel-on**. A 600 ms sleep at either point adds zero TCON discharge time; at `PM_SUSPEND_PREPARE` it only delays suspend entry. The current `elapsed < 600 ms` branch is dead for every successful suspend (elapsed spans sync + freeze + full device suspend/resume; rtcwake cycles are ≥10 s) and only reachable on *failed*-freeze abort paths, where it sleeps 600 ms after a failed suspend and prints a false "Enforcing TCON discharge delay" line. Option (a) cannot deliver the clamp; the out-of-tree module cannot enforce TCON sequencing at all. **Recommendation: option (b) — honest DMI banner + breadcrumbs, clamp delivered only by the Option 2 kernel patch.**
2. **The clamp patch does not dry-run-apply to any mainline kernel tested.** Anchor symbols `intel_pps_init_delays`, `cur_delay.panel_power_cycle_delay`, `QUIRK_NO_PCH_PWM_ENABLE`, `lenovo_ideapad_d330_10igm_81md` are absent from torvalds/linux at v5.4, v5.10, v5.15, v6.1, v6.6, v6.7–v6.17 and master (probed via raw.githubusercontent.com). The roadmap's `patch -p1 --dry-run` + warn-don't-fail gate is therefore not a formality — it is the expected common path. Docs must stop implying Option 2 "just works".
3. **`video=efifb:nobgrt` IS a real efifb option** — `efifb_setup()` parses it (`v6.6 drivers/video/fbdev/efifb.c:305-306`, present in v5.15 too). It is merely absent from the `efifb.rst` "Accepted options" table. Removing it regresses exactly what the cfg comment claims (distorted BGRT logo). **Recommendation: KEEP it; correct the roadmap/CONTEXT premise instead.**
4. **The resume service is deletable with low blast radius**: 10 textual references in 5 files (installer ×4, debian postinst ×1, rpm spec ×1, CHANGES_AUDIT ×3, patches/README ×1) plus the unit file itself = **6 files**; **zero test-suite references**. One repo tool (`tools/d330-refresh-screen.sh`) does real recovery but only inside a graphical session, and its sysfs `dpms` fallback is dead (`DEVICE_ATTR_RO(dpms)` since ≤5.15) — not a drop-in service replacement.
5. **SC2 as written is currently impossible**: `scripts/test_resume_loop.sh` runs `set -euo pipefail` (line 15) and then `((passed++))` (line 113) / `((failed++))` (line 83) — with the counter at 0 the arithmetic command returns status 1 and errexit kills the script after the first cycle (verified in bash: `set -e; p=0; ((p++))` exits 1). The phase must fix this arithmetic before "5 cycles" can ever pass.

**Primary recommendation:** implement option (b) + service deletion + honest docs, ship the `--kernel-src` dry-run gate as the *detector* of Option 2 feasibility (loud `[WARN]` expected on stock kernels), KEEP `efifb:nobgrt`, ADD the two `panel_orientation` params (connector-absent → silently ignored), fix the resume-loop arithmetic, and gate SC1/SC2 to hardware UAT with static truth-checks in CI.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PPS 600 ms clamp (real discharge wait) | Kernel / i915 driver (Option 2 patch) | — | Only `panel_power_cycle_delay` wait inside i915 runs between panel-off and panel-on; no userspace/PM-notifier point exists (suspend.c ordering, Finding 1) |
| DMI match + `dmesg` breadcrumb (SC1) | DKMS module (kernel) | — | `register_pm_notifier` module prints at `module_init` on `dmi_first_match` (lenovo_d330_fix.c:131-143) |
| Orientation quirk | Kernel (`drm_panel_orientation_quirks.c`, upstream ≥6.6 covers 82H0) + cmdline `video=` (drm core) | — | `drm_connector_get_cmdline_mode()` sets the connector property at init (drm_connector.c:161-180) |
| Boot cmdline delivery | grub.d snippet + installer deploy (`install_dkms.sh:186-194`) | update-grub (Phase 35 owns mkconfig symmetry) | grub.d drop-in is the deployed artifact; regen belongs to Phase 35 per roadmap |
| "Resume recovery" | **None this phase** (deleted); manual session tool `d330-refresh-screen` | Phase 36 session wiring | System service has no DISPLAY/WAYLAND; sysfs `dpms` RO |
| Truth in docs | README / CHANGES_AUDIT | — | Audit C4/N3/M17 |

## Findings (per research question)

### Q1 — PM ordering on i915/MIPI-DSI, 5.15–6.x: where can a notifier run? [HIGH]

All quotes from `kernel/power/suspend.c` (torvalds/linux **v6.6**, downloaded this session; 5.15–6.12 checked for the same structure — event set identical):

- `PM_SUSPEND_PREPARE` fires **before processes are frozen, before any device is touched**:
  - `:360: error = pm_notifier_call_chain_robust(PM_SUSPEND_PREPARE, PM_POST_SUSPEND);`
  - `:365: error = suspend_freeze_processes();` (after the notifiers)
  - `enter_state()` calls `suspend_prepare(state)` at `:582` **before** `suspend_devices_and_enter(state)` at `:592`.
  - Devices (incl. i915 → panel power-down) only start at `:501: error = dpm_suspend_start(PMSG_SUSPEND);`.
- Panel re-energises during device resume, `:516: dpm_resume_end(PMSG_RESUME);`, still *inside* `suspend_devices_and_enter()`.
- `PM_POST_SUSPEND` fires afterwards in `suspend_finish()` (`:538`, `:541: pm_notifier_call_chain(PM_POST_SUSPEND);`) — **after** the panel is already back on. It also fires on the failure path at `:372` (failed freeze) and via `pm_notifier_call_chain_robust` unwinding.
- The complete notifier event set (`v6.6 include/linux/suspend.h:484-489`, verbatim):
  ```
  #define PM_HIBERNATION_PREPARE	0x0001 /* Going to hibernate */
  #define PM_POST_HIBERNATION	0x0002 /* Hibernation finished */
  #define PM_SUSPEND_PREPARE	0x0003 /* Going to suspend the system */
  #define PM_POST_SUSPEND		0x0004 /* Suspend finished */
  #define PM_RESTORE_PREPARE	0x0005 /* Going to restore a saved image */
  #define PM_POST_RESTORE		0x0006 /* Restore failed */
  ```
  **There is no resume-side "prepare" event.** No `register_pm_notifier` callback can execute between panel-off (`dpm_suspend_start`) and panel-on (`dpm_resume_end`).

**Answers:**
- *Sleep before panel power-on on resume (PM_SUSPEND_PREPARE)?* PREPARE does technically run before the resume-time power-on — but it runs while the panel is **still on**; the TCON discharge window (`t11_t12`) starts at power-down during `dpm_suspend_start`. Sleeping 600 ms at PREPARE contributes **0 ms of off-time**; it only adds 600 ms of suspend-entry latency (and it runs before the freezer, with the module's `priority = 100` notifier first in line — `lenovo_d330_fix.c:146`).
- *Can a 600 ms delay in suspend-prepare affect TCON power-cycle sequencing?* **No** — not via the PM notifier mechanism. Pre-modeset timing lives inside the i915 driver resume path, unreachable out-of-tree.
- *Is `PM_POST_SUSPEND` + `elapsed < 600 ms` provably dead?* **Dead for its intended purpose, not provably unreachable.** `elapsed` spans `ksys_sync_helper()` (`suspend.c:576`) + freezing + full device suspend + actual sleep + full device resume; any real rtcwake cycle (repo default 10 s, `test_resume_loop.sh:22`) makes it ≥ 10 s. The branch *is* reachable when `PM_POST_SUSPEND` fires from the **failure** paths (`:372`, robust unwind) within milliseconds of PREPARE — there the module then `msleep(600)` after a *failed* suspend and prints `"Enforcing TCON discharge delay: holding %lld ms (target %d ms)"` (`lenovo_d330_fix.c:110-112`) — a false claim. [MEDIUM: abort-path timing not measured on hardware]

The real enforcement point exists only inside i915: `intel_pps.c` waits `panel_power_cycle_delay - panel_power_off_duration` before re-powering (v5.15 `intel_pps.c:517-519`), and `pps_init_delays()` computes the value the patch wants to clamp. That is what the Option 2 patch targets.

### Q2 — The clamp patch itself: what it changes, where it applies, detection mechanics [HIGH]

**What it changes** (`patches/d330_display_resume_fix.patch`, read in full): 4 files, 61 insertions (patch:29-33):
- `drivers/gpu/drm/drm_panel_orientation_quirks.c` — two new data structs (800x1280, 1200x1920 `DRM_MODE_PANEL_ORIENTATION_RIGHT_UP`) + two DMI entries for D330-10IGL / `82H0` (patch:43-76)
- `drivers/gpu/drm/i915/display/intel_pps.c` — clamp `panel_power_cycle_delay` to `6000` (600 ms in 100 µs units) when quirk set (patch:87-97), inserted inside `intel_pps_init_delays`
- `drivers/gpu/drm/i915/display/intel_quirks.c` — new `quirk_lenovo_d330_pps()` + DMI quirk entry (patch:110-142)
- `drivers/gpu/drm/i915/display/intel_quirks.h` — `QUIRK_INCREASE_PPS_CYCLE_DELAY` enum member (patch:153)

**Does the context stay valid on any kernel? NO — probed this session against torvalds/linux raw sources:**

| Anchor (patch context) | v5.4 | v5.15 | v6.1 | v6.6 | v6.7–v6.17 | master |
|---|---|---|---|---|---|---|
| `intel_pps_init_delays` (patch:83) — real name is `pps_init_delays` / `pps_init_delays_bios` | n/a | absent | absent | absent | absent | absent |
| `cur_delay.panel_power_cycle_delay` (patch:85) | absent | absent | absent | absent | absent | absent |
| `QUIRK_NO_PCH_PWM_ENABLE` (patch:151) | absent | absent | absent | absent | absent | absent |
| `lenovo_ideapad_d330_10igm_81md` + `LNVNB161216` (patch:61,59) | absent | absent | absent | absent | absent | absent |
| `struct intel_display *display` API style (patch:110) | — | no | no | no | — | yes (6.12+) |

Also: `intel_quirks.c` API style in the patch (`struct intel_display *display`) only exists from ~6.9 on (`v6.12 intel_quirks.c` uses it; `v6.6` still uses `struct drm_i915_private *i915`), while its `intel_quirks.h` enum context (`QUIRK_NO_PCH_PWM_ENABLE`) matches **no** mainline tag at all. **The patch is internally inconsistent with mainline — `patch -p1 --dry-run` will report FAILED hunks on essentially every stock kernel.** The sibling `patches/chromeos/d330_chromeos_*.patch` and `patches/android/d330_android_x86_*.patch` share the same context lines (repo grep) → same risk (out of phase scope, flag only).

**Implication:** warn-don't-fail is the *primary* path, not the edge case. Also note: applying the patch to a source tree does **nothing to the running kernel** — it requires kernel rebuild + install + reboot; `/lib/modules/$(uname -r)/build` is headers only and must not be silently "patched" as if that delivered the clamp.

**Gate mechanics:** `patch -p1 --dry-run` is the right gate; harden it: `patch -p1 --dry-run --forward --batch -d "$KERNEL_SRC" < "$REPO/patches/d330_display_resume_fix.patch"` (exit 0 = all hunks fit; `--forward --batch` turns "already applied" into a clean skip instead of an interactive prompt). In `--dry-run` installer mode, run the dry-run probe anyway (it is non-destructive) and print `[DRY-RUN] patch would apply` / `would NOT apply`. Detection: running kernel = `uname -r` (already used at `install_dkms.sh:58`), headers probe already exists at `:59-62`; `--kernel-src` is a new value-taking arg (`--kernel-src) KERNEL_SRC="$2"; shift 2` in the `while` at `:656-664`) and the step goes early in `do_install()` (after `check_prerequisites`, before DKMS staging at `:72-96`), inside the existing `if [ "$DRY_RUN" = false ]` pattern, with an `[INFO] clamp not applied (no --kernel-src)` line when absent. Sanity-check `$KERNEL_SRC` contains `drivers/gpu/drm/i915/display/intel_pps.c` before attempting. **Do not touch the phase-33 resume ladder (`install_dkms.sh:300-445`).**

### Q3 — `video=` parameters: efifb:nobgrt, panel_orientation syntax, absent connectors, DSI [HIGH]

**3a. `efifb:nobgrt` is REAL (CONTEXT decision premise is wrong):**
- `v6.6 drivers/video/fbdev/efifb.c:305-306` (verbatim): `else if (!strcmp(this_opt, "nobgrt"))` / `use_bgrt = false;` inside `efifb_setup(char *options)` — the callback that consumes `video=efifb:<opts>` (same mechanism the official `efifb.rst` documents with `video=efifb:macbook`, `video=efifb:nowc`).
- Present at `v5.15 efifb.c:287` too → works across the whole 5.15–6.x target range. [VERIFIED: raw v5.15/v6.6 efifb.c]
- It *is* absent from the `efifb.rst` "Accepted options" table (only `nowc` listed) — so "undocumented in the rst" is true; "not a real option" is false. `use_bgrt=false` skips drawing the BGRT bitmap, i.e. exactly what `50-lenovo-d330-boot.cfg:5` comments claim ("Disable EFI BGRT boot logo distortion"). **Removing it re-enables distorted-logo drawing. Recommendation: keep the param; correct the roadmap/CONTEXT note instead.**

**3b. `video=eDP-1:panel_orientation=right_side_up` / `video=DSI-1:...` are valid drm fb-helper syntax:**
- `v6.6 Documentation/fb/modedb.rst:78-80` (verbatim): `- panel_orientation, one of "normal", "upside_down", "left_side_up", or "right_side_up". For KMS drivers only, this sets the "panel orientation" property on the kms connector as hint for kms users.`
- Value parser `v6.6 drivers/gpu/drm/drm_modes.c:2112-2132`: `right_side_up` → `DRM_MODE_PANEL_ORIENTATION_RIGHT_UP` (`:2131-2132`).
- Documented in modedb since **at least v5.15** (`v5.15 Documentation/fb/modedb.rst:68` contains `panel_orientation`) → valid across the whole target range. [VERIFIED]

**3c. Absent connector = ignored:** `v6.6 drivers/gpu/drm/drm_connector.c:156-165`: `drm_connector_get_cmdline_mode()` does `option = video_get_options(connector->name); if (!option) return;` — options are looked up **per existing connector**; a `video=DSI-1:...` string on a machine with no `DSI-1` is simply never claimed. When claimed: `:176-180` logs `DRM_INFO("cmdline forces connector %s panel_orientation to %d\n", ...)` and calls `drm_connector_set_panel_orientation()` — which creates/attaches the property on first use (`:2556-2590`). So on the D330 the shipped pair is **not a no-op**: whichever of eDP-1/DSI-1 exists gets the property, and **`dmesg | grep "cmdline forces connector"`** is the on-hardware verification hook. Works for DSI as well as eDP — it is drm-core generic, not i915-specific. [MEDIUM: whether adding the property changes GNOME/compositor rotation on this device needs hardware check]

**3d. i915+DSI caveat:** if the D330 panel is truly MIPI-DSI (CONTEXT.md hardware table says "MIPI-DSI / eDP", ambiguous), the patch's `intel_pps.c` clamp (Intel **DisplayPort** PPS) would not touch the DSI panel's power sequencing at all — unknown until hardware `dmesg`/EDID confirms the connector. Flagged in Open Questions.

### Q4 — Resume service: contents, existing recovery tooling, deletion impact [HIGH]

- **`ExecStart` echoes only** — `patches/dkms/etc/systemd/system/lenovo-d330-resume.service:7` (verbatim): `ExecStart=/bin/sh -c 'if [ -d /sys/class/drm/card0-eDP-1 ]; then echo "Resumed - verifying eDP connector status: $(cat /sys/class/drm/card0-eDP-1/status 2>/dev/null || true)"; fi'` — no state change, output goes to the journal only.
- **Existing repo recovery tool: YES, but not service-grade.** `tools/d330-refresh-screen.sh` (deployed as `/usr/local/bin/d330-refresh-screen`, `install_dkms.sh:237-239`) does: (1) `wlr-randr --off/--on` cycle when `WAYLAND_DISPLAY` set, (2) `xrandr --output ... --off` + `--auto --rotate right` when `DISPLAY` set, (3) `echo "Off"/"On" > /sys/class/drm/card*-*/dpms` fallback. The sysfs fallback is **dead**: `v5.15 drm_sysfs.c:240` and `v6.6 drm_sysfs.c:326` are both `static DEVICE_ATTR_RO(dpms);` — read-only, writes fail (script swallows with `|| true`). A system service has no session env, so paths 1-2 can't work there either. → **Deletion stands**; README may point users at `d330-refresh-screen` (manual, from a session) as the honest recovery story.
- **Deletion impact — 10 references in 5 files + the unit file itself = 6 files:**

| File | Lines | Change |
|---|---|---|
| `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` | whole file | delete |
| `scripts/install_dkms.sh` | 268 (cp), 289 (enable), 582 (disable), 611 (rm) | remove all 4 |
| `packaging/debian/postinst` | 13 (`systemctl enable lenovo-d330-resume.service`) | remove |
| `packaging/rpm/lenovo-d330-fix.spec` | 46 (same enable in `%post`) | remove (`%install` glob `patches/*/etc/systemd/system/*.service` and `%files /etc/systemd/system/*` unaffected) |
| `CHANGES_AUDIT.md` | 38 ("Restores display output post-sleep"), 41 (auditor verify point), 383 (manifest row) | correct/remove |
| `patches/README.md` | 24 ("Post-wake connector validation service") | remove row |

- **Test suites: ZERO references** to `lenovo-d330-resume.service` (repo-wide grep; `test_hibernate_guards.sh`/`test_storage_cellular.sh` anchor other installer strings — `INSTALLER` assertions at `test_hibernate_guards.sh:234,391-433` are swapfile/mkconfig anchors, unaffected). `README.md` and `docs/` also have no references (only `.planning/phases/33-*` pattern docs — historical, do not edit).
- **Cross-phase side effect:** the enable block `install_dkms.sh:288-297` currently enables **9 units**; after deletion **8**. Phase 35's SC2 wording "all 9 units" needs recounting (Phase 35 also plans to add `camera-loopback` → back to 9). Flag in PLAN.

### Q5 — DKMS correctness: BUILT_MODULE_LOCATION / MAKE_MATCH [HIGH for syntax, MEDIUM for guard semantics]

Current `patches/dkms/lenovo-d330-fix/dkms.conf` (7 lines): `MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build modules"`, `BUILT_MODULE_NAME[0]="lenovo_d330_fix"`, `DEST_MODULE_LOCATION[0]="/updates/dkms"`, `AUTOINSTALL="yes"` — no `BUILT_MODULE_LOCATION`, no `MAKE_MATCH`.

From `dell/dkms` `dkms.8.in` (main, read this session):
- `BUILT_MODULE_LOCATION[#]=` — "This directive tells DKMS where to find your built module after it has been built. This pathname should be given relative to the root directory of your source files (where your `dkms.conf` file can be found). **If unset, DKMS expects to find your `BUILT_MODULE_NAME[#]` in the root directory of your source files.**"
  → With the current Makefile (`$(MAKE) -C $(KDIR) M=$(PWD) modules`) the `.ko` lands at the build-dir root, which *is* the default — so nothing is broken **today**; `BUILT_MODULE_LOCATION[0]="."` is default-equal explicitness (roadmap-locked, safe, protects if the Makefile ever moves output). Without it, a future Makefile change silently breaks `dkms install` (module-not-found), which is the real hazard it guards.
- `MAKE_MATCH[#]=` — **real directive** (not a hallucination): "Other entries in the MAKE array will only be used if their corresponding entry in `MAKE_MATCH[#]` matches, as a regular expression (using grep -E), the kernel that the module is being built for... `MAKE_MATCH[0]` is optional and if it is populated, it will be used to determine if MAKE[0] should be used to build the module for that kernel... **If no `MAKE` directive matches, DKMS will attempt to use a generic make command.**"
  → ⚠️ guard semantics (MEDIUM): a too-narrow `MAKE_MATCH[0]` does not cleanly *refuse* the build — dkms falls back to a generic make. If the intent is "don't attempt builds on unsupported kernels", the canonical tool is `BUILD_EXCLUSIVE_KERNEL[0]="^5\.15\|^6\."` (dkms.8.in:803-857 documents `BUILD_EXCLUSIVE_KERNEL[0]="^5\..*"` examples) which refuses with a clear message. **Plan recommendation:** add roadmap-locked `MAKE_MATCH[0]` with a permissive supported-range regex + a comment, and consider `BUILD_EXCLUSIVE_KERNEL[0]` as the effective guard (small, mechanical; planner decides, roadmap says "guard").

### Q6 — SC2 reality: `scripts/test_resume_loop.sh` [HIGH]

- **What it measures:** per cycle — reads `/sys/class/drm/card0-eDP-1/status` pre/post, runs `rtcwake -m mem -s $SLEEP_SECS` (default 10 s), waits `WAKE_SECS`, then greps post-wake `dmesg` for `pipe .* underrun|gpu hang|drm:.*error|i915.*timed out` (FAIL) and for `lenovo_d330_fix|Enforcing TCON` (informational only). PASS criterion = no i915 error lines (`:99-114`). Summary + exit 1 if any cycle failed (`:117-126`). Defaults `CYCLES=5` (`:21`).
- **Can it run off-hardware? NO.** Requires root + real S3/s2idle (`:49-52`), a writable `/sys/power/state`, and a DRM connector. This machine is WSL2: `/sys/power/state` not writable, no `/sys/class/drm`, no `dkms`, no headers (see Environment Availability) → every cycle would fail.
- **BLOCKER BUG (must fix for SC2):** `set -euo pipefail` (`:15`) + `((failed++))` (`:83`) and `((passed++))` (`:113`). When the counter is 0 the post-increment arithmetic expression evaluates to 0 → command status 1 → errexit terminates the script **after the first cycle, with no summary**. Verified this session: `bash -c 'set -e; p=0; ((p++)); echo alive'` → exit 1, `alive` not printed. So today the script can never report "5 cycles" — first PASS *and* first FAIL both kill it. Fix: `passed=$((passed + 1))` / `failed=$((failed + 1))` (or pre-increment + `|| true`).
- **How to split SC2:** machine-checkable now (static): defaults `CYCLES=5`, `--cycles` flag exists, arithmetic fixed, `dmesg` error patterns present; actual `--cycles 5 --sleep 10` green run = **hardware UAT, deferred-to-UAT** exactly like Phase 33 (`33-UAT.md:12` pattern). The static cases live in a new guard suite (name at discretion, e.g. `scripts/test_display_resume_guards.sh`), following the `test_hibernate_guards.sh` skeleton (`expect_file_out` etc., `:143`).

### Q7 — SC1: does the module already print a catchable banner? [HIGH]

Yes, at module init — `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c`:
- `:47-48` (verbatim): `#define d330_info(fmt, ...) \` / `	pr_info("[" DRV_NAME "] " fmt, ##__VA_ARGS__)` with `DRV_NAME "lenovo_d330_fix"` (`:32`).
- `:137-138` (verbatim): `if (matched)` / `		d330_info("Matched platform: %s\n", matched->ident);` — prints only on `dmi_first_match()` success (`:131`), plus `:142` `"Initializing Display Resume Fix (Enforced PPS Cycle Delay: %d ms)"` and `:153` `"Driver loaded successfully (v%s)."`.

Exact dmesg line shape (pr_info prepends the module name): `lenovo_d330_fix: [lenovo_d330_fix] Matched platform: Lenovo IdeaPad D330-10IGL` — `dmesg | grep lenovo_d330_fix` (README:89) catches it. Load path: installer `modprobe -v lenovo_d330_fix` (`install_dkms.sh:495`) + `MODULE_DEVICE_TABLE(dmi, ...)` (`:83`) for boot autoload. DMI strings: `DMI_PRODUCT_VERSION "Lenovo ideapad D330-10IGL"` or `DMI_PRODUCT_NAME "82H0"` (`:59-82`) — **hardware-dependent**, but two match chances. SC1 works under option (b) unchanged (banner is the deliverable).

### Q8 — CHANGES_AUDIT §2.2 claims vs what ships [HIGH]

**Claim side:**
- `CHANGES_AUDIT.md:46` (verbatim): "1. Kernel cmdline `video=eDP-1:panel_orientation=right_side_up` / `fbcon=rotate:1`."
- `CHANGES_AUDIT.md:50` (verbatim): "`patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg`: Injects `fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up`."
- `CHANGES_AUDIT.md:51` (matrix claim): "`ACCEL_MOUNT_MATRIX` for BOSC0200 sensor (`0, 1, 0; 1, 0, 0; 0, 0, -1`)"
- `CHANGES_AUDIT.md:53` (verification point): "DMI string globbing: `sensor:modalias:acpi:BOSC0200*:dmi:*:svnLENOVO:pn81H3*:*` and `82H0*`. Must match both Type 81H3 and Type 82H0 boards."

**Ship side:**
- `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg:6` (verbatim, the whole cmdline line): `GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} fbcon=rotate:1 video=efifb:nobgrt i915.enable_psr=0 i915.enable_fbc=0"` — **no `panel_orientation` params** (roadmap says file line ":7"; actual is **line 6**). Extra shipped items the audit doesn't claim: `video=efifb:nobgrt`, `i915.enable_psr=0`, `i915.enable_fbc=0`.
- `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb:8,12,16` (verbatim): ` ACCEL_MOUNT_MATRIX=0, 1, 0; -1, 0, 0; 0, 0, 1` — **differs from the audit's claimed matrix** (line 51). (README:40 quotes the shipped values correctly.)
- hwdb match patterns shipped: `:7` `...svnLENOVO:*:pvrLenovoideapadD330-10IGL:*`, `:11` `...svnLENOVO:pn82H0:*`, `:15` `...pvrLenovoideapadD330-10IGM:*` — there is **no `pn81H3*` glob** (81H3 boards are caught via the `pvr...D330-10IGM` pattern); audit line 53 describes something that doesn't exist.
- Resume-service claims adjacent to §2.2 (deletion side): `CHANGES_AUDIT.md:34` ("a systemd resume hook that forces TCON discharge sequencing"), `:36` ("Kernel module ... and `dkms.conf` to clamp PPS delay"), `:38` ("Restores display output post-sleep"), `:41` (verify-point), `:383` (manifest row) — all become false advertising once C4 lands; §2.1's `enable_fbc=1`/`fastboot=1` contradiction (actual: `options i915 enable_psr=0 enable_fbc=0`, `lenovo-d330-i915.conf:6-7`) is assigned to the later M17 batch (ROADMAP:348), not this phase.

**Truth-fix direction for §2.2:** ADD the two `video=` params (research says valid + connector-absent-safe + dmesg-verifiable) — matches CONTEXT's preferred option; ALSO correct line 51 (matrix) and line 53 (glob) to the shipped values, and fix the three resume.service rows when the unit is deleted.

## Risks / Unknowns

| # | Risk | Severity | Needs hardware? | Mitigation |
|---|------|----------|-----------------|------------|
| R1 | Patch applies to **no** mainline kernel → Option 2 never delivers the clamp on stock kernels | HIGH | No (proven) | Docs state "context must match your tree; expect `[WARN]` on stock kernels; adapt hunks manually"; keep dry-run gate |
| R2 | Panel may be **DSI**, making the `intel_pps.c` (eDP/DP) clamp irrelevant even if applied | HIGH | Yes (`dmesg \| grep -E "DSI-1\|eDP-1"`, EDID) | Ship both `video=` params; on UAT confirm connector; if DSI-only, docs must say the DP-PPS quirk is inert |
| R3 | `efifb:nobgrt` removal (locked decision) would regress the BGRT-distortion fix the file comment promises | MEDIUM | No | Research recommends KEEP + correct premise; if operator insists removal, drop the cfg comment line 5 too |
| R4 | Adding `panel_orientation` property may trigger compositor auto-rotation differently than today | MEDIUM | Yes (GNOME session after install) | Verify on hardware during UAT; fallback = correct §2.2 doc instead of adding params |
| R5 | `test_resume_loop.sh` arithmetic bug → SC2 can never pass until fixed | HIGH | No | Fix `((x++))` → `$((x+1))` in Phase 34; add static guard case |
| R6 | Deleting resume.service shifts enabled-unit census 9 → 8, colliding with Phase 35 SC2 wording ("9 units") | MEDIUM | No | Note in PLAN; Phase 35 recounts |
| R7 | `MAKE_MATCH[0]` too narrow → dkms generic-make fallback instead of clean refusal (dkms.8.in paraphrase, MEDIUM) | LOW | No | Permissive regex + comment; use `BUILD_EXCLUSIVE_KERNEL` if a hard guard is wanted |
| R8 | `elapsed < 600 ms` branch can still fire on failed-suspend paths, printing a false "Enforcing TCON" line today | MEDIUM | No | Option (b) removes the branch entirely |
| R9 | DMI strings may differ on actual unit (`DMI_PRODUCT_VERSION` vs `82H0`) → SC1 banner missing | LOW | Yes | Two-match table already; UAT greps `dmesg` |

**What needs hardware to answer:** SC1 banner, SC2 5 cycles, R2 connector identity, R4 rotation behavior, actual suspend wall-time, whether the panel actually misbehaves without the clamp (validates the whole t11_t12 premise).

## Recommended Implementation Approach

### 1. PM handler → **option (b): honest DMI banner + breadcrumb** (evidence: Finding Q1)
- Keep: DMI table, `Matched platform` banner (SC1), `register_pm_notifier`, debug breadcrumbs (`System preparing for sleep...`, `System waking up. Sleep duration: %lld ms`).
- Remove: the `elapsed_ms < power_cycle_delay_ms` → `msleep()` branch (`lenovo_d330_fix.c:103-117`) and the `power_cycle_delay_ms` "Enforced PPS" wording at `:142` — it enforces nothing. Rewrite to a breadcrumb like `"suspend prepare"` / `"resume complete after %lld ms"` + one module-doc line: *timing enforcement lives in the Option 2 kernel patch; this module only confirms DMI match*.
- Why not (a): `PM_SUSPEND_PREPARE` runs while the panel is still powered (suspend.c:360 vs :501) → 0 ms discharge contribution; no resume-side notifier exists (suspend.h:484-489); `PM_POST_SUSPEND` runs after `dpm_resume_end` (suspend.c:538-541 vs :516). This satisfies the CONTEXT decision rule's "otherwise (b)" branch.

### 2. Resume service → **delete unit + all 6-file references** (Finding Q4 table)
No repo tool works in a system-service context (session-only paths; `dpms` RO since ≤5.15), so "implement real recovery" is impossible without hardware — CONTEXT already locks deletion. Point README users at `d330-refresh-screen` (manual, from a session) instead. Reminder: Phase 35 unit-count note (R6).

### 3. Docs strategy
- `README.md:54-67`: Option 1 = `i915 enable_psr=0 enable_fbc=0` + DKMS module = DMI banner only, **no PPS clamp**; Option 2 = `--kernel-src` patch = the clamp, with the honest caveat from R1 + "requires kernel rebuild/reboot"; replace `:67` `"Suspend and resume will now work reliably."` with a non-guaranteeing statement; keep `:83`/`:89` verify commands (both valid).
- `CHANGES_AUDIT.md`: §2.2 — ADD `video=eDP-1:panel_orientation=right_side_up` and `video=DSI-1:panel_orientation=right_side_up` to the cfg (Finding 3b: valid, absent-connector-safe, `dmesg | grep "cmdline forces connector"` proves it); correct `:51` matrix → `0, 1, 0; -1, 0, 0; 0, 0, 1`; correct `:53` glob → shipped patterns; fix `:34/:36/:38/:41/:383` resume-service + clamp claims.
- `50-lenovo-d330-boot.cfg`: **KEEP `video=efifb:nobgrt`** (Finding 3a, contradicts locked premise — planner must surface this to the operator); append the two `video=*:panel_orientation=right_side_up` tokens to line 6.
- `docs/DISTRO_INSTALL_GUIDE.md:26` still says `git apply ...` which will hard-fail — out of the locked scope, but PLAN should consider a one-line caveat (planner's call).

### 4. `--kernel-src` step (locked shape, concrete mechanics in Finding Q2)
`usage()` line + `--kernel-src)` arg case + early-in-`do_install` block: `uname -r` context, existence + `intel_pps.c` sanity check, `patch -p1 --dry-run --forward --batch -d "$KERNEL_SRC"` gate, apply only on exit 0, loud `[WARN]` (do not `exit`) on mismatch, explicit "running kernel unaffected until rebuild" message, `[DRY-RUN]` probe mode. Never touch `install_dkms.sh:300-445`.

### 5. Build system (mechanical)
`dkms.conf`: add `BUILT_MODULE_LOCATION[0]="."` and `MAKE_MATCH[0]` with permissive supported-range regex + comment (and optionally `BUILD_EXCLUSIVE_KERNEL[0]` — see Q5, planner's call). Makefile unchanged (KVERSION/KDIR already `uname -r` based, `Makefile:3-4`).

### 6. Tests (validation split)
- Fix `test_resume_loop.sh:83,113` arithmetic.
- New static guard suite (discretion name), following `test_hibernate_guards.sh` skeleton: resume.service absence + zero refs (installer/postinst/spec/audit/README), cfg content tokens (`fbcon=rotate:1` present, `panel_orientation` per decision, `nobgrt` per decision), README forbidden/required phrases, installer `--kernel-src` + `patch -p1 --dry-run` + `log_warn` presence, C module: banner string present AND dead `msleep` branch absent, `dkms.conf` new directives, `test_resume_loop.sh` fixed arithmetic + `CYCLES=5`.
- Optional `--kernel-src` fixture: tiny fake tree (files containing the patch's context lines → dry-run OK; mismatched file → WARN path) since no real kernel source exists here.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Applying kernel patches conditionally | custom context matcher | `patch -p1 --dry-run --forward --batch` | handles offsets, fuzz, already-applied, exit codes |
| DKMS install gating | ad-hoc make wrappers | `dkms.conf` `MAKE_MATCH`/`BUILD_EXCLUSIVE_KERNEL` | dkms semantics already cover it (dkms.8.in) |
| Resume recovery in a system service | shell + sysfs `dpms` writes | none this phase (deleted); session tool Phase 36 | `dpms` is read-only since ≤5.15 (drm_sysfs.c:240) |
| Panel discharge timing out-of-tree | PM notifier sleeps | Option 2 in-driver PPS clamp | no notifier point between panel-off/on (Finding Q1) |

## Runtime State Inventory

Rename/refactor/migration? **Partial (service deletion) — inventory done:**

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore holds the unit name | — |
| Live service config | Deployed `/etc/systemd/system/lenovo-d330-resume.service` + its `suspend.target` symlink on already-installed machines | Uninstall path already `systemctl disable --now` + `rm -f` (`install_dkms.sh:582,611`) — keep those two lines until Phase 35's install/uninstall inverse is verified? **No: deletion decision removes all 4 sites incl. disable/rm; already-installed machines keep a stale unit until manual cleanup → note in README/CHANGES_AUDIT ("re-run installer's uninstall before upgrading" or one-line manual `rm`)** |
| OS-registered state | systemd unit symlink (enablement) — covered above | code edit + doc note |
| Secrets/env vars | None | — |
| Build artifacts | Old `/usr/src/lenovo-d330-fix-1.0.0` may carry previous dkms.conf — re-staged every install (`install_dkms.sh:78-80`) | none (install re-copies) |

## Common Pitfalls

1. **"Patch step = delivery":** applying to a source tree doesn't change the running kernel. Pitfall: docs/user assume Option 2 done after install. Avoid: explicit rebuild/reboot wording + installer output.
2. **`((var++))` under `set -e`:** kills scripts when var=0 (SC2 blocker). Avoid: `var=$((var + 1))`.
3. **Assuming `video=efifb:nobgrt` is bogus because it's missing from `efifb.rst`:** it's parsed in `efifb_setup`. Avoid: trust code over doc-table absence; verify with `rg nobgrt` on efifb.c.
4. **Sleeping in PM notifiers expecting to time-gate resume:** PREPARE = panel on; POST = panel on; no event in between. Avoid: see Finding Q1.
5. **Breaking the phase-33 resume ladder / 21+26 green gates:** `install_dkms.sh:300-445` and both guard suites must stay untouched/green.
6. **Roadmap line-number drift:** cfg param is at line 6 (not :7); resume ladder at :300-445 (not only :404-444).

## Validation Architecture

`workflow.nyquist_validation: true` (`.planning/config.json`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash guard suites (no pytest/jest in repo) |
| Config file | none — pattern source `scripts/test_hibernate_guards.sh` |
| Quick run | `bash scripts/test_hibernate_guards.sh` (expect `passed=21 failed=0`, `33-UAT.md:12`) |
| Full suite | `bash scripts/test_hibernate_guards.sh && bash scripts/test_storage_cellular.sh --dry-run` (rc=0, 26 cases) + new Phase 34 static suite |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SC1 | `dmesg \| grep lenovo_d330_fix` DMI match | static now + hardware UAT | static: guard case greps `Matched platform` in `lenovo_d330_fix.c`; UAT: `dmesg \| grep lenovo_d330_fix` on tablet | ❌ new suite Wave 0 |
| SC2 | `test_resume_loop.sh` passes 5 cycles | static now + hardware UAT | static: arithmetic-fixed + `CYCLES=5` greps; UAT: `sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10` (WSL cannot: `/sys/power/state` read-only) | ❌ fix `:83/:113` + new suite |
| SC3 | README claims match behaviour | static | new suite greps README for forbidden phrase `will now work reliably`, required Option 1/2 split wording, cfg token set | ❌ new suite Wave 0 |

### Sampling Rate
- Per task commit: `bash scripts/test_display_resume_guards.sh` (new) + `bash scripts/test_hibernate_guards.sh`
- Per wave merge: both above + `test_storage_cellular.sh --dry-run`
- Phase gate: all green, then `/gsd-verify-work` with hardware checklist (SC1, SC2, R2, R4)

### Wave 0 Gaps
- [ ] New static guard suite (name at discretion) covering the table above
- [ ] `scripts/test_resume_loop.sh` arithmetic fix (prerequisite of SC2)
- [ ] Optional: `--kernel-src` dry-run fixtures (pass/fail fake trees) — no real kernel source on this machine
- [ ] Framework install: none needed (bash + rg/grep exist in WSL)

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high`.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | — (local installer, no auth surface) |
| V3 Session Management | no | — |
| V4 Access Control | partial | existing `EUID` root gate `install_dkms.sh:45-48`; deletion removes a unit (no privilege change) |
| V5 Input Validation | yes | `--kernel-src` must be validated: non-empty, `[ -d ]`, contains `drivers/gpu/drm/i915/display/intel_pps.c`; all expansions quoted; `patch` runs only with `--dry-run` first |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Arbitrary file write via crafted `--kernel-src` (e.g. pointing at `/`) | Tampering | path sanity check + `patch --dry-run` gate + root-only execution; patch modifies only the 4 declared files under the tree |
| Misleading logs ("Enforcing TCON delay" after failed suspend) | Repudiation | option (b) removes the false claim (R8) |
| Supply chain (kernel patch content) | Tampering | patch lives in-repo, applied only from `$REPO_ROOT`; no network fetch in install |

No packages are installed this phase → **Package Legitimacy Audit: not applicable (none).**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash (WSL2 Ubuntu 24.04) | all guard suites | ✓ | /usr/bin/bash (WSL2 kernel `6.18.40.1-microsoft-standard-WSL2`) | — |
| `patch` | `--kernel-src` gate + fixture tests | ✓ (WSL) | /usr/bin/patch | — |
| `gcc`/`make`/`git` | DKMS build (not runnable here anyway) | ✓ (WSL) | present | — |
| `dkms` | `check_prerequisites` (`install_dkms.sh:51`) | ✗ | — | installer cannot run end-to-end here; static tests only (as in Phases 32/33) |
| `/lib/modules/$(uname -r)/build` headers | DKMS build | ✗ | — | none locally; hardware/CI |
| Kernel source tree (`/usr/src`) | real `--kernel-src` run | ✗ (`/usr/src` empty) | — | fixture trees for dry-run tests |
| Real suspend (`rtcwake -m mem`) | SC2 | ✗ (`/sys/power/state` not writable in WSL2) | — | **defer SC2 to hardware UAT** |
| D330 hardware | SC1, SC2, R2, R4 | ✗ (dev machine is Windows/WSL) | — | UAT checklist in phase gate |
| `rg` inside WSL | — | ✗ | — | suites use `grep` (they already do) |

**Blocking for local execution:** none for the static scope; SC1/SC2 are hardware-deferred by design.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PM notifier ordering at v6.6 also holds for 5.15–6.12 (structure stable; only v6.6 suspend.c read line-by-line) | Q1 | Low — ordering of suspend_prepare/dpm/finish is core invariant |
| A2 | t11_t12 ≥ 500 ms TCON premise (repo's Windows analysis) is physically correct | Q1/Recommendations | Medium — if premise false, whole clamp is unnecessary; not verifiable without hardware |
| A3 | `panel_orientation` cmdline support present for the full 5.15+ target range (verified at v5.15 modedb + v6.6 code; exact introduction commit not pinned) | Q3 | Low |
| A4 | D330-10IGL orientation quirk landed upstream in the v6.1→v6.6 window (v6.1 lacks it, v6.6 has it at `:327-331`) | Q3 | Low |
| A5 | Sibling chromeos/android patches share the mainline-context problem (inferred from identical context lines; their target trees not fetched) | Q2 | Medium — out of scope anyway |
| A6 | Adding the `panel_orientation` property is what the audit intended (vs. correcting the doc) — follows CONTEXT's preferred option | Q8/R4 | Medium — hardware rotation check may flip to doc-correction |

*All kernel/dkms claims above were fetched this session from `raw.githubusercontent.com/torvalds/linux/<tag>/...` and `raw.githubusercontent.com/dell/dkms/main/dkms.8.in` (official upstream sources) — they are `[VERIFIED]` with file:line citations; repo claims are `[VERIFIED]` against files read this session.*

## Open Questions

1. **eDP-1 or DSI-1 on the real panel?** (decides whether the `intel_pps.c` clamp can ever matter — R2). Handle: single UAT grep (`dmesg | grep -E "eDP-1|DSI-1"`); docs keep both `video=` params regardless.
2. **Should `efifb:nobgrt` stay?** Research says yes (Finding 3a) — contradicts an auto-accepted decision whose premise is factually wrong. Handle: planner surfaces evidence; default = keep + fix notes.
3. **Target kernel for Option 2 regeneration** — against which tree should the patch be regenerated so dry-run passes (R1)? Handle: docs-cope this phase ("adapt manually"); regeneration needs a chosen kernel source + is arguably Phase 35+/deferred.
4. **Stale unit on already-installed machines after upgrade** (Runtime State note): one-line manual cleanup in README, or keep disable/rm lines for one release? Handle: planner picks; recommend documenting manual removal (exactness beats lingering uninstall hooks).

## Sources

### Primary (HIGH confidence)
- torvalds/linux **v6.6** raw sources, read this session: `kernel/power/suspend.c` (:351-372, :479-600), `include/linux/suspend.h` (:483-499), `Documentation/fb/modedb.rst` (:17-19, :55-83), `Documentation/fb/efifb.rst`, `drivers/video/fbdev/efifb.c` (:281-310), `drivers/gpu/drm/drm_connector.c` (:147-180, :275-300, :2536-2590), `drivers/gpu/drm/drm_modes.c` (:2112-2135), `drivers/gpu/drm/drm_sysfs.c` (:326), `drivers/gpu/drm/drm_panel_orientation_quirks.c`, `drivers/gpu/drm/i915/display/{intel_pps.c,intel_quirks.c,intel_quirks.h}`
- torvalds/linux **v5.15 / v6.1 / v6.12** same files + **v5.4/v5.10/v6.7-v6.17/master** anchor probes (Q2 table; Q3 `efifb.c:287`, `modedb.rst:68`, `drm_sysfs.c:240`)
- **dell/dkms** `dkms.8.in` (main): `BUILT_MODULE_LOCATION`, `MAKE`/`MAKE_MATCH`, `BUILD_EXCLUSIVE_*` directive semantics
- Repo files read in full/section this session: `lenovo_d330_fix.c`, `d330_display_resume_fix.patch`, `dkms.conf`, `Makefile`, `lenovo-d330-resume.service`, `50-lenovo-d330-boot.cfg`, `install_dkms.sh` (675 lines), `test_resume_loop.sh`, `test_boot_orientation.sh`, `61-lenovo-d330-sensor.hwdb`, `README.md:36-117`, `CHANGES_AUDIT.md:30-69,370-392`, packaging postinst/spec, `34-CONTEXT.md`, `ROADMAP.md:157-208`

### Secondary (MEDIUM confidence)
- Bash errexit × arithmetic behavior — verified live in this environment's bash (`set -e; p=0; ((p++))` → exit 1)
- grep.app rate-limited (429) → anchor probes done via raw GitHub per-tag fetches instead

### Tertiary (LOW confidence)
- Exact upstream commit that added the 82H0 orientation quirk (bracketed v6.1→v6.6 only)
- Compositor reaction to the newly set `panel_orientation` property (hardware UAT)

## Metadata

**Confidence breakdown:**
- Standard Stack: N/A (no new packages) — HIGH
- Architecture (PM ordering, drm cmdline, dkms): HIGH — primary sources read line-by-line
- Pitfalls: HIGH — arithmetic bug and patch-anchor failure proven by execution/probing

**Research date:** 2026-10-08
**Valid until:** ~30 days (kernel/dkms APIs stable; anchor probe set covers tags available as of today)
