# Architecture Research: Integrating the D330 Resume-Black-Screen Fix

**Domain:** Linux DRM/i915 out-of-tree fix + distro packaging + on-device verification
**Project:** lenovo-d330-linux-screen-fix, milestone v8.0 (fix the open resume black screen)
**Researched:** 2026-10-12
**Confidence:** MEDIUM overall — repo integration points are HIGH (read directly from the tree);
option choice is constrained by the prior on-device research (host regs byte-identical, reload is the
only proven recovery); upstream process is MEDIUM (kernel docs read, i915 GitLab behind a bot wall).

---

## Executive Summary

The bug is not a missing host write. The two research docs (`DISPLAY_RESUME_CCS_MODIFIER.md`,
`DSI_RESUME_TRACE_ANALYSIS.md`) establish, with `i915_reg_rw`/`pr_err` tracing on real hardware,
that on resume i915 runs the **full** cold DSI power-on sequence, drives the same VBT GPIOs
(144/145/160), programs the same PLL/CDCLK, and leaves the DSI link, panel-power and PHY registers
**byte-identical** to a state produced by a full i915 reload. The only reliable recovery is a PCI
**unbind/bind of `0000:00:02.0`** ("reload"), which works because the driver *probe* path
(`intel_modeset_setup_hw_state()` + full encoder init) does something the S4 resume path
(`__intel_display_driver_resume()` -> `drm_atomic_helper_commit_duplicated_state()`) does not.

That single fact drives the whole integration architecture:

- **Option (a) a clean i915 resume-path patch** is the right *goal* but is currently **unimplemented**
  and unproven — no host-side lever has been found. It can only be attempted after the RE push
  answers "what does probe do that resume does not?". Do not plan it as a certain deliverable.
- **Option (b) an out-of-tree/DMI-gated module** cannot fix this. The fault is inside i915's
  non-exported display code; a `register_pm_notifier` module can only re-trigger user-visible
  recovery (duplicating (c) with more build risk). Reject as a primary path.
- **Option (c) a robust automatic i915 unbind/bind reload + compositor restart** already exists in
  the tree (`patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh`, manifest line
  118), meets the milestone's explicit "seamless automatic recovery is acceptable" bar, and is the
  only path with a proven end state. **This is the recommended v8.0 deliverable: harden it, ship it
  through the packagers (currently a gap), and machine-verify it.** Keep (a) as a parallel stretch.
- **Option (d) a KWin/compositor-side workaround** is a diagnostic, not a product fix: the
  no-compositor resume is *also* black (trace analysis Result 3), so "avoid the encoder
  disable/enable" is not obviously sufficient, and it is KWin-only in a project that targets
  GNOME/Mint/ChromeOS/Android-x86. Run it as an experiment feeding (a)/(c); do not ship it as a new
  component.

The integration work is therefore dominated by three things the repo already models well: the
**deploy manifest** (`deploy_manifest()` in `scripts/install_dkms.sh`) as the single source of truth,
the **installer symmetry guard** (`scripts/test_installer_symmetry.sh`) that machine-checks it, and
the **harness-trust meta-guard** (`scripts/test_harness_trust.sh`) that forces any on-device
mutation test to be `--apply`-gated. A new component is only "done" when it appears in the manifest,
the installer body, the uninstaller body, the packagers, and the CI `.deb`.

---

## Option Comparison

| Criterion | (a) i915 resume patch | (b) OOT module / DMI hack | (c) auto reload + DM restart | (d) KWin workaround |
|:--|:--|:--|:--|:--|
| Feasible today? | **No** — root cause unfound | Yes, but cannot fix | **Yes** (proven recovery) | Maybe, KWin-only |
| Fixes root cause? | Yes (if found) | No | No (recovers panel) | No (avoids symptom) |
| Upstreamable? | Yes (the only one) | No | No | No |
| Ship path today | `run_kernel_src_step` + CI kernel | DKMS (exists) | sleep hook (exists) | none |
| Boot safety | High (source tree only) | High | High (post-resume) | Med (DM/session) |
| User-visible cost | none | none | session lost, re-login | none |
| Harness-verifiable | static + CI grep | static | static + on-device | not in CI |
| Packaging effort | patch + CI | none | **packagers must add system-sleep** | n/a |
| Risk of unbootable tablet | low (bad patch = build fails) | low | low | low |

