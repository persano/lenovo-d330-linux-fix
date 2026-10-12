---
phase: 43
plan: 43-03
wave: 1
status: complete
commits:
  - 8b83932
  - 2e67597
requirements: [RECOV-02, RECOV-03]
---

# Plan 43-03 — Packaging + Manifest Symmetry

## What shipped

- `scripts/install_dkms.sh`:
  - `deploy_manifest()` gains exactly one TAB-separated state entry next to the existing state precedent: `/etc/default/lenovo-d330-display-resume` → kind `state`. No do_install copy action (state kind is a runtime artifact, created by neither install nor packagers; verify reports SKIP when absent).
  - `do_uninstall` gains the symmetric removal `rm -f /etc/default/lenovo-d330-display-resume`, adjacent to the existing state-json removal. Single source of truth maintained (no second artifact list).
- `packaging/debian/rules` — new system-sleep block: `mkdir -p` + `cp` of the hook + `chmod 755` (same explicit-permissions rationale as the /usr/local/bin block).
- `packaging/arch/PKGBUILD` — `install -d` + `install -m 755` with the explicit destination file path into `usr/lib/systemd/system-sleep`.
- `packaging/rpm/lenovo-d330-fix.spec` — `%install`: mkdir + cp + chmod 755; `%files`: the hook path as its own line (unpackaged buildroot files fail rpmbuild — Pitfall 4).
- `.github/workflows/build-packages.yml` — build-deb: `build/deb/usr/lib/systemd/system-sleep` added to the mkdir list, hook cp + chmod 755.
- No postinst/%post/.install changes (system-sleep hooks are plain executables; nothing to enable); no packager references the runtime state file (Pitfall 3 prohibition, machine-asserted).
- `scripts/test_installer_symmetry.sh` — extended 17 → 19 cases, all green:
  - `state-file-verify-symmetry`: populated fixture root → verify OK "present" for the state path; conditional root (state not populated) → SKIP "conditional/runtime artifact absent" and rc 0; `--removed` with the file present → non-zero + DRIFT "still present after uninstall"; state-kind manifest entries == 2 (grew by exactly one, Pitfall 5); uninstall body contains the removal.
  - `hook-packager-parity`: the hook source path, destination path, and an explicit `chmod 755`/`install -m 755` asserted in all four shippers (rules, spec, PKGBUILD, CI workflow); RPM `%install` and `%files` sections each carry the hook (awk section slices); the runtime state-file path is asserted absent from all four.
  - `manifest-deploy-consistency` tightened: state kinds skip the install-action check (by design) but the uninstall-removal requirement now covers them.

## Verification

- `bash -n scripts/install_dkms.sh` → exit 0.
- `bash scripts/test_installer_symmetry.sh` → `Guard suite summary: passed=19 failed=0`.
- Full harness chain deliberately NOT run in this wave-1 plan (43-04, wave 2, asserts it once).

## Deviations

- Executed inline by the orchestrator (subagent dispatch broken, disclosed at wave-1 start). Plan followed exactly; no worktree (ISOLATION=none milestone-wide).

## Requirements touched

- RECOV-02: hook ships from the installer, all three packagers, and the CI .deb with parity asserted; verify/uninstall symmetric for hook and state file.
- RECOV-03: state-kind semantics give re-run-safe install/uninstall and a manifest-tracked disable file (present-OK / absent-SKIP / drift-in-removed).
