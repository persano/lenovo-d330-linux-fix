---
phase: 41-test-harness-trustworthiness
uat: 2026-10-08
status: passed
score: 3/3 tests pass (all machine-checked)
overrides_applied: 0
note: |
  41-VERIFICATION.md: 3/3 truths verified (roadmap SC1+SC2). All machine-checked under WSL bash.
  Meta-guard non-vacuous: 5 subjects broken -> scripts non-zero, restored byte-exact; SC2 flagged a
  synthetic ungated mutation. Suites: 17/0, 21/0, 10/0, 26/0, 5/0, 10/0, 12/0, audio 17/0, rnnoise 7/0.
  (Bare hardware probes test_touch_calibration.sh / test_mic_rnnoise.sh --probe are non-zero off-device by design.)
---

## Tests

### 1. SC1: a broken subject fails the run
expected: |
  Deliberately breaking the config/module a test checks makes that test exit non-zero.
result: [pass] note: |
  `test_harness_trust.sh` 9/0 (runs intact baseline first, so an always-failing script cannot pass).
  Independently: speaker conf -> test_audio_dsp.sh rc1; hwdb pn82H0 -> test_udev_hwdb_match.sh rc1;
  tray Exec -> test_tray_applet.sh rc1; all restored byte-exact, tree clean.

### 2. SC2: no test mutates the system without --apply
expected: |
  A `test_*.sh` performing `systemctl`/`fstrim`/`modprobe`/`nmcli radio`/sysfs writes must gate them
  behind `--apply`.
result: [pass] note: |
  Meta-guard SC2 static scan (structural gate on the mutating branch, not token presence) flags a
  synthetic ungated `systemctl restart` (rc1) and a neutralized `hardware_controls` gate (rc1). The 4
  mutating scripts gate real writes behind `--apply`; default run is read-only.

### 3. Goal: dry-run modes validate; harness is trustworthy
expected: |
  `--dry-run` modes validate something real; false `[OK]` for a missing subject is gone.
result: [pass] note: |
  `build_live_iso.sh --dry-run` validates real prereqs and fails when xorriso is absent; failure
  counters added across the listed scripts; `fcc-unlock`/cellular rules paths now FAIL when missing/empty;
  SCRIPT_DIR anchors make scripts CWD-independent; `bash -n` 0/40.
