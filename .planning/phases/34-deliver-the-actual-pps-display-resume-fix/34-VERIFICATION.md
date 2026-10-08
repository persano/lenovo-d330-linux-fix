---
phase: 34-deliver-the-actual-pps-display-resume-fix
verified: 2026-10-08T14:49:00Z
status: human_needed
score: 11/11 static must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification: false
deferred:
  - truth: "CHANGES_AUDIT.md §2.1 modprobe claim `fastboot=1, enable_fbc=1, enable_psr=0` matches the shipped modprobe.d file"
    addressed_in: "Phase 42"
    evidence: "ROADMAP Phase 42 / Audit M17 list: '§2.1 `enable_fbc=1` vs actual `0`'; shipped `patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf:8` is `options i915 enable_psr=0 enable_fbc=0` (no fastboot)."
behavior_unverified_items:
  - truth: "`dmesg | grep lenovo_d330_fix` shows a DMI match on the D330 hardware (SC1)"
    test: "Install Phase 34 assets on the D330, then `dmesg | grep lenovo_d330_fix`"
    expected: "A line such as `lenovo_d330_fix: [lenovo_d330_fix] Matched platform: Lenovo IdeaPad D330-10IGL`"
    why_human: "DMI strings are hardware-only; dev machine is Windows/WSL2 with no D330 and no loaded module. Static check proves the banner + DMI table are present and wired, not that the hardware matches."
  - truth: "`sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10` passes 5 real suspend/resume cycles (SC2)"
    test: "Run the real RTC-wake loop on the D330"
    expected: "`Passed: 5 / 5` with no i915 pipe-freeze/underrun lines"
    why_human: "WSL2 `/sys/power/state` is read-only and there is no DRM connector; the CI `--simulate` path proves arithmetic + reporting only, not real S3/S0ix behaviour."
human_verification:
  - test: "SC1 — DMI banner on hardware: `dmesg | grep lenovo_d330_fix`"
    expected: "A DMI-match banner line (e.g. `lenovo_d330_fix: [lenovo_d330_fix] Matched platform: Lenovo IdeaPad D330-10IGL`). If absent, try `lsmod | grep lenovo_d330_fix`, `modinfo lenovo_d330_fix`, `journalctl -k | grep lenovo_d330_fix`."
    why_human: "DMI match strings exist only on the real tablet."
  - test: "SC1 — breadcrumb honesty: suspend/resume once, then `dmesg | grep -Ei \"Enforcing TCON|lenovo_d330_fix\"`"
    expected: "Honest breadcrumb present; NO `Enforcing TCON discharge delay` false line."
    why_human: "Requires a real suspend/resume event."
  - test: "SC2 — real cycles: `sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10`"
    expected: "`Passed: 5 / 5` with no i915 pipe-freeze/underrun lines."
    why_human: "Needs root, writable `/sys/power/state`, DRM connector."
  - test: "Option 2 path (optional): `sudo ./scripts/install_dkms.sh --install --kernel-src /usr/src/linux`"
    expected: "Successful apply + `[OK]`, or the documented `[WARN]` context-mismatch path; never an install failure."
    why_human: "Needs a kernel source tree and root; the WARN path is the expected common case."
  - test: "Orientation sanity: confirm panel comes up correctly rotated (fbcon); BGRT logo not distorted."
    expected: "Correct rotation and no distorted logo after reboot."
    why_human: "Visual behaviour, hardware-only."
---

# Phase 34: Deliver the Actual PPS / Display Resume Fix — Verification Report

**Phase Goal:** The recommended install path must produce the 600 ms panel power-cycle clamp and the DMI orientation quirk it advertises, or stop advertising them.
**Verified:** 2026-10-08T14:49:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

