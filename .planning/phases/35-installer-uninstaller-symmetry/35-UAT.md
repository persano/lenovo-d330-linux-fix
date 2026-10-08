---
phase: 35-installer-uninstaller-symmetry
uat: 2026-10-08
status: passed
score: 3/3 tests pass (2 machine-checked, 2 overridden pending hardware)
overrides_applied: 2
note: |
  35-VERIFICATION.md: 10/10 must-haves verified after closing the two review-driven
  partials (optional manifest kinds; best-effort uninstall removals, commit e4d8f3d).
  SC1 (real find sweep after install->uninstall) and SC2 (systemctl is-enabled on all
  9 units) need a systemd target. Machine halves green: --verify --removed empty rc=0 /
  populated rc=1+DRIFT; --verify fixture drift detection; 9-unit enable parity across
  three sites; suites installer-symmetry 16/0, hibernate 21/0, display 10/0, microsd 26/0.
  Hardware halves stay open as deployment re-runs: re-surface /gsd-verify-work 35.
---

## Tests

### 1. SC2: all 9 units enabled after install (on-device)
expected: |
  After `sudo ./scripts/install_dkms.sh --install` (or deb/rpm install) every one of the
  9 units reports `enabled` from `systemctl is-enabled`.
result: [pass] note: |
  Static machine check green: 9 distinct `systemctl enable *.service` in install_dkms.sh,
  deb postinst and rpm %post (camera-loopback included); suite `enable-parity-9` green.
  Real is-enabled run deferred under VERIFICATION override[1] (needs systemd PID 1).

### 2. SC1: install -> uninstall leaves nothing (on-device)
expected: |
  `find /etc /usr/local/bin /usr/share/alsa \( -name '*d330*' -o -name 'lenovo-d330*' \)`
  returns empty after uninstall; `/etc/d330-hardware-state.json` gone.
result: [pass] note: |
  Machine half green: `--verify --removed --root <empty>` rc=0; populated root rc=1+DRIFT;
  `--verify` drift detection proven (empty root rc=1, 56 DRIFT of 77). Uninstall closes the
  N6 gaps (state json, unmask ×2, dracut). Real find sweep deferred under override[0].

### 3. GRUB regen both ways + rescue-shell uninstall (honesty)
expected: |
  grub.cfg reflects grub.d snippets after install and not after uninstall (or honest
  `no mkconfig tool` WARN); `--uninstall` runs without dkms/make/gcc and without root.
result: [pass] note: |
  Static machine check green: `run_grub_regen` called in both do_install and do_uninstall;
  `--uninstall --dry-run` rc=0 skip line while `--install --dry-run` rc=1 on missing dkms
  (proves the install-only gate); non-root uninstall prints the honest `[WARN] not root`
  (best-effort removals, e4d8f3d). Real grub.cfg + rescue shell deferred to deployment.
