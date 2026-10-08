---
phase: 42
plan: 02
subsystem: documentation-parity-packaging-harness
tags: [docs, packaging, parity, guard, static-analysis]
requires:
  - "42-01"
provides:
  - "doc<->code parity guard (SC1)"
affects:
  - CHANGES_AUDIT.md
  - packaging/debian/rules
  - packaging/debian/control
  - packaging/arch/PKGBUILD
  - packaging/rpm/lenovo-d330-fix.spec
  - docs/DISTRO_INSTALL_GUIDE.md
  - scripts/test_doc_parity.sh
  - scripts/test_storage_cellular.sh
tech-stack:
  added: []
  patterns:
    - "static doc<->code parity guard (PASS/FAIL, non-zero on drift)"
    - "fail-loud packagers (no `|| true` around cp/install)"
key-files:
  created:
    - scripts/test_doc_parity.sh
  modified:
    - CHANGES_AUDIT.md
    - packaging/debian/rules
    - packaging/debian/control
    - packaging/arch/PKGBUILD
    - packaging/rpm/lenovo-d330-fix.spec
    - docs/DISTRO_INSTALL_GUIDE.md
    - scripts/test_storage_cellular.sh
decisions:
  - "PKGBUILD prepare(): corrected docs/DISTRO_INSTALL_GUIDE.md instead of adding prepare() - the repo PKGBUILD ships configs/tools only and never builds a kernel; the display-resume patch belongs in the distro kernel PKGBUILD's prepare(), which the doc now states explicitly."
  - "test-script count: actual `ls scripts/test_*.sh | wc -l` == 36 (incl. the new guard), not the 27 the plan estimated. CHANGES_AUDIT section 9 states 36; the guard recomputes it."
  - "Optional runtime deps declared as Recommends (deb), optdepends (Arch), Recommends/Suggests (rpm): thermald, earlyoom, zram-generator, rnnoise-ladspa/librnnoise-ladspa, vainfo/libva-utils, glib2/libglib2.0-bin, desktop-file-utils."
  - "power_cycle_delay_ms authoritative value is the C default 600 (patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:48); CHANGES_AUDIT now matches."
metrics:
  duration: "~20m"
  completed: "2026-10-08"
status: complete
---

# Phase 42 Plan 02: Documentation Parity & Repository Polish Summary

Reconciled every listed `CHANGES_AUDIT.md` claim against the shipping code, made the three
packagers fail loudly on a missing source and declare the real optional runtime deps, and added
a `scripts/test_doc_parity.sh` guard wired into the storage/cellular aggregate runner.

## What Was Built

### Task 2 - Packaging fails loudly + optional runtime deps (`fix`) [4d52ff7]
- Removed `|| true` from every `cp`/install step in `packaging/debian/rules`,
  `packaging/arch/PKGBUILD`, and `packaging/rpm/lenovo-d330-fix.spec`, so a missing source now
  fails the build. (`|| true` remains only on post-install `systemctl`/`udevadm` service enables
  in `%post`/`postinst`, which are intentional best-effort runtime actions, not copy steps.)
- Declared optional runtime deps in all three packagers:
  - `packaging/debian/control` Recommends: `thermald, earlyoom, zram-generator,
    librnnoise-ladspa, vainfo, libglib2.0-bin, desktop-file-utils` (plus existing
    `iio-sensor-proxy, v4l2loopback-dkms`).
  - `packaging/arch/PKGBUILD` optdepends: `thermald, earlyoom, zram-generator,
    rnnoise-ladspa, libva-utils, glib2, xdg-utils`.
  - `packaging/rpm/lenovo-d330-fix.spec` Recommends/Suggests:
    `thermald, earlyoom, zram-generator` / `librnnoise-ladspa, libva-utils, glib2,
    desktop-file-utils`.
- `prepare()`: rather than add a kernel `prepare()` to the config-only repo PKGBUILD, corrected
  `docs/DISTRO_INSTALL_GUIDE.md` (Arch section) to state the display-resume patch belongs in the
  distro kernel PKGBUILD's `prepare()`, not this repository's.

### Task 3 - Doc-parity guard + aggregate wiring (`test`) [952a4bd]
- Created `scripts/test_doc_parity.sh` (12 checks, PASS/FAIL summary, non-zero on failure):
  swappiness=180 (sysctl + audit); `mq-deadline` in the eMMC rule + audit (and no `bfq`);
  `i915.enable_fbc=0` (boot cfg + audit); `panel_orientation` present (cfg + audit);
  `softlockup_panic=1` present / `nowatchdog` absent (fastboot cfg + audit); no tracked PWM boot
  service + audit documents removal; no `GTK3`/AppIndicator tray claim (audit + `tools/d330-tray.py`
  has no `gi`/`Gtk` import); no `iwlwifi` wireless claim (audit + wireless conf); test-script count
  parity (`ls scripts/test_*.sh`); no `touch-mode` claim (audit + `tools/d330-ctl`);
  `scripts/*.sh`/`tools/*.sh` are index mode `100755`; no 0-byte tracked files.
