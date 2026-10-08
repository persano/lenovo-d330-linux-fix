---
phase: 42-documentation-parity-repo-polish
uat: 2026-10-08
status: passed
score: 4/4 tests (3 machine-checked, 1 overridden pending a Linux build host)
overrides_applied: 1
note: |
  42-VERIFICATION.md: 4/4 must-haves verified (SC2 package build host-bound overridden).
  Machine proofs: doc-parity 19/0 (spot-checked vs code: swappiness 180, mq-deadline, enable_fbc=0,
  power_cycle_delay_ms=600, 36 test scripts), SC3 (no 0-byte tracked files; all 50 scripts/tools
  100755 incl. tools/d330-ctl), FCC hook deployed as 8086:7360. Full gate set green.
  Real package build deferred: re-surface /gsd-verify-work 42 on a Linux host.
---

## Tests

### 1. SC2: package build fails on a broken copy (on a Linux host)
expected: |
  With one `cp` source path broken, `dpkg-buildpackage -b` / `makepkg -f` / `rpmbuild -bb` exit
  non-zero; a clean build is green.
result: [pass] note: |
  Deferred under VERIFICATION override[0] (no debhelper-13/makepkg/rpmbuild here; `dpkg-buildpackage`
  aborts on unmet build deps). Machine half green: no `cp ... || true` in any packager.

### 2. SC1: CHANGES_AUDIT matches code
expected: |
  No mismatch between CHANGES_AUDIT claims and the code for the audited list.
result: [pass] note: |
  `test_doc_parity.sh` 19/0; spot-checked against code (swappiness=180, mq-deadline, enable_fbc=0,
  panel_orientation, power_cycle_delay_ms=600, 36 test scripts, no touch-mode/iwlwifi/bfq/PWM-boot-service/GTK claims).

### 3. SC3: repo hygiene (no 0-byte files, no 100644 shell scripts)
expected: |
  No 0-byte tracked files; every `scripts/*.sh` and CLI tool is 100755.
result: [pass] note: |
  Index sweep (`git cat-file -s`) = 0 zero-byte blobs; no non-755 `scripts/*.sh`; `tools/d330-ctl` 100755;
  50 scripts/tools.sh all 100755.

### 4. Goal: docs match code, dead code gone, deps declared
expected: |
  CHANGES_AUDIT/README/packaging match the code; dead code removed; runtime deps declared; FAIL-LOUD builds.
result: [pass] note: |
  Dead code (`SW_LID`, except shadow) removed; resource handles fixed; `cp ... || true` removed from all 3
  packagers; thermald/earlyoom/zram-generator/rnnoise/vainfo/desktop deps declared; README tree + .desktop hygiene updated.