### (a) Clean i915 kernel resume-path patch

**What it is.** A hunk in `drivers/gpu/drm/i915/display/...` that makes the resume path perform
whatever the probe path does (e.g. re-run the DSI encoder disable+enable, or call the panel init from
`__intel_display_driver_resume()`). Highest-value RE target: diff probe vs resume around
`intel_modeset_setup_hw_state()`.

**Integration.** Extend `patches/d330_display_resume_fix.patch` (or add a second patch file). It is
consumed by `run_kernel_src_step()` (installer lines ~233-293), which dry-runs first and **warns,
never fails**, on context mismatch. `.github/workflows/build-kernel.yml` applies it and greps a
content marker to *prove* the hunk landed (lines ~100-106), then publishes a prerelease
`kernel-<ver>` `.deb`.

**Deploy/revert.** It edits a *kernel source tree* — the running kernel is unchanged until rebuild +
install + reboot. Revert = rebuild from an unpatched tree, or simply boot the stock kernel. Safe:
a broken patch fails the build, so a bad kernel never reaches `/boot`.

**Verify.** `scripts/test_display_fix_guards.sh::case_kernel_src_dryrun_first` already asserts the
dry-run probe precedes a real apply; add a grep for the new hunk marker. CI proves it applied.
On-device: boot the CI `-d330-fix` kernel as a **non-default** GRUB entry and run the rtcwake loop.

### (b) Out-of-tree module or DMI-gated hack

**Why it fails here.** i915's display entry points are not exported; an out-of-tree module cannot
call `intel_dsi_pre_enable()`, `intel_power_domains_init_hw()`, etc. kprobe/ftrace hacks on
non-exported symbols are fragile and upstream-rejected, and — crucially — the research already shows
register-forcing and `glk_cold_boot` forcing do **not** fix the panel, so there is nothing a module
could poke. The existing `lenovo_d330_fix.ko` is honestly scoped as a **banner-only** module
(`patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c`), and
`test_display_fix_guards.sh::case_module_banner_no_dead_sleep` / `case_dkms_build_guards` actively
enforce that it stays that way. **Do not expand the module to "fix" the panel.**

**Where it *could* plug in (if ever):** as a carrier that, on `PM_POST_SUSPEND`, schedules the reload
— but the system-sleep hook does that with zero build cost, no per-kernel rebuild, and no DKMS
churn on kernel upgrades. So it is strictly worse than (c).

### (c) Automatic i915 unbind/bind reload + display-manager restart

**What it is.** The shipped fallback, already wired:
- `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` — on `post/*`, DMI-gated
  to `82H0`, reloads every i915 PCI device, then restarts `display-manager.service`. Bounded by
  `timeout 30` so a stuck rebind cannot hang resume. Runtime-off switch = `/etc/default/lenovo-d330-display-resume`
  containing `D330_DISPLAY_RESUME=0`.
- `scripts/d330-display-reload.sh` — the same reload, manual/SSH, **not deployed and not packaged**.

**Integration.** Manifest line 118 (`exec`), install copy at lines ~442-444, uninstall `rm` at line
~867. systemd-sleep runs *every* file under `/usr/lib/systemd/system-sleep/`, so **no
`systemctl enable` step is needed** — a fact that keeps install/uninstall symmetry simple.

**Deploy/revert.** Table stakes, but with three gaps to close:
1. **Packaging gap (HIGH priority).** No packager ships `patches/*/etc/systemd/system-sleep/*.sh`
   (`rg system-sleep packaging/` -> none). So `.deb`/`.rpm`/PKGBUILD users get **no recovery at all** —
   the wifi, touchscreen and display hooks are all silently missing from packaged installs. Fixing
   this is the single largest correctness win of the (c) path.
