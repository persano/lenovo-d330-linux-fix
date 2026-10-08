---
phase: 35-installer-uninstaller-symmetry
reviewed: 2026-10-08T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - scripts/install_dkms.sh
  - packaging/debian/postinst
  - packaging/rpm/lenovo-d330-fix.spec
  - scripts/test_installer_symmetry.sh
  - scripts/test_storage_cellular.sh
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 35: Code Review Report

**Reviewed:** 2026-10-08
**Depth:** standard (light single pass)
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Diff `bd81a87..HEAD` adds a `deploy_manifest()` + `--verify [--root DIR]` mode, a shared `run_grub_regen()` called on both install and uninstall, an install-only prerequisite/EUID gate, all-9-unit enable parity across the three sites, narrow drop-in removal, named missing-package WARNs, and uninstall gap closure (state json, two unmasks, dracut branch). The 9-unit enable sets are exactly the 9 shipped units (no typo/dup), the drop-in removal is correctly narrowed, the dracut branch is guarded, and no broad `rm -rf` under `/etc/systemd` remains.

Live runs: `test_installer_symmetry.sh` 11/0, `test_hibernate_guards.sh` 21/0, `test_microsd_guards.sh` 26/0. `test_display_fix_guards.sh` cannot run in this Windows checkout because `core.autocrlf=true` materialized it as CRLF; the committed git blob is LF, so this is a local artifact, not a diff regression.

The central defect is that `--verify` treats every manifest entry as *required to exist*, while install deploys several entries only conditionally (state json, resume snippet 53, and optional-package files). On any machine missing an optional dependency, `--verify` reports DRIFT and exits non-zero after a legitimate install.

## Critical Issues

### CR-01: `--verify` requires conditionally-deployed artifacts, producing false DRIFT / non-zero after a legitimate install

**File:** `scripts/install_dkms.sh:940-965` (with manifest entries at `:96`, `:107`, `:110`, `:111`, `:112`, `:126-139`, `:140`)
**Issue:** `do_verify()` checks `-f` (or `-d`/exec) for every manifest entry regardless of kind. But several entries are only created conditionally by install and legitimately absent otherwise:
- `/etc/d330-hardware-state.json` (kind `state`): install **never** writes it; only `d330-ctl save` via `d330-hardware-state.service` ExecStop does. Install only enables the unit (`:518`), it never starts it, so after a real `--install` the file is absent → `--verify` on `/` prints `[DRIFT] /etc/d330-hardware-state.json (state): missing` and exits 1.
- `/etc/default/grub.d/53-lenovo-d330-resume.cfg` (`:106`): rendered only when hibernate activation succeeds (`:606-621`); when `d330-swapfile.service` fails to start, install logs WARN, skips activation, and completes successfully (`:538-544`), leaving 53 absent → DRIFT.
- `/etc/tlp.d/50-lenovo-d330.conf`, `/usr/share/color/icc/Lenovo-D330-sRGB-D65.icc`, `/etc/thermald/thermal-conf.xml`, `/etc/ModemManager/fcc-unlock.d/8086:7360`, `/etc/pipewire/...`, `/etc/xdg/autostart/d330-tray.desktop`, `/etc/X11/xorg.conf.d/...`: install copies each only when the target dir already exists, else it warns and skips (`:432-438`, `:696-711`, `:426-429`, `:486-488`, `:684-691`, `:381-386`). On a host without tlp/thermald/colord/pipewire/ModemManager those manifest entries are absent → each is reported as DRIFT.
- Additionally `unit-enabled` only tests `command -v systemctl` (`:907`): on a container/chroot/WSL with the binary but no running systemd, every unit reports DRIFT.

Net effect: `./scripts/install_dkms.sh --verify` fails on the very after-install state the plan promises will exit 0, defeating the phase's machine-checked-symmetry deliverable.
**Fix:** give conditional/runtime entries a kind the verifier skips (or checks only when present), e.g. add kinds `state` and `grub-snippet-optional` and `if [ "$kind" = state ] || [ "$kind" = file-optional ]` skip unless `-e`; and gate `unit-enabled` on systemd actually being PID 1 (`[ -d /run/systemd/system ]`). Example:
```bash
case "$kind" in
    state|file-optional|grub-snippet-optional)
        echo "  [SKIP] $path ($kind): conditional/runtime artifact"
        continue ;;
esac
```

## Warnings

### WR-01: SC1 "install→uninstall leaves nothing" is not machine-checked; the fixture test simulates the *installed* state only

**File:** `scripts/test_installer_symmetry.sh:164-170`
**Issue:** `case_verify_clean_passes` calls `populate_root` (creates every manifest entry) then asserts `--verify --root` exits 0 — this proves presence-checking works, i.e. it models a *populated/installed* tree. It never exercises an install followed by uninstall against a fixture, and `--verify` has no "expected absent/removed" direction. So the plan's claim that SC1 ("leaves no `*d330*` under /etc, /usr/local/bin, /usr/share/alsa") is machine-checked via a `--verify` fixture round trip is not true — the only behavioral test asserts the opposite condition.
**Fix:** either add a `--verify --removed` mode asserting entries are absent and use it after `populate_root && remove_all_manifest_entries`, or add a `verify-empty-after-removal` case that deletes the populated fixture and asserts exit 0 in removed-mode.

### WR-02: `deploy_manifest()` is not actually the single source; install/uninstall still hand-maintain duplicate lists

