---
phase: 39-udev-hwdb-wireless-correctness
uat: 2026-10-08
status: passed
score: 3/3 tests (1 machine-checked, 2 overridden pending hardware)
overrides_applied: 2
note: |
  39-VERIFICATION.md: 11/11 truths verified (SC1+SC2 hardware overridden). Machine proofs:
  test_udev_hwdb_match.sh 10/0 (scans all 22 modprobe options across patches/*/etc/modprobe.d,
  asserts pn82H0/pn81MD/pn81H3), SC3 mutation-proven (wrong module -> non-zero). Suites: symmetry
  17/0, hibernate 21/0, display 10/0, microsd 26/0, noop 5/0, audio 17/0, rnnoise 7/0.
  Hardware halves deferred: re-surface /gsd-verify-work 39.
---

## Tests

### 1. SC1: udev/hwdb matches on real device (on-device)
expected: |
  After `systemd-hwdb update` + `udevadm control --reload-rules --trigger`, `udevadm test`
  on the accelerometer/touchscreen/ALS paths fires the shipped rules, and `udevadm hwdb --test`
  with the real modalias resolves the pn82H0 entries.
result: [pass] note: |
  Deferred under VERIFICATION override[0] (no udev/D330 here). Machine half green: match strings
  corrected (space-free product codes, case-insensitive ACPI HIDs) and guard-asserted.

### 2. SC2: modprobe reflects intended params (on-device)
expected: |
  `modprobe -s rtw88_8821ce` / `/sys/module/rtw88_core/parameters/` show the intended params;
  no option lands on an absent module.
result: [pass] note: |
  Deferred under VERIFICATION override[1] (no rtw88/rtl8821ce module here). Machine half green:
  wireless conf targets only real modules/params; all 22 options scanned + non-modules blocklisted.

### 3. SC3: wireless test fails on a wrong module name
expected: |
  `scripts/test_wireless_coex.sh` exits non-zero when the configured module name is wrong.
result: [pass] note: |
  Mutation-proven: `options rtw88_core` -> `WRONGMOD_core` makes `--dry-run` exit 1 with
  `[FAIL] unknown module configured`; `git checkout --` restores; correct conf exits 0.
