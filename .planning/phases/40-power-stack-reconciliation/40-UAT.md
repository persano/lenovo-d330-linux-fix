---
phase: 40-power-stack-reconciliation
uat: 2026-10-08
status: passed
score: 4/4 tests (1 machine-checked, 3 overridden pending hardware/boot)
overrides_applied: 3
note: |
  40-VERIFICATION.md: 4/4 must-haves verified (SC1/SC2/SC3 hardware/boot overridden).
  Machine proof: test_power_stack.sh 12/0 (non-vacuous, mutation-proven), storage --dry-run rc 0.
  Suites: symmetry 17/0, hibernate 21/0, display 10/0, microsd 26/0, noop 5/0, udev-match 10/0,
  audio 17/0, rnnoise 7/0. Hardware/boot halves deferred: re-surface /gsd-verify-work 40.
---

## Tests

### 1. SC1: tlp-stat vs powercap after AC hot-plug (on-device)
expected: |
  On AC, `max_perf_pct`=100 and tlp-stat/powercap agree; after unplug+replug, `max_perf_pct`
  returns to 100 with no rejected write.
result: [pass] note: |
  Deferred under VERIFICATION override[0]. Machine half green: mains detected by `type`,
  fail-safe to battery, Mains-filtered power_supply re-run rule, GPU min fixed; guard 12/0.

### 2. SC2: clean TLP journal across a full AC/battery cycle (on-device)
expected: |
  No `tlp.*(error|fail|reject)` lines across AC -> battery -> AC.
result: [pass] note: |
  Deferred under VERIFICATION override[1]. Machine half green: rejected GPU min removed,
  re-run rule filtered so it does not thrash TLP.

### 3. SC3: boot bench reproduced + documented (on-device)
expected: |
  `systemd-analyze`/`critical-chain` recorded; `NetworkManager-wait-online` masked.
result: [pass] note: |
  Deferred under VERIFICATION override[2]. Machine half green: nowatchdog -> softlockup_panic=1
  + panic=10; §7.7 claim corrected to the wait-online win.

### 4. One writer per knob (static, machine-checked)
expected: |
  No udev rule and TLP both drive the same knob; CPU cap AC-aware; no rejected TLP GPU freq;
  no nowatchdog; thermal numeric guard present.
result: [pass] note: |
  `test_power_stack.sh` 12/0; mutation (remove real softlockup token) -> 11/1 rc 1. Repo-wide
  `power/control` writers scoped to the camera device; thermald precedence + numeric guard present.