- Wired into `scripts/test_storage_cellular.sh` `--dry-run` aggregate (execution + the `bash -n` loop).
- `chmod +x` / index mode `100755` (`fe4b33e`).

### Task 1 - CHANGES_AUDIT parity (`docs`) [247df1a]
Reconciled each listed contradiction against the code:
- §2.1 `enable_fbc=0` (code `patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf`); `power_cycle_delay_ms=600`
  matches the C default (`patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:48`).
- §2.2 `panel_orientation=right_side_up` present (`50-lenovo-d330-boot.cfg`).
- §4.2 `vm.swappiness=180` + `mq-deadline` eMMC scheduler (code + audit + inventory table).
- §4.4 removed the nonexistent `touch-mode` subcommand claim (`tools/d330-ctl` has none).
- §4.5 PWM: no boot service (removed Phase 37); `--apply` is honest/verified.
- §7.3 earlyoom `--prefer`/`--avoid` lists match `patches/oom_protection/etc/default/earlyoom`
  (`code` absent from prefer).
- §5.4 FCC hook tracked as `8086`, installed as `8086:7360`.
- §7.2 removed the "15 s PL2 window" claim ("no time-window register is written").
- §7.6 wireless: no Intel; `rtl8821ce ant_sel=2`; `rtw88_core`/`rtw88_pci` tuning.
- §7.8 tray is a stdlib notification/status helper (no GTK/AppIndicator).
- §9 test-script count = 36.
§7.6/§7.8 were already correct at HEAD; no edit was needed there.

## Verification

All gates run under WSL bash (`wsl bash -lc`). Raw final lines:

- `scripts/test_doc_parity.sh`: `Doc-parity summary: passed=17 failed=0` (RC=0)
- `scripts/test_storage_cellular.sh --dry-run`: `RC=0` (aggregate; all nested suites green)
  - microsd `passed=26 failed=0`; display-fix `10/0`; hibernate `21/0`; installer-symmetry `17/0`;
    no-op `5/0`; audio-dsp `passed=17 failed=0`; mic-rnnoise `7/0`; udev/hwdb `10/0`;
    power-stack `12/0`; wireless coex OK; harness-trust `passed=9 failed=0` + `RESULT: PASS`.
- `scripts/test_harness_trust.sh` (standalone): `Harness-trust meta-guard summary: passed=9 failed=0` / `RESULT: PASS` (RC=0)
- `git ls-files -s scripts/*.sh tools/*.sh | grep -v 100755` -> empty (50 files, all `100755`)

## Deviations from Plan

### Auto-fixed / process notes

**1. [Rule 3 - Blocking] Header exec bit lost by SDK commit on Windows**
- **Found during:** Task 3 post-commit check
- **Issue:** `gsd-tools query commit --files scripts/test_doc_parity.sh` recorded the new file
  as `100644` in the tree because the repo runs with `core.fileMode=false` on Windows; the SDK
  commits with a pathspec (`git commit -- <paths>`), which re-derives the mode from the working
  tree and drops the exec bit. The index still held `100755`, so the guard's index check passed,
  but a fresh checkout would not.
- **Fix:** Applied the same mechanism Phase 42 used for the existing scripts:
  `git update-index --chmod=+x scripts/test_doc_parity.sh` followed by a pathless
  `git commit -m "chore(42): track doc-parity guard as 100755"` (commit `fe4b33e`). This is the
  only commit not routed through `gsd-tools query commit`; it is required because the SDK cannot
  carry a mode change on this host. Result: `git ls-tree HEAD` shows `100755`.

No functional deviations; packaging/doc edits follow the plan. The plan's Task 1 estimate of
27 test scripts was superseded by the verified actual count (36).

## Deferred / Out of Scope

- Real `dpkg-buildpackage`/`makepkg`/`rpmbuild` runs (SC2 host-bound) remain deferred.
- Pre-existing working-tree noise (CRLF-only modifications to `README.md`, `patches/*`, `.gitkeep`;
  the `AUDIT_PROMPT.md` deletion; `.planning`/`.gsd` junction untracked entries) was left untouched.

## Commits

| Commit | Type | Description |
| --- | --- | --- |
| `4d52ff7` | fix(42) | packaging fails loudly on missing source; declare optional deps |
| `952a4bd` | test(42) | add doc-parity guard and wire into storage runner |
| `247df1a` | docs(42) | reconcile CHANGES_AUDIT claims with code (M17) |
| `fe4b33e` | chore(42) | track doc-parity guard as 100755 |

## Self-Check: PASSED
- `scripts/test_doc_parity.sh` present, executable (`100755` in HEAD), guard green (17/0).
- CHANGES_AUDIT reconciled; `power_cycle_delay_ms=600` matches the C source.
- All listed gates green under WSL bash.
- No 0-byte tracked files; all `scripts/*.sh` + `tools/*.sh` index mode `100755`.
