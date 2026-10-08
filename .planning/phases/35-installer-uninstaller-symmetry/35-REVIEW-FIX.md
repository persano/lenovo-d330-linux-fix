---
phase: 35-installer-uninstaller-symmetry
fixed_at: 2026-10-08T15:35:38Z
review_path: .planning/phases/35-installer-uninstaller-symmetry/35-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 35: Code Review Fix Report

**Fixed at:** 2026-10-08T15:35:38Z
**Source review:** .planning/phases/35-installer-uninstaller-symmetry/35-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (CR-01, WR-01..WR-05, IN-01, IN-02)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: `--verify` requires conditionally-deployed artifacts, producing false DRIFT / non-zero after a legitimate install

**Files modified:** `scripts/install_dkms.sh`
**Commit:** e42e1ba
**Applied fix:** Added conditional-artifact manifest kinds. `53-lenovo-d330-resume.cfg` is now `grub-snippet-optional`; the conditional package copies (`ModemManager` `exec-optional`; tlp, icc, thermald, xdg autostart, pipewire x2 as `file-optional`); X11 copies `file-optional`. `do_verify` treats `state|file-optional|exec-optional|grub-snippet-optional` as present=OK / absent=SKIP (never DRIFT). `unit-enabled` is gated on `[ -d /run/systemd/system ]` (see WR-05). New regression case `verify-conditional-absent` proves a required-only fixture exits 0 with a `conditional/runtime artifact absent` SKIP.

### WR-05: `--verify` unit check only probes for the `systemctl` binary, not a running systemd

**Files modified:** `scripts/install_dkms.sh`
**Commit:** e42e1ba (implemented once with CR-01)
**Applied fix:** The `unit-enabled` branch now additionally requires `[ -d /run/systemd/system ]`; otherwise the entry reports `[SKIP] ... systemd not PID 1` instead of 9 false DRIFTs on a chroot/container/WSL.

### WR-01: SC1 "install→uninstall leaves nothing" is not machine-checked

**Files modified:** `scripts/install_dkms.sh`, `scripts/test_installer_symmetry.sh`
**Commit:** 1387326 (installer), 68f8940 (suite)
**Applied fix:** Added `--verify --removed` to `install_dkms.sh` (new `--removed` flag threaded as `do_verify`'s 2nd arg). In removed mode every manifest path must be ABSENT: `[ -e ]/[ -d ]` present => `[DRIFT]`; `unit-enabled` requires not-enabled; `fstab-line` requires absent. Suite case `verify-removed-direction` proves empty root => rc 0 and populated root => non-zero + DRIFT.

### WR-02: `deploy_manifest()` is not actually the single source; install/uninstall still hand-maintain duplicate lists

**Files modified:** `scripts/test_installer_symmetry.sh`
**Commit:** 68f8940
**Applied fix:** Added suite case `manifest-deploy-consistency` (the low-risk option). It strips the `deploy_manifest()` heredoc from the installer body, then for every deployed manifest path asserts a matching `do_install` deploy action (basename present in the install body) AND a matching `do_uninstall` removal action (full destination present in the uninstall body). Two documented exceptions: the variable-expanded `/usr/src/<pkg>` staging dir (`DEST_SRC`) and the dir-glob earlyoom drop-in (`earlyoom.service.d`). A mutation test (deleting one `rm -f /usr/local/bin/d330-tray`) is detected.

### WR-03: `manifest-single-source` drift guard is vacuous

**Files modified:** `scripts/test_installer_symmetry.sh`
**Commit:** 68f8940
**Applied fix:** The case now matches basenames against `strip_manifest` (the installer body with the `deploy_manifest()` heredoc removed) instead of the raw file, so the manifest heredoc can no longer satisfy its own check. Uses `case` substring matching (a `printf | grep -q` pipeline trips `set -o pipefail` via SIGPIPE and was itself a false-negative source).

### WR-04: unprivileged `--uninstall` prints a misleading success

**Files modified:** `scripts/install_dkms.sh`
**Commit:** 884de6f
**Applied fix:** `do_uninstall` records `UNINSTALL_SKIPPED_NONROOT` when `[ "$EUID" -ne 0 ]` and `DRY_RUN=false`; the final line is now `[DRY-RUN] ... simulated`, else `[WARN] not root - removals were skipped; re-run as root to restore baseline state.`, and only the root path prints the success line. Static guard `uninstall-nonroot-warn` added.

### IN-01: doubled `[WARN] [WARN]` prefixes

**Files modified:** `scripts/install_dkms.sh`
**Commit:** 77c9c8a
**Applied fix:** Removed the literal leading `[WARN] ` from every `log_warn` message in the installer (29 calls inspected; `log_warn` already emits the tag). No doubled prefix remains (`rg '"\[WARN\]'` => no match).

### IN-02: broad `rm -rf /usr/share/alsa/ucm2/sof-essx8336`

**Files modified:** `scripts/install_dkms.sh`
**Commit:** 47d0f9f
**Applied fix:** Replaced the broad delete with a guarded, installer-owned removal: `if [ -d ... ]; then rm -f .../sof-essx8336.conf .../HiFi.conf; rmdir ... 2>/dev/null || true; fi`, with a comment that foreign files must survive. Static guard `no-broad-ucm-rm-rf` asserts the broad form is gone and the empty-only `rmdir` is present.

## Out of scope (not in the fix-scope list)

- Review IN-01 (`--dump-manifest` emits a human `[INFO]` line to stdout) and IN-04 (local CRLF artifact) were not in the task's FINDINGS list and were left untouched; the suite's `dump_manifest` awk guard already filters the `[INFO]` line.

## Verification

Ran in the main checkout under WSL (`core.autocrlf=true`; `test_display_fix_guards.sh` and `test_resume_loop.sh` were temporarily LF in the working tree to run, then restored to their original CRLF so no EOL-only dirt remains).

- `bash scripts/test_installer_symmetry.sh` => `passed=16 failed=0` (was 11 cases; +5 new)
- `bash scripts/test_hibernate_guards.sh` => `passed=21 failed=0` (phase-33 ladder + literal cp/rm greps intact)
- `bash scripts/test_display_fix_guards.sh` => `passed=10 failed=0`
- `bash scripts/test_storage_cellular.sh --dry-run` => rc=0 (microsd 26/0, display 10/0, hibernate 21/0, installer 16/0)
- `bash -n scripts/install_dkms.sh scripts/test_installer_symmetry.sh scripts/test_storage_cellular.sh` => rc=0

`git status --porcelain` shows only pre-existing untracked planning files and the pre-existing `AUDIT_PROMPT.md` deletion; no modified tracked file and no EOL-only dirt.

---

_Fixed: 2026-10-08T15:35:38Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