2. **Manifest/disable-file gap.** The runtime disable file `/etc/default/lenovo-d330-display-resume`
   is not in the manifest and is not removed by `--uninstall`; a re-install after a disable keeps it
   disabled. Add it as a `state` (or `*-optional`) manifest entry and remove it in `do_uninstall`.
3. **Deploy `d330-display-reload`.** Either promote `scripts/d330-display-reload.sh` to
   `/usr/local/bin/d330-display-reload` (exec, manifest, packagers) so packaged users have the manual
   escape hatch, or keep it dev-only and only ship the hook — decide explicitly.

**Verify.** Static (extend `test_display_fix_guards.sh` and `test_installer_symmetry.sh`); on-device
(new, `--apply`-gated or living in a non-`test_*.sh` script). Details in "Safe On-Device Test".

### (d) Compositor-side workaround (KWin Wayland)

**What it is.** Keep the DSI output from being disabled/re-enabled across suspend, or force the
compositor to re-open DRM and do a full modeset after resume (a KWin restart already recovers a fresh
session on the reloaded GPU — that is why the hook restarts the DM).

**Why it is not the product fix.** (1) Trace Result 3: with **no compositor** the resume issues no DSI
writes and the panel is **still black** — so avoiding the encoder cycle is not sufficient by itself.
(2) KWin-only in a project that also targets GNOME, Cinnamon/Mint, ChromeOS and Android-x86. (3) It
adds a `kwinoutputconfig.json` / `kscreen-doctor` / session-side component that the current harness
cannot exercise in CI. Classify it as an **experiment** that may reveal the encoder-cycle ordering
that option (a) then fixes in the driver; if a compositor toggle ever becomes shippable, fold it into
the existing sleep hook rather than adding a new top-level component.

### Recommendation

