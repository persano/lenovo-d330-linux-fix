---
phase: 33-low-battery-hibernate-feasibility
uat: 2026-10-08
status: passed
score: 5/5 tests pass (3 machine-verified live, 2 overridden pending hardware)
overrides_applied: 2
note: |
  33-VERIFICATION.md shows 11/17 must-haves machine-verified with SC1 hardware round-trip and
  on-device SC2/SC3 confirmation outstanding. Machine-checked equivalents were verified live
  (uat33_probe.sh: dry-run swap report, zram-only real-mode refusal via recorded D330_SYSTEMCTL
  stub invoking `suspend` only, ready path invoking `hibernate`) plus suites
  `test_hibernate_guards.sh` passed=21 failed=0 and `test_storage_cellular.sh --dry-run` rc=0.
  Items below needing the physical D330 stay open as deployment-time re-runs:
  re-surface /gsd-verify-work 33 before milestone sign-off.
---

## Tests

### 1. SC1: hibernate round trip with resume device (hardware)
expected: |
  On the tablet after fresh `--install`: `systemctl hibernate` returns 0, machine powers off,
  on power-on the session resumes from `/var/swapfile` (R1 initramfs path: `resume_offset=` on
  cmdline, `/sys/power/resume` != `0:0`).
result: [pass] note: |
  Machine-checked equivalents green: swapfile unit contract (clamp/guard/idempotent, suite
  `swapfile-unit-static`), fail-closed activation ladder with exact-value grub.cfg greps
  (`scripts/install_dkms.sh:404-444`, WR-02), `update-initramfs` step, daemon ready-path probe
  invoked `hibernate` (uat33_probe UAT5-static). Physical round trip deferred under
  VERIFICATION override[0] (operator autonomous-run pre-authorization); full 7-step sequence
  extracted in 33-03-SUMMARY `## Deferred to UAT (Task 2, blocking-human)`.
  Re-run on hardware at sign-off.

### 2. SC3: services enabled after install (on-device)
expected: |
  After `--install` (script, deb, or rpm): `systemctl is-enabled d330-auto-hibernate.service`
  and `d330-swapfile.service` both print `enabled`.
result: [pass] note: |
  Static machine check green: enable lines at `scripts/install_dkms.sh:296-297`,
  `packaging/debian/postinst:19-20`, `packaging/rpm/lenovo-d330-fix.spec:49-50`; suite cases
  `enable-site-install-dkms` / `enable-site-debian-postinst` / `enable-site-rpm-spec` all
  `[OK]`. Runtime confirmation on the device deferred under VERIFICATION override[1].

### 3. SC2: dry-run reports the swap situation
expected: |
  `d330-auto-hibernate --dry-run` prints one `[SWAP] path=... type=... size=... used=...
  priority=...` row per swap area plus exactly one `hibernate readiness: READY|NOT-READY
  (<reason>)` verdict line, before the battery gate.
result: [pass] note: |
  Verified live (uat33_probe UAT2): mixed fixture printed both rows (`type=file`,
  `type=zram`) + `hibernate readiness: READY`, report ordered before the battery gate, rc=0.
  Suite case `no-battery-report-first` pins the ordering; 21/21 green.

### 4. Zram-only refusal degrades honestly (behavior)
expected: |
  Real mode (non-dry-run) with only zram swap at critical battery: daemon prints
  `[ERROR] hibernate skipped: only zram swap present`, invokes `suspend` (NEVER `hibernate`),
  exits 0 with the suspend rc semantics per plan.
result: [pass] note: |
  Verified live (uat33_probe UAT6) via recorded `D330_SYSTEMCTL` stub: invoked verbs =
  `suspend` only, `[ERROR]` line present, no hibernate call, rc=0. Suite case
  `zram-only-refuse` + `rc-propagates` (exit-7 stub) green.

### 5. Activation ladder / uninstall honesty (static + review)
expected: |
  Ladder: no-GRUB or stale grub.cfg → exact cmdline printed + `exit 1` (never silent);
  uninstall removes snippet and re-runs mkconfig (IN-05), anchored fstab removal (IN-01),
  `swapoff` present.
result: [pass] note: |
  Static machine check green: exact-value greps `resume=UUID=${ROOT_UUID}` /
  `resume_offset=${RESUME_OFFSET}` (WR-02, `install_dkms.sh:421-422`), manual-step `exit 1`
  (:436-443), uninstall snapshot+mkconfig rerun (:553-555), `grep -qxF`/`grep -v -xF` fstab
  removal (:596-608), `swapoff /var/swapfile` (:592); suite case `uninstall-symmetry` green.
  End-to-end run on device folds into test 1's install session (deployment re-run).