**File:** `scripts/install_dkms.sh:67-70` (claim) vs `:318-508` (install cp list) and `:751-820` (uninstall rm list)
**Issue:** The header asserts the manifest is "the authoritative inventory" and that do_install/do_uninstall were refactored to iterate it, but neither function consumes `deploy_manifest()`; they retain independent `cp`/`rm -f` lists. Only `do_verify` consumes the manifest. A file added to the manifest but not to install/uninstall (or vice versa) will pass every test and be undetected. The plan must_have "single source of truth" is not met.
**Fix:** iterate `deploy_manifest` in the removal path (or generate both lists from it), so manifest ↔ install ↔ uninstall cannot drift; at minimum add a suite case that asserts every non-manifest-only manifest path appears as a literal `cp ... /dest` target and every manifest path has a matching uninstall `rm`.

### WR-03: `manifest-single-source` drift guard is vacuous

**File:** `scripts/test_installer_symmetry.sh:118-131`
**Issue:** For each manifest entry the case does `grep -qF -- "$b" "$S"` where `$b` is the path basename. Because the manifest heredoc lives *inside* `$S`, every basename matches its own manifest line. The check can never fail for any entry actually in the manifest, so it detects no manifest↔deploy drift. (Verified: `grep -F lenovo-d330-i915.conf install_dkms.sh` matches the manifest line.)
**Fix:** grep for the deploy target, not the basename, e.g. assert `grep -qF "/dest/path" ` against the *install* body and a matching `rm -f /dest/path` in the uninstall body, or check that the destination appears on a line outside the `deploy_manifest()` heredoc.

### WR-04: unprivileged `--uninstall` prints a misleading success

**File:** `scripts/install_dkms.sh:1016-1023` and `:885`
**Issue:** Since the EUID check is skipped for `--uninstall` (intended for rescue shells) and every removal is `|| true`, running `--uninstall` as a non-root user whose writes all fail still reaches `log_ok "Uninstallation complete. System restored to baseline state."` (research R4). The operator is told the system was restored when nothing changed.
**Fix:** detect post-conditions (or missing root) and print an honest failure summary; e.g. if `[ "$EUID" -ne 0 ]` log a WARN that removals were skipped, or count remaining d330 artifacts and warn.

### WR-05: `--verify` unit check only probes for the `systemctl` binary, not a running systemd

**File:** `scripts/install_dkms.sh:906-917`
**Issue:** `[ "$root" = "/" ] && command -v systemctl` is the only gate; inside a chroot/container/WSL where `systemctl` exists but systemd is not PID 1, `systemctl is-enabled` returns non-`enabled` for every unit and `--verify` reports 9 DRIFTs / non-zero on an otherwise-correct install.
**Fix:** additionally require `[ -d /run/systemd/system ]` (or `systemctl is-system-running` success) before treating a unit as drift; otherwise `[SKIP]`.

## Info

### IN-01: `--dump-manifest` writes a human `[INFO]` line into the documented machine output

**File:** `scripts/install_dkms.sh:1021` (log emitted before `deploy_manifest`)
**Issue:** The help text documents `--dump-manifest` as printing `path<TAB>kind lines`, but the prereq-skip `log_info` line is emitted to stdout first, requiring consumers to filter (the suite's `dump_manifest` awk does). 
**Fix:** route the skip log to stderr for `dump-manifest`, or suppress it for read-only modes.

### IN-02: broad `rm -rf /usr/share/alsa/ucm2/sof-essx8336` remains

**File:** `scripts/install_dkms.sh:813`
**Issue:** Installer-owned subdir, but `rm -rf` deletes any foreign file placed there. Pre-existing and acknowledged by 35-RESEARCH (I29, lower risk) and out of the locked CONTEXT scope, but still an over-broad delete.
**Fix:** remove the installer-authored files explicitly and `rmdir` the subdir if empty.

### IN-03: doubled `[WARN] [WARN]` prefix on new warn lines

**File:** `scripts/install_dkms.sh:276`, `:437`, `:702`, `:710`
**Issue:** `log_warn` already emits a `[WARN]` tag, and the message strings also start with `[WARN]`, yielding `[WARN] [WARN] ...`. Cosmetic; matches a pre-existing pattern in the file.
**Fix:** drop the literal `[WARN] ` from the message strings.

### IN-04: local-only CRLF artifact makes `display_fix_guards` unrunnable on this checkout

**File:** `scripts/test_display_fix_guards.sh` (not in diff)
**Issue:** With `core.autocrlf=true` the working-tree copy is CRLF (279 CR / 279 LF) and bash aborts (`$'\r': command not found`), so `test_storage_cellular.sh --dry-run` fails locally. The committed git blob is LF (`git cat-file` CR=0), so Linux/CI is unaffected; recorded so it is not mistaken for a Phase 35 regression.
**Fix:** none required for this phase; add a `.gitattributes` (`*.sh text eol=lf`) if local runs matter.

---

## Class summary

- Correctness: **finding** — CR-01 (verify false DRIFT on conditional artifacts), WR-01, WR-02, WR-05.
- Security: **clean** — no broad `rm -rf` added, install root check retained (`:154-159` install-only gate, `:1016-1023`), removal scoped to d330 paths, no `eval`, all expansions quoted.
- Integration: **clean** — hibernate 21/0, microsd 26/0, display_fix 10/0 on LF checkout; harness wiring adds `test_installer_symmetry.sh` to the `bash -n` loop and delegate (`test_storage_cellular.sh:59,86`).
- Tests: **finding** — WR-03 (vacuous drift guard), WR-01 (no uninstall-direction case); `verify-clean-passes`/`verify-drift-detected` do exercise real `do_verify` behavior (non-vacuous).

Counts: Critical=1 Warning=5 Info=4

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