**Ship (c), hardened and packaged, as the v8.0 deliverable; pursue (a) in parallel via the RE push;
reject (b); treat (d) as an experiment.** Rationale: (a) has no proven lever yet and the milestone
explicitly accepts invisible reload/restart; (c) is the only path with a demonstrated working end
state and it reuses the repo's existing manifest/symmetry machinery. Order matters: land (c) first so
a working, verified baseline exists, then attempt (a) without risking the milestone.

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│ REPO (source of truth)                                                │
│  scripts/install_dkms.sh   ← deploy_manifest() + install/uninstall/   │
│  patches/display/…sleep…   ← recovery hook    patches/d330_…patch     │
│  patches/dkms/…            ← banner module    scripts/test_*.sh       │
└───────────────┬──────────────────────────────────────────────────────┘
                │ --install / --uninstall / --verify
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ INSTALLER (manifest-driven, symmetric)                                │
│  file/exec/unit → /etc, /usr/local/bin, /usr/lib/systemd/{user,sleep} │
│  dkms add/build/install              run_kernel_src_step (--kernel-src)│
└───────────────┬──────────────────────────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ DEPLOYED SYSTEM                                                        │
│  systemd-sleep hooks ──(post/*)──► i915 unbind/bind ──► restart DM     │
│  modprobe.d i915      (enable_psr=0 enable_fbc=0)                      │
│  GRUB cmdline         (orientation, fbcon=rotate:1)                    │
└───────────────┬──────────────────────────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ KERNEL / DRM                                                           │
│  i915 resume path (black)   vs   i915 probe path (reload, works)       │
│  DSI encoder · VBT GPIO 144/145/160 · panel/link (state not readable)  │
│  patches/d330_display_resume_fix.patch (CCS-on-82H0) → CI kernel .deb  │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|:--|:--|:--|
| `deploy_manifest()` | Single source of truth for deployed artifacts | `path<TAB>kind` heredoc, installer lines 89-168 |
| `do_install()` | Stage DKMS, copy configs/hooks/tools, enable units | hand-written cp/`systemctl enable` blocks |
| `do_uninstall()` | Reverse every install action, regen GRUB/initramfs | hand-written rm/`disable --now` list |
| `do_verify()` | Diff deployed tree vs manifest; `--root`+`--removed` | lines 1030-1186 |
| `run_kernel_src_step()` | Optional Option-2 patch apply, dry-run-gated | lines 233-293 |
| display resume hook | Post-resume i915 reload + DM restart, bounded | `/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh` |
| `d330-display-reload.sh` | Manual/SSH reload escape hatch | `scripts/`, not yet deployed |
| banner module | DMI match + honest breadcrumb only | `patches/dkms/lenovo-d330-fix/` |
| `test_display_fix_guards.sh` | Static truth checks for the display deliverable | 10 cases, no root/hardware |
| `test_installer_symmetry.sh` | Manifest ↔ install/uninstall ↔ packagers symmetry | 17 cases, fixture `--verify` |
| `test_harness_trust.sh` | Meta-guard: fail-ability (SC1) + `--apply` gate (SC2) | breaks subjects, scans sources |
| `test_storage_cellular.sh` | Harness entry point (`--dry-run`) | `bash -n` list + suite calls |

---

## Integration Points (per option)

| Concern | (a) i915 patch | (c) reload + DM restart | Notes |
|:--|:--|:--|:--|
| `deploy_manifest()` | no new entry (source-tree artifact) | entry already exists (line 118); add disable file | manifest is authoritative |
| `do_install()` | via `--kernel-src` (unchanged) | copy already at lines ~442-444 | keep ordering/log lines |
| `do_uninstall()` | n/a (patch is on a source tree) | `rm` at line ~867; add disable-file `rm` | symmetric |
| `do_verify()` | n/a | covered automatically by manifest `exec` | `--root` fixture safe |
| `scripts/d330-display-reload.sh` | — | decide: promote to `/usr/local/bin` or keep dev-only | affects manifest+packagers |
| Packagers (deb/rpm/arch) | ship patch via CI only | **must add `system-sleep` deployment** | current gap |
| `build-kernel.yml` | apply + grep hunk marker | n/a | already greps CCS marker |
| Harness (static) | extend `test_display_fix_guards.sh` | extend display suite + symmetry suite | counts matter |
| Harness (on-device) | CI kernel + rtcwake loop | new `--apply`-gated test | SC2 gate required |
| Docs parity | README/patches/CHANGES_AUDIT | same | `test_doc_parity.sh` |

**Symmetry contract (from `test_installer_symmetry.sh`):** every manifest entry must have its
**basename** in the installer body (with the manifest heredoc stripped) *and* its **full path** in the
uninstaller body. `unit-enabled` rows must be enabled in `install_dkms.sh`, `packaging/debian/postinst`
*and* the RPM `%post` (parity is asserted). A new deployed file that is not added to all of these
fails the suite.

**Harness-trust contract (from `test_harness_trust.sh` SC2):** any `scripts/test_*.sh` that runs
`systemctl start/...`, `modprobe`, or writes under `/sys` or `/proc` **must** parse `--apply` and
branch on it before the mutation, or the scan fails. The reload test writes to
`/sys/bus/pci/drivers/i915/{unbind,bind}` — so it either (i) lives in a non-`test_*` script
(`scripts/d330-display-*.sh`, which is *not* scanned) or (ii) is a `test_*.sh` with a real `--apply`
gate. Also note `test_display_fix_guards.sh::case_resume_service_deleted_zero_refs` forbids the literal
`lenovo-d330-resume.service` anywhere in installer/postinst/spec/audit/README — do not reintroduce it.

---

## New vs Modified Components

### New

| Component | Purpose | Why new |
|:--|:--|:--|
| `docs/research/RESUME_FIX_LEDGER.md` | One tried/disproven ledger so nothing is re-tread | milestone deliverable |
| `scripts/test_display_resume_recovery.sh` (or new cases in the display suite) | Static proof the hook is manifest-tracked, DMI-gated, timeout-bounded, and packaged | verification |
| `scripts/d330-display-resume-test.sh` | On-device rtcwake + reload-recovery test (`--apply`-gated, root) | no such test exists |
| optional `patches/d330_display_resume_v2.patch` | The (a) resume-path fix, if the RE finds it | only if found |

### Modified

| Component | Change |
|:--|:--|
| `scripts/install_dkms.sh` | add disable file to manifest (+install/uninstall); optionally deploy `d330-display-reload`; keep symmetry |
| `packaging/debian/rules` (+`postinst`), `packaging/rpm/lenovo-d330-fix.spec`, `packaging/arch/PKGBUILD` (+`.install`) | deploy `patches/*/etc/systemd/system-sleep/*.sh` (and the manual reload tool) |
| `scripts/test_storage_cellular.sh` | register any new suite in the `bash -n` list and the run list |
| `scripts/test_display_fix_guards.sh` | new cases for the hook/manifest/packaging; update case counts |
| `.github/workflows/build-kernel.yml` | grep marker for a new patch hunk (if (a) lands) |
| `README.md`, `patches/README.md`, `CHANGES_AUDIT.md`, `docs/research/*` | doc parity |

---

## Data Flow

### Resume flow (option c, current + hardened)

```
systemd suspend → i915 post_disable (panel off) → S3
        ↓ resume
i915 __intel_display_driver_resume (no DSI pre_enable)  ── panel black
        ↓ ~3 s later
compositor commit → intel_dsi_pre_enable (full cold seq) ── panel still black
        ↓ systemd-sleep post/*
lenovo-d330-display-resume.sh (DMI 82H0)
   → unbind 0000:00:02.0 → probe path re-inits panel → bind  (works)
   → systemctl restart display-manager  (fresh session on new card node)
```

### Install / uninstall symmetry flow

```
deploy_manifest() ──► do_install()  (cp + chmod + enable) ──► deployed tree
                 └─► do_uninstall() (rm + disable --now)  ──► baseline
do_verify(--root R) populates R from the manifest and diffs; --removed inverts.
test_installer_symmetry.sh cross-checks manifest ⊆ installer body ⊆ packagers.
```

### Verification flow

```
scripts/test_storage_cellular.sh --dry-run
  ├─ bash -n <every listed script>
  ├─ test_display_fix_guards.sh   (static, display)
  ├─ test_installer_symmetry.sh   (manifest round-trip)
  ├─ test_harness_trust.sh        (SC1 fail-ability + SC2 --apply gate)
  └─ test_doc_parity.sh           (docs == code)
on-device (root, --apply): rtcwake loop + assert rebound device + fresh card node + hook journal
```

---

## Architectural Patterns

### Pattern 1: Bounded system-sleep recovery hook

**What:** A `post/*` hook that performs a DMI-gated, `timeout`-bounded hardware recovery and then
restarts the display manager, because the live compositor cannot survive a GPU teardown.
**When:** Only when a clean driver fix is unavailable and an automatic recovery is acceptable.
**Trade-offs:** Recovers without reboot (the point); costs the live session; logs a non-fatal
`drm_framebuffer_cleanup` warning; changes the DRM card node.

```sh
case "${1:-}/${2:-}" in
  post/*)
    [ "$(cat /sys/class/dmi/id/product_name)" = "82H0" ] || exit 0
    timeout 30 "$0" _run || logger -t d330-display "reload timed out"
    ;;
  _run/*) reload_i915; systemctl restart display-manager.service ;;
esac
```

**Hardening to add:** the disable file in the manifest; deploy to packagers; keep `timeout`; never
hot-remove the device (see anti-patterns).

### Pattern 2: Option-2 kernel patch via the dry-run gate

**What:** `run_kernel_src_step()` applies `patches/d330_display_resume_fix.patch` to an
operator-supplied tree, gated by `patch -p1 --dry-run`; mismatch → `[WARN]`, never failure.
**When:** For custom/distro kernels; the only path to an upstreamable fix.
**Trade-offs:** Patch context is kernel-ABI-specific; the installer's fail-soft behaviour is correct
but means "patch not delivered" can be silent — the guard suite force-orders dry-run before apply and
CI greps the landed marker.

### Pattern 3: DMI-gated i915 quirk the upstream way

**What (upstream shape):** i915 already has a first-class DMI quirk mechanism in
`drivers/gpu/drm/i915/display/intel_quirks.c`: an `enum intel_quirk_id` in `intel_quirks.h`, a
`quirk_*(struct intel_display *)` hook calling `intel_set_quirk()`, a `struct intel_dmi_quirk` entry
with a `dmi_system_id` list wired into `intel_dmi_quirks[]`, and consumers checking
`intel_has_quirk(display, QUIRK_...)`. **Any board-specific i915 fix must use this, not a scattered
`dmi_match()`.** This is also where a `quirk_d330_*` would live if (a) needs gating.
**When:** Only when the fix is genuinely board-specific and the root cause is understood.

### Pattern 4: Manifest-driven deploy (existing invariant)

**What:** One `deploy_manifest()` is the authority; `--verify` diffs it; the symmetry suite
cross-checks it against the hand-written install/uninstall bodies and the packagers.
**When:** Every new artifact. Non-negotiable in this repo.

### Pattern 5: CI-built kernel as a non-default boot entry

**What:** `build-kernel.yml` builds a `-d330-fix` kernel and publishes a prerelease; it is installed
alongside the stock kernel and only made default after a verified boot.
**When:** Any kernel-patch deliverable. Keeps the stock kernel as the rollback path.

---

## Anti-Patterns

### Anti-Pattern 1: Hot-removing the GPU
**What people do:** `echo 1 > /sys/bus/pci/devices/0000:00:02.0/remove` + rescan, or bare PCI reset.
**Why it's wrong:** The research shows remove+rescan left the box hung and the bare reset made the
panel fully off. Only **unbind/bind** recovers.
**Do instead:** unbind/bind, never remove/rescan.

### Anti-Pattern 2: An out-of-tree module trying to fix the panel
**What people do:** expand `lenovo_d330_fix.ko` to poke DSI registers or kprobe i915 internals.
**Why it's wrong:** i915 display symbols aren't exported; register forcing is already proven not to
fix it; upstream rejects it; per-kernel rebuild churn for zero benefit.
**Do instead:** keep the module banner-only (its guard suite enforces this); do recovery in the sleep
hook.

### Anti-Pattern 3: A scattered `dmi_match()` in a random i915 file
**What people do:** `if (dmi_match(DMI_PRODUCT_NAME, "82H0")) ...` inline at a call site.
**Why it's wrong:** Not the i915 convention; maintainers reject it; it cannot be reuse-tested and
evades the quirk registry.
**Do instead:** `intel_quirks.c` `intel_dmi_quirks[]` + `intel_has_quirk()`.

### Anti-Pattern 4: Shipping a hook that is not in the manifest or the packagers
**What people do:** add a `system-sleep` file, wire it in the installer only.
**Why it's wrong:** The manifest has no visibility (drift), and packaged users get nothing — the exact
gap that exists today for the display/wifi/touchscreen hooks.
**Do instead:** manifest entry + install + uninstall + all three packagers + a symmetry guard case.

### Anti-Pattern 5: An un-gated on-device mutation test
**What people do:** add `scripts/test_display_resume.sh` that writes to
`/sys/bus/pci/drivers/i915/unbind`.
**Why it's wrong:** `test_harness_trust.sh` SC2 fails the whole harness.
**Do instead:** `--apply` gate it, or put it in a `scripts/d330-*.sh` (non-`test_*`) script.

### Anti-Pattern 6: Making the patched kernel the default before a verified boot
**What people do:** install the `-d330-fix` kernel and set it as default immediately.
**Why it's wrong:** one bad boot and the tablet is hard to recover on-device.
**Do instead:** keep the stock kernel default; add the patched one as a second entry; switch only
after a clean boot + resume test.

---

## Safe On-Device Test & Rollback (avoid an unbootable tablet)

**Boot safety rules**
1. Never let the fix touch the only GRUB entry. Keep the stock kernel default; add the `-d330-fix`
   kernel as a second entry and switch only after a verified boot.
2. No new cmdline requirements. The installer's resume-cmdline step already fails loud on mismatch;
   keep orientation (`fbcon=rotate:1`, `video=DSI-1:panel_orientation=right_side_up`) intact.
3. A bad kernel patch fails the *build*, so it cannot reach `/boot` — the fail-soft
   `run_kernel_src_step` is safe by construction.

**Runtime/graphics safety rules**
4. Only **unbind/bind** the GPU (never remove/rescan, never bare PCI reset).
5. Keep SSH up before testing; the reload hook restarts the display manager, so the console session
   is expected to drop.
6. Test with `rtcwake -m mem -s N` over SSH, not the lid, so the machine is reachable through the
   whole cycle.

**Fast reverts (no reinstall required)**
7. Disable the recovery without uninstalling: `echo D330_DISPLAY_RESUME=0 > /etc/default/lenovo-d330-display-resume`
   (or `rm /usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh`).
8. Full revert: `sudo ./scripts/install_dkms.sh --uninstall`, then
   `sudo ./scripts/install_dkms.sh --verify --removed` must exit 0 (proves nothing is left behind).
9. Kernel: boot the stock entry; or `dpkg -r` the `-d330-fix` kernel package.

**Proposed on-device acceptance test (new)**
```
pre:  record /sys/class/drm/card*/DSI-1/status, backlight actual_brightness, bound device
run:  rtcwake -m mem -s N   (or systemctl suspend with RTC wake)
post: 
  - journalctl -t d330-display shows the hook ran on 82H0
  - i915 bound again: /sys/bus/pci/drivers/i915/0000:00:02.0 exists
  - a fresh DRM card node exists (card node changes on reload — expected)
  - backlight actual_brightness > 0 after the DM restarts
assert: hook ran AND device rebound AND (best-effort) backlight on
```
Gate the /sys writes behind `--apply`; otherwise implement it in `scripts/d330-display-*.sh`.

---

## Upstream Submission Requirements (for option (a))

**Bug + reproducer first.** File on the i915 tracker
(`gitlab.freedesktop.org/drm/i915/-/issues`) with the `i915_reg_rw` trace, the resume-vs-reload
register diff (empty), and the exact reproducer (`rtcwake -m mem`). Maintainers reject a
"D330 stays black" DMI quirk without a root cause.

**Root cause, not a workaround.** The patch must explain *what* the resume path fails to do that
probe does. The reload's trace (`DSI PHY → DSI core → PLL → CDCLK`) and the absence of
`intel_dsi_pre_enable()` in i915's own resume are the evidence to build on. `glk_cold_boot` is a
correlate, not the cause — don't submit it.

**DMI gating — the i915 way.** Prefer a generic fix. If board-specific, use
`intel_quirks.c` `intel_dmi_quirks[]` + `enum intel_quirk_id` + `intel_has_quirk()`; add a
`drm_info()` line naming the quirk. Do **not** add `dmi_match()` inline. Note the orientation quirk
for this board **already exists upstream** (`drm_panel_orientation_quirks.c`: `82H0` matches
`DMI_PRODUCT_VERSION "Lenovo ideapad D330-10IGL"` → `lcd800x1280_rightside_up`), so no
orientation quirk is needed.

**Commit shape (DRM/i915).**
- One logical change per patch; subject `drm/i915/display: <subsystem>: <imperative summary>` (or
  `drm/i915/vlv_dsi:` / `drm/i915/intel_quirks:`).
- Body: symptom → root cause → fix → "Tested on: Lenovo IdeaPad D330-10IGL (82H0), kernel X".
- Trailers: `Closes: <gitlab issue URL>`; `Fixes: <12-hex> ("<original subject>")` if a regression;
  `Cc: stable@vger.kernel.org` for regressions; `Signed-off-by: Real Name <real@email>` (DCO — a
  fictitious agent identity will be rejected; use a real developer identity); `Reviewed-by` from a
  maintainer comes later.
- `checkpatch.pl --strict` clean; reverse-Christmas-tree declarations; `drm_dbg_kms()`/`drm_info()`
  (not `pr_err`); no `msleep` in atomic paths; add an IGT test if it changes uAPI-observable
  behaviour.

**Process.** Plain-text `git send-email` to `intel-gfx@lists.freedesktop.org` (cc
`dri-devel@lists.freedesktop.org`); reply to review, respin with `v2` + a changelog under `---`;
follow the DRM merge windows (feature work into linux-next by -rc6 / drm-next by -rc7; only bugfixes
after the merge window; ~1 month blackout). **Stable tags:** a plain new quirk does not auto-go to
stable — add `Cc: stable@vger.kernel.org` only for regressions with a `Fixes:` tag.

---

## Recommended Build Order (dependencies first)

1. **Phase A — Harden and ship the recovery (c).** Ledger the prior work; add the disable file to the
   manifest; fix the packagers to ship `system-sleep`; optionally deploy the manual reload tool;
   extend the static suites. Lowest risk, no kernel build, meets the accepted bar. Delivers a
   verified working recovery even if (a) never lands.
2. **Phase B — RE the resume/probe delta.** Windows `igdkmd64.sys` + GOP RE (REA/Ghidra) and the
   on-device resume-vs-probe trace, targeting "what probe does that resume doesn't". Produce the
   tried/disproven ledger and, if found, a candidate hunk.
3. **Phase C — The fix (a), if B found one.** Implement the resume-path patch (upstream shape),
   build a CI `-d330-fix` kernel as a **non-default** GRUB entry, verify on-device with the reload
   disabled. If B finds no lever, close the milestone on (c) honestly rather than shipping a
   non-fix.
4. **Phase D — Upstream (only if C landed).** DMI quirk via `intel_quirks.c` if needed, file the bug,
   send to intel-gfx/dri-devel, follow the merge windows.

**Why this order:** (c) is provably correct today and independent of the RE outcome; (a) depends on
Phase B's unknown; upstream (D) depends on (a). Putting (a) first risks the whole milestone on an
unfound root cause.

---

## Sources

- Repo (read directly):
  - `scripts/install_dkms.sh` (deploy_manifest lines 89-168, `run_kernel_src_step` 233-293,
    install step 5 sleep hooks ~442-444, uninstall ~865-867, `do_verify` 1030-1186)
  - `scripts/d330-display-reload.sh`, `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh`
  - `patches/d330_display_resume_fix.patch`, `patches/dkms/lenovo-d330-fix/*`, `patches/README.md`
  - `scripts/test_display_fix_guards.sh`, `scripts/test_installer_symmetry.sh`,
    `scripts/test_harness_trust.sh`, `scripts/test_resume_loop.sh`, `scripts/test_storage_cellular.sh`
  - `.github/workflows/build-kernel.yml`
  - `packaging/debian/{rules,postinst,control}`, `packaging/rpm/lenovo-d330-fix.spec`,
    `packaging/arch/{PKGBUILD,lenovo-d330-fix.install}` (no `system-sleep` shipped)
  - `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `docs/research/DSI_RESUME_TRACE_ANALYSIS.md`,
    `docs/research/COMMUNITY_FINDINGS.md`, `docs/windows_analysis/RESUME_SEQUENCE.md`, `README.md`
- Upstream kernel (read directly):
  - `drivers/gpu/drm/i915/display/intel_quirks.c` (DMI quirk mechanism, `intel_dmi_quirks[]`,
    `intel_has_quirk()`) — the upstream shape for a board quirk
  - `drivers/gpu/drm/drm_panel_orientation_quirks.c` (D330-10IGL `82H0` orientation quirk already
    present)
  - `Documentation/gpu/introduction.rst` (DRM contribution process, merge windows, code of conduct)
  - `Documentation/gpu/i915.rst` (i915 style / register-macro rules)
- Notes: i915 GitLab and lore.kernel.org were bot-walled (Anubis) at research time, so the i915
  `CONTRIBUTING` text could not be quoted verbatim; the process points above are from the kernel DRM
  docs and established DRM/i915 practice. Verify the exact tracker URL and trailer conventions at
  submission time.

---

*Architecture research for: integrating the D330 resume black-screen fix*
*Researched: 2026-10-12*