The phase chose the honest branch of the goal: it stopped advertising a clamp the out-of-tree module cannot deliver, deleted the echo-only resume service, and made the Option 2 kernel patch the only clamp delivery path, gated by `patch -p1 --dry-run`. Every machine-checkable claim was re-run independently and holds. SC1 and SC2 remain hardware-gated (same deferred-to-UAT pattern as Phases 32/33).

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1 static: module prints a DMI-matched banner (`d330_info`) and `MODULE_DEVICE_TABLE(dmi` is intact | ✓ VERIFIED | `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:60-61,96,145,149,159`; suite case `module-banner-no-dead-sleep` [OK] |
| 2 | SC1 static: dead `elapsed_ms < ... power_cycle_delay_ms` branch and `msleep` gone; no false "Enforcing TCON" line | ✓ VERIFIED | grep: dead-branch ABSENT, `msleep` ABSENT, `Enforcing TCON` ABSENT; `.c:110-124` is an honest breadcrumb |
| 3 | SC2 CI half: `test_resume_loop.sh --simulate --cycles 5` → `Passed: 5 / 5`, rc=0 | ✓ VERIFIED | raw run below: `Test Summary: Passed: 5 / 5, Failed: 0 / 5`, `rc=0` |
| 4 | SC2 arithmetic blocker gone: no `((passed++))`/`((failed++))`; `passed=$((passed + 1))` present | ✓ VERIFIED | `scripts/test_resume_loop.sh:107,154` (`passed=$((passed + 1))`), `:124,151` (`failed=$((failed + 1))`); `grep -c` = 0; only `++` is `for ((i...i++))` at `:98` |
| 5 | SC3: README has no guarantee / module-enforcement claim; Option 1 vs Option 2 accurate | ✓ VERIFIED | `README.md:35` module row "does NOT enforce TCON discharge timing"; `:67-73` Option 1 "does **not include** the 600 ms panel power-cycle clamp"; `:75-91` Option 2 `--kernel-src`; `grep "will now work reliably"` ABSENT; `:106` keeps `dmesg | grep lenovo_d330_fix` |
| 6 | `lenovo-d330-resume.service` deleted; zero stale refs in scripts/packaging/CHANGES_AUDIT/README/patches-README | ✓ VERIFIED | unit file ABSENT (`patches/dkms/etc/systemd/system/` empty); zero-ref sweep "ZERO REFS (ok)". `CHANGES_AUDIT.md:38,41` now state REMOVED |
| 7 | `--kernel-src` step: `patch -p1 --dry-run` FIRST, warn (never fail) on mismatch | ✓ VERIFIED | `scripts/install_dkms.sh:85-145`; dry-run `:121`, real apply `:137` (121<137); mismatch returns 0 with `[WARN]` `:123-128`; invoked `:173-178`; arg guard `:743-748` |
| 8 | `dkms.conf` carries `BUILT_MODULE_LOCATION[0]="."`, `MAKE_MATCH[0]`, `BUILD_EXCLUSIVE_KERNEL[0]` | ✓ VERIFIED | `patches/dkms/lenovo-d330-fix/dkms.conf:8,9,13` |
| 9 | `video=efifb:nobgrt` KEPT + both `panel_orientation` tokens; CHANGES_AUDIT §2.2 cfg claim matches shipped string | ✓ VERIFIED | `50-lenovo-d330-boot.cfg:10`; CHANGES_AUDIT.md:50 quoted string is byte-identical to shipped cmdline |
| 10 | Existing gates stay green (hibernate 21/0, storage-cellular --dry-run rc=0) | ✓ VERIFIED | raw tails below |
| 11 | Review fixes f0aa35b..a670c01 landed (README row CR-01, audit §2.1, module param, non-vacuous ordering assert, `--forward` drop, readme-truth strengthening, patches README literal, CLI guards) | ✓ VERIFIED | `git log --oneline f0aa35b..a670c01` = 8 commits; effects confirmed in code (see Anti-Patterns/evidence) |

**Score:** 11/11 static must-haves verified (2 hardware items pending — see Human Verification)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | CHANGES_AUDIT §2.1 modprobe claim `fastboot=1, enable_fbc=1` vs shipped `enable_psr=0 enable_fbc=0` | Phase 42 | ROADMAP Phase 42 / Audit M17 explicitly lists this contradiction |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c` | honest DMI banner, no dead clamp | ✓ VERIFIED | 175 lines; banner + DMI table intact; dead branch/msleep removed |
| `patches/dkms/lenovo-d330-fix/dkms.conf` | three build guards | ✓ VERIFIED | 15 lines; guards at :8,:9,:13 |
| `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` | deleted | ✓ VERIFIED | absent; directory empty |
| `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg` | nobgrt kept + 2 tokens | ✓ VERIFIED | :10 |
| `scripts/install_dkms.sh` | `--kernel-src` dry-run-first step | ✓ VERIFIED | :77-145, :173-178, :743-748 |
| `scripts/test_resume_loop.sh` | arithmetic fixed + `--simulate` | ✓ VERIFIED | :49-70 guards, :107/:124 counters, simulate path |
| `scripts/test_display_fix_guards.sh` | 10-case static suite | ✓ VERIFIED | `passed=10 failed=0` |
| `README.md` | truthful options | ✓ VERIFIED | :35,:54-91 |
| `CHANGES_AUDIT.md` | §2.1 banner-only + §2.2 cfg match | ✓ VERIFIED | :34,:36,:38,:41,:46,:50 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `install_dkms.sh:174` | `run_kernel_src_step:85` | `[ -n "${KERNEL_SRC:-}" ]` guard | ✓ WIRED | only runs with `--kernel-src` |
| `run_kernel_src_step:121` | `patch -p1 --dry-run` | order before apply `:137` | ✓ WIRED | dry=121 < apply=137; suite case `kernel-src-dryrun-first` non-vacuous |
| `install_dkms.sh` | `patches/d330_display_resume_fix.patch` | `patch_file` :87 | ✓ WIRED | path from `REPO_ROOT` |
| `lenovo_d330_fix.c:96` | DMI autoload | `MODULE_DEVICE_TABLE(dmi,...)` | ✓ WIRED | plate table present |
| `test_storage_cellular.sh --dry-run` | `test_display_fix_guards.sh` + `test_hibernate_guards.sh` | delegation | ✓ WIRED | both suites run under the harness |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| SC2 simulate 5 cycles | `bash scripts/test_resume_loop.sh --simulate --cycles 5` | `Test Summary: Passed: 5 / 5, Failed: 0 / 5`; rc=0 | ✓ PASS |
| Display-fix static suite | `bash scripts/test_display_fix_guards.sh` | `passed=10 failed=0` | ✓ PASS |
| Hibernate guard suite | `bash scripts/test_hibernate_guards.sh` | `passed=21 failed=0` | ✓ PASS |
| Storage/cellular dry-run + delegation | `bash scripts/test_storage_cellular.sh --dry-run` | `passed=26 failed=0`; delegates 10+21; rc=0 | ✓ PASS |
| Real suspend/resume + hardware dmesg | (needs D330) | not runnable on WSL2 | ? SKIP → human |

Raw tails (re-run independently this session):

```
=== SC2 simulate ===
 Test Summary: Passed: 5 / 5, Failed: 0 / 5
rc=0
=== arithmetic blocker grep (only ++ is the for-loop) ===
0
98:for ((i = 1; i <= CYCLES; i++)); do
=== fixed idiom lines ===
107:        passed=$((passed + 1))
154:        passed=$((passed + 1))
124:        failed=$((failed + 1))
151:        failed=$((failed + 1))

=== display_fix_guards ===
  [OK] module-banner-no-dead-sleep
  [OK] resume-service-deleted-zero-refs
  [OK] kernel-src-dryrun-first
  [OK] nobgrt-kept
  [OK] panel-orientation-present
  [OK] audit-claims-match-cfg
  [OK] dkms-build-guards
  [OK] resume-loop-arithmetic-fixed
  [OK] resume-loop-simulate-5
  [OK] readme-truth
 Guard suite summary: passed=10 failed=0

=== hibernate_guards ===
 Guard suite summary: passed=21 failed=0

=== storage_cellular --dry-run ===
 [OK] bash -n scripts/test_display_fix_guards.sh
 Guard suite summary: passed=26 failed=0
 (delegates) Display Fix: passed=10 failed=0 ; Hibernate: passed=21 failed=0
 [OK] dry-run verification complete
rc=0
```

### Probe Execution

No phase-declared `probe-*.sh` exist; this phase's machine checks are the guard suites above.

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| (none declared) | — | — | N/A |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| SC1 | 34-01 | `dmesg \| grep lenovo_d330_fix` DMI match | ✓ SATISFIED (static) / ? HUMAN (hardware) | banner + DMI table present; live run deferred |
| SC2 | 34-01 | `test_resume_loop.sh` passes 5 cycles | ✓ SATISFIED (CI simulate) / ? HUMAN (real cycles) | `Passed: 5 / 5` simulate |
| SC3 | 34-01 | README claims match behaviour | ✓ SATISFIED | README accurate; §2.1/§2.2 enforcement claims corrected |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `CHANGES_AUDIT.md` | 51 | §2.2 claims `ACCEL_MOUNT_MATRIX=0, 1, 0; 1, 0, 0; 0, 0, -1` but shipped `61-lenovo-d330-sensor.hwdb:8,12,16` is `0, 1, 0; -1, 0, 0; 0, 0, 1` | ⚠️ WARNING | Non-enforcement doc mismatch in §2.2; not a phase must-have, and not listed in the ROADMAP M17 set. README:40 quotes the shipped value correctly |
| `CHANGES_AUDIT.md` | 53 | §2.2 claims DMI glob `pn81H3*`; shipped hwdb has no `pn81H3` pattern (uses `pvrLenovoideapadD330-10IGM`) | ⚠️ WARNING | Same class: residual doc/glob drift, not a phase must-have |
| `CHANGES_AUDIT.md` | 34 | §2.1 claims modprobe `fastboot=1, enable_fbc=1`; shipped is `enable_psr=0 enable_fbc=0` | ℹ️ DEFERRED | Explicitly owned by Phase 42 (Audit M17) |

No debt markers (`TBD`/`FIXME`/`XXX`) in phase-modified files. No false "Enforcing TCON" line in the module.

### Human Verification Required

**1. SC1 — DMI banner on hardware**
- **Test:** after install, `dmesg | grep lenovo_d330_fix`
- **Expected:** a DMI-match banner line.
- **Why human:** DMI strings exist only on the tablet.

**2. SC1 — breadcrumb honesty**
- **Test:** suspend/resume once, then `dmesg | grep -Ei "Enforcing TCON|lenovo_d330_fix"`
- **Expected:** honest breadcrumb, no `Enforcing TCON discharge delay` line.
- **Why human:** needs a real suspend/resume event.

**3. SC2 — real cycles**
- **Test:** `sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10`
- **Expected:** `Passed: 5 / 5`, no i915 pipe-freeze/underrun.
- **Why human:** root + writable `/sys/power/state` + DRM connector.

**4. Option 2 — kernel patch path (optional)**
- **Test:** `sudo ./scripts/install_dkms.sh --install --kernel-src /usr/src/linux`
- **Expected:** `[OK]` apply or the documented `[WARN]` mismatch path; never a failure.
- **Why human:** requires a kernel source tree.

**5. Orientation sanity**
- **Test:** after reboot, check fbcon rotation and BGRT logo.
- **Expected:** correct rotation, no distorted logo.
- **Why human:** visual.

### Gaps Summary

No must-have truth failed. All 11 machine-checkable truths verified, all four gate suites green, zero stale resume-service references, and review fixes f0aa35b..a670c01 are present with their effects confirmed.

Residual (non-blocking): `CHANGES_AUDIT.md` §2.2 still carries two stale claims (accelerometer matrix at `:51`, `pn81H3*` glob at `:53`) that do not match the shipped hwdb. These are documentation-parity defects outside this phase's declared must-haves and, unlike the §2.1 `enable_fbc` contradiction, are not explicitly listed in the ROADMAP M17/Phase 42 set — they should be folded into Phase 42 doc parity. They are not enforcement claims, so they do not reintroduce the audit's false-advertising root cause.

Token for the goal: the phase stopped advertising what it cannot deliver and made the Option 2 patch the sole clamp path. No broken enforcement promise found.

---

_Verified: 2026-10-08T14:49:00Z_
_Verifier: the agent (gsd-verifier)_
