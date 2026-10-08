---
phase: 32-data-loss-boot-safety-guards
verified: 2026-10-08T06:55:25Z
status: human_needed
score: 18/18 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Real-hardware mounted-target abort: insert a MicroSD, mount one of its partitions, run `sudo tools/d330-microsd-setup.sh --format --device /dev/mmcblk1`"
    expected: "Tool aborts at `[GUARD] mountpoints: FAIL (mounted at: ...)` before parted runs; card contents untouched (roadmap SC1 manual row, VALIDATION Manual-Only)"
    why_human: "Destructive path on real hardware; shim suite proves abort-before-write with a canary, but no real card was ever written (non-root dev box, no card inserted)"
  - test: "On-target fstab boot-safety: run `--mount-data --device /dev/mmcblk1` on the tablet with the card inserted, then `findmnt --verify` the real /etc/fstab line and `systemd-analyze verify --recursive-errors=yes` on the generated .mount unit"
    expected: "0 parse errors on the real entry; the card-absent boot case degrades via `nofail` + `x-systemd.device-timeout=10s` instead of an emergency shell (roadmap SC2 manual row)"
    why_human: "Dev machine cannot resolve the fake UUID (`unreachable on boot required source` WARN); the parse proof on this box covers the generated .mount unit and a resolvable-source candidate only, never the real /etc/fstab"
  - test: "WR-01/WR-03 failure branches (32-REVIEW-FIX.md flagged): run `--mount-data` with an unreadable fstab (awk read error) and force a grep/mv failure inside `rollback_fstab_line`"
    expected: "Unreadable fstab fails closed with `[ERR] Could not read ...`; a failed rollback prints `[ERR] Rollback FAILED: ...` and never truncates fstab, never claims success"
    why_human: "Control-flow failure branches with no test coverage — explicitly flagged for human review by the code-review fix report (commit acb9b23-era, REVIEW-FIX line 110)"
---

# Phase 32: Data-Loss & Boot Safety Guards Verification Report

**Phase Goal (ROADMAP):** Eliminate the two paths that can destroy the eMMC root filesystem or hang systemd at boot.
**Verified:** 2026-10-08T06:55:25Z (HEAD = `fc2dac6`, includes review fixes 05687e7/0bc62de/d4c2dcf/acb9b23)
**Status:** human_needed (all automated checks pass; 3 real-hardware / failure-branch items need a human)
**Re-verification:** No — initial verification (no prior VERIFICATION.md)

## Goal Achievement

### Roadmap Success Criteria (contract — non-negotiable)

| #   | Success Criterion                                        | Status     | Evidence                                                                                                                                                                                        |
| --- | -------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SC1 | `--format` on a device with a mounted partition aborts before any write | ✓ VERIFIED | Live run: `bash scripts/test_microsd_guards.sh` → `mounted-target-abort` OK — shim reports `MOUNTPOINT=/mnt/data`, tool exits non-zero at `[GUARD] mountpoints: FAIL`, **parted canary never created**; code `tools/d330-microsd-setup.sh:336` guard precedes `:347` parted |
| SC2 | fstab line parses under `systemd-analyze verify`          | ✓ VERIFIED | Live run: `fstab-parse-proof` OK — real `findmnt --verify --tab-file` reports `0 parse errors` (only environmental `unreachable` WARN), real `systemd-analyze verify ./data.mount --recursive-errors=yes` rc=0; install-time gate `findmnt --verify` before append at `:445-455` |
| SC3 | `--dry-run` prints the guard outcomes                     | ✓ VERIFIED | Live run: `dry-run-guard-pass-report` / `dry-run-guard-fail-report` OK — one `[GUARD] <name>: PASS\|FAIL` line per guard; FAIL run aborts with `Dry-run aborted: N guard(s) FAILED.` before `[DRY-RUN] parted` (asserted absent); mount-data dry-run: `guard_lines=2` + locked options string present (extra probe this session) |

**Score:** 3/3 roadmap SCs verified.

### Plan Must-Have Truths (32-01 / 32-02 / 32-03 frontmatter)

| ID  | Claim (abbreviated)                                                                                            | Status     | Evidence (machine-checked this session)                                                                                          |
| --- | -------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 01-1 | `--format` without `--device` exits 1 with usage text before guard/prompt/write                                 | ✓ VERIFIED | Suite `missing-device-format`: rc=1 + `requires an explicit --device` + `Usage:`; code `require_device_for_action` at `:249` immediately after parse, before all guards (`:336+`) and stub/precondition |
| 01-2 | Dry-run prints one `[GUARD]` line per each of 3 guards; FAIL aborts without planned commands                    | ✓ VERIFIED | `dry-run-guard-fail-report` + `dry-run-guard-pass-report` green; `expect_no_out "[DRY-RUN] parted"` on FAIL run; report mode `:312-319` evaluates all 3 guards before aborting               |
| 01-3 | Shim-mounted target → non-dry-run `--format` exits non-zero at mountpoints guard, parted canary never created   | ✓ VERIFIED | `mounted-target-abort` green (rc≠0, FAIL line, `expect_no_canary`) — behavioral test passed live                               |
| 01-4 | Root-device refusal fires in both prefix directions (root longer AND root shorter than target)                  | ✓ VERIFIED | `root-refusal-target-is-prefix` + `root-refusal-source-is-prefix` + `root-refusal-equal` all green; code `:122-133` both `case` directions |
| 01-5 | Sysfs scan never reassigns `TARGET_DEV`; `--probe` exits 0 without `--device`, scan informational only          | ✓ VERIFIED | `probe-regression` green (rc=0, no `--device`); `TARGET_DEV=` assignments only at `:73` (probe invalid-value reset), `:222` (default), `:240` (parser) — none in scan loop; adoption string `Found secondary SD card` absent |
| 01-6 | No mkfs force flag; `partprobe` + `udevadm settle` instead of fixed sleep                                       | ✓ VERIFIED | Greps: `mkfs.ext4 -F` → none; `sleep 1` → none; straight-line ordering `parted :347 → partprobe :348 → udevadm :349 → mkfs :355`; `dry-run-guard-pass-report` asserts `[DRY-RUN] partprobe` and `expect_no_out "mkfs.ext4 -F"` |
| 02-1 | fstab line carries exactly `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s` (locked string)    | ✓ VERIFIED | `build_fstab_line :191` exact string; `mount-data-append-success` asserts the **exact full line** in the written temp fstab; source grep count=3 (builder + refusal message + sed remediation) |
| 02-2 | `mkdir -p` before proof; `findmnt --verify` before append; failing proof aborts without touching fstab          | ✓ VERIFIED | Code order `mkdir :434 → verify :445 → append :457`; behavioral: `mount-data-verify-fails-aborts` green — rc≠0, `failed verification` message, **fstab line count = 0**                     |
| 02-3 | Mount failure after append → rollback trap removes line, exits non-zero, no success message                     | ✓ VERIFIED | `mount-data-mount-fail-rollback` green: `D330_SHIM_MOUNT_RC=32` → rc≠0, fstab count back to 0, both rollback messages, `expect_no_out "Storage expansion task complete."` (behavioral)       |
| 02-4 | Duplicate UUID: refuse re-append, verify existing options, refuse legacy missing `nofail`, never silently migrate | ✓ VERIFIED | `mount-data-duplicate-legacy-refuses` (rc≠0, actionable `nofail,x-systemd.device-timeout=10s` message, file untouched) + `mount-data-duplicate-good-noop` (rc=0, `already present`, count=1); WR-01 fix: exact first-field `awk '$1==u'` at `:414/:419` |
| 02-5 | Dry-run `--mount-data` prints guard outcomes + planned append with exact locked options                          | ✓ VERIFIED | `mount-data-dry-run-options` green (exact append line asserted) + extra probe this session: `guard_lines=2` (root-device + confirm — the guards this path owns), `LOCKED_OPTS_IN_DRYRUN=yes`, `SUCCESS_LEAK=no` |
| 02-6 | Suite proves fstab line with `findmnt --verify --tab-file` (`0 parse errors`, environmental WARN only, strict rc-0 on resolving source) + `systemd-analyze verify`, never real `/etc/fstab` | ✓ VERIFIED | `case_fstab_parse_proof :550-622` live green: WARN classification emitted exactly as designed; resolved-source candidate strict rc-0 asserted; `systemd-analyze --recursive-errors=yes` rc=0; all writes via `D330_FSTAB` seam (`:361`) into `$TAB_DIR` |
| 03-1 | `--mount-home` exits non-zero with clear "not implemented", no success message, `--help` marks unsupported      | ✓ VERIFIED | `mount-home-missing-device`, `mount-home-not-implemented`, `help-marked-unsupported` all green; stub at `:258-261` (immediately after `require_device_for_action`), help row `:31` `(unsupported: not implemented)` |
| 03-2 | Success message reachable only from genuinely completed real actions; exactly one source occurrence             | ✓ VERIFIED | `grep -c 'Storage expansion task complete.'` → **1** (`:471`); `completion-honesty` green over 3 negative paths (format dry-run, mount-data dry-run, stub) + duplicate-noop/rollback/refusal cases all assert absence; positive `mount-data-append-success` asserts presence. Format-real positive direction reachable only after the write path completes (manual row → human item 1) |
| 03-3 | `--help` documents `--device` and marks `--mount-home` unsupported                                              | ✓ VERIFIED | `help-marked-unsupported` green (`--device` present, `mount-home.*unsupported` regex matched); help rows `:31-34` |
| 03-4 | `test_storage_cellular.sh --dry-run` really runs `bash -n` gates + guard suite instead of echoing paths          | ✓ VERIFIED | Live run: 3× `[OK] bash -n ...` + full 26-case suite + `[OK] dry-run verification complete`, rc=0; source `:59-70` per-file gates + plain suite delegation under `set -euo pipefail` (`:5`) → failure propagates |
| 03-5 | `--probe` and `--test-microsd` keep passing (existing smoke regression)                                        | ✓ VERIFIED | Live: `PROBE_RC=0`, `TESTMICROSD_RC=0`; `git diff 037424d..HEAD -- scripts/test_storage_cellular.sh` shows **zero** changes to the probe/test-microsd branch (`PROBE_BRANCH_UNCHANGED`) |
| 03-6 | Full guard suite covers all three SCs end-to-end, exits 0 with `failed=0`                                      | ✓ VERIFIED | Live run at HEAD: **`Guard suite summary: passed=26 failed=0`**, `GATE2_RC=0` (12 format/guard cases + 9 mount-data + parse proof + 4 honesty cases)                            |

**Score:** 18/18 plan truths verified. **Total: 3/3 roadmap SCs + 18/18 plan truths.**

### Required Artifacts

| Artifact                          | Expected                                   | Status       | Details                                                                                  |
| --------------------------------- | ------------------------------------------ | ------------ | ---------------------------------------------------------------------------------------- |
| `tools/d330-microsd-setup.sh`     | rewritten parser, guard chain, mount-data, stub, dry-run report | ✓ VERIFIED   | 471 lines, substantive, `bash -n` rc=0; all guards/stub/fstab/rollback code present (read in full) |
| `scripts/test_microsd_guards.sh`  | new PATH-shim guard suite with canary      | ✓ VERIFIED   | 742 lines, 26 cases registered `:690-717`, live green `passed=26 failed=0`                |
| `scripts/test_storage_cellular.sh`| dry-run mode = real bash -n gates + suite delegation | ✓ VERIFIED | 103 lines, dry-run branch `:51-77` substantive; probe/test-microsd untouched               |

### Key Link Verification

| From → To                                            | Status     | Details                                                                        |
| ---------------------------------------------------- | ---------- | ------------------------------------------------------------------------------ |
| Guard chain after arg validation, before first parted write | ✓ WIRED | `require_device_for_action :249` → guards `:336/:337/:345` → `parted :347` (strict source order) |
| PATH shims shadow lsblk/findmnt/parted/mkfs so tests never touch a real device | ✓ WIRED | `PATH="$SHIM_DIR:$PATH"` on every destructive invocation; WR-05 activation assert `:164-174`; canary `expect_no_canary` per case |
| Parser accepts `--device` in both argument orders before action logic | ✓ WIRED | while/shift loop `:227-247`; both-order cases green                            |
| Armed EXIT trap is the only path between failed mount and clean fstab | ✓ WIRED | `trap 'rollback_fstab_line' EXIT :458` (armed only after append `:457`, disarmed on success `:468`) |
| `findmnt --verify` between candidate construction and append | ✓ WIRED | build `:436` → verify `:445` → abort-on-fail `:446-454` → append `:457`         |
| `D330_FSTAB` seam keeps test writes off real `/etc/fstab`; format root gate unconditional | ✓ WIRED | `:361` seam; exemption `:394` requires `ACTION=mount-data` + seam + non-root; format gate `:339` has no exemption |
| Harness dry-run propagates guard-suite failures as non-zero exit | ✓ WIRED | `set -euo pipefail :5` + bare `bash scripts/test_microsd_guards.sh :70`         |
| Help text / stub exit / suite assertions reference same fixed message strings | ✓ WIRED | `not implemented` in help `:31`, stub `:259`, suite grep `:642`                |
| Trailing success line: one reachable path, one source occurrence | ✓ WIRED | single occurrence `:471`; all non-genuine paths `exit` before it (truth 03-2)   |

### Data-Flow Trace (Level 4)

| Artifact / Output               | Data Variable       | Source                                     | Produces Real Data | Status       |
| ------------------------------- | ------------------- | ------------------------------------------ | ------------------ | ------------ |
| `[GUARD] mountpoints` result    | `lsblk` MOUNTPOINT  | real/shimmed `lsblk -nr -o MOUNTPOINT "$TARGET_DEV"` `:93` | Yes (live device/shim) | ✓ FLOWING |
| `[GUARD] root-device` result    | `findmnt -n -o SOURCE /` | real `findmnt` `:117`                  | Yes                | ✓ FLOWING    |
| Appended fstab line             | `UUID` from `blkid` `:404` → `build_fstab_line` | real/shim blkid + real fs UUID | Yes                | ✓ FLOWING    |
| Suite outcomes                  | counters from per-case asserts `:719-732` | live tool invocations             | Yes                | ✓ FLOWING    |

No static/hardcoded render paths; the only literal placeholders (`<uuid resolved by blkid>`, `<first partition of ...>`) are dry-run display values with no write behind them.

### Behavioral Spot-Checks (run this session, WSL bash, script-file payloads)

| Behavior                                          | Command / probe                                      | Result                                        | Status |
| ------------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------- | ------ |
| Syntax gate (3 files)                             | `bash -n` ×3                                         | `GATE1_OK` ×3                                  | ✓ PASS |
| Guard suite (SC1/SC2/SC3 end-to-end)              | `bash scripts/test_microsd_guards.sh`                | `passed=26 failed=0`, `GATE2_RC=0`             | ✓ PASS |
| Harness entry point                               | `bash scripts/test_storage_cellular.sh --dry-run`    | 3×`[OK] bash -n` + suite + `[OK] dry-run verification complete`, rc=0 | ✓ PASS |
| Existing smoke regression                         | `--probe` / `--test-microsd`                         | `PROBE_RC=0`, `TESTMICROSD_RC=0`               | ✓ PASS |
| mount-data dry-run guard lines + locked options   | extra probe (shim PATH, temp fstab)                  | `guard_lines=2`, `LOCKED_OPTS_IN_DRYRUN=yes`, `SUCCESS_LEAK=no` | ✓ PASS |
| Source assertions                                 | greps (see GATE5)                                    | success_msg=1, NO_FORCE_FLAG, NO_SLEEP1, NO_ADOPTION_STRING, stub/device/verify/trap strings present | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist or are declared for this phase — the phase's executable checks are the harness commands above (VALIDATION "Test Infrastructure"), all run in this session. Status: SKIPPED (no probe scripts by design).

### Requirements Coverage

`phase_req_ids: null`, `.planning/REQUIREMENTS.md` does not exist — N/A by instruction (no REQ IDs invented).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `scripts/test_microsd_guards.sh` | 74,75,388,553 | grep `XXX` hit | ℹ️ Info | False positive — `mktemp ...XXXXXX` templates, not debt markers |
| `tools/d330-microsd-setup.sh` | 258-261 | `--mount-home` stub exits 1 | ℹ️ Info | Intentional locked decision (CONTEXT), `--help` marks unsupported, 3 suite cases pin it — not a stub defect |

Zero `TBD`/`FIXME` debt markers, zero `TODO`/`HACK`/`PLACEHOLDER`, zero unguarded empty returns in phase-touched files. Review closure cross-check: 5 WR warnings in 32-REVIEW.md, 4 fixed (commits `05687e7`, `0bc62de`, `d4c2dcf`, `acb9b23`), WR-02 wontfix-by-lock with `Deferred WR-02` note present at 32-REVIEW.md:62 — matches 32-REVIEW-FIX.md claim. All fix commits are ancestors of HEAD (`fc2dac6`); all gates above ran at HEAD, so no post-fix regression.

### 14 LOCKED CONTEXT Decisions — Honored

All 14 verified against code: explicit `--device` (D1 ✓ `:44-54`), missing-device hard error+usage (D2 ✓ `:48-50`), sysfs auto-substitution removed (D3 ✓ scan loop never assigns, `:281-291`), refuse root-backed/mounted targets (D4 ✓ guards a+b), guard order a→b→c fail-fast (D5 ✓ `:336/:337/:345`), `-F` removed (D6 ✓), `sleep`→`partprobe`+`udevadm settle` (D7 ✓ `:348-349`), dry-run PASS/FAIL per guard (D8 ✓ `:312-319`), locked fstab options (D9 ✓ `:191`), install-time + test-time parse proofs (D10 ✓ `:445`, `:550-622`), rollback trap on failed mount (D11 ✓ `:458-465`), duplicate refusal/verification (D12 ✓ `:414-430`), honest stub + help marker (D13 ✓ `:258-261`, `:31`), single genuine success line (D14 ✓ one occurrence `:471`, honesty suite green).

## Human Verification Required

### 1. Real-hardware mounted-target abort (roadmap SC1 manual row)

**Test:** Insert a MicroSD, mount one of its partitions, run `sudo tools/d330-microsd-setup.sh --format --device /dev/mmcblk1`
**Expected:** Aborts at `[GUARD] mountpoints: FAIL` before parted runs; card contents untouched
**Why human:** Destructive on real hardware; dev box is non-root with no card — the shim suite proves abort-before-write via canary, the physical run is VALIDATION Manual-Only row 1

### 2. On-target fstab / `systemd-analyze verify` (roadmap SC2 manual row)

**Test:** On the tablet with card inserted, run `--mount-data --device /dev/mmcblk1`, then `findmnt --verify` the real `/etc/fstab` line and `systemd-analyze verify --recursive-errors=yes` on the generated `.mount` unit; additionally boot once with the card removed
**Expected:** 0 parse errors with the card present; absent card at boot drops to `nofail` behavior (timeout 10s), never an emergency shell
**Why human:** Dev machine cannot resolve the fake UUID (environmental `unreachable` WARN); real `/etc/fstab` and boot behavior are target-only — VALIDATION Manual-Only row 2

### 3. WR-01 / WR-03 failure branches (REVIEW-FIX explicit flag)

**Test:** Run `--mount-data` against an unreadable fstab (awk read error path `:414-417`) and force a grep/mv failure inside `rollback_fstab_line` (`:202-217`)
**Expected:** Fail-closed `[ERR] Could not read ...` before append; on rollback failure `[ERR] Rollback FAILED: ...` with fstab never truncated and no success claim
**Why human:** Control-flow failure branches have zero test coverage; 32-REVIEW-FIX.md line 110 explicitly flags them for manual review

## Gaps Summary

No gaps. Every roadmap success criterion, plan truth, artifact, and key link verified against the actual code at HEAD `fc2dac6` with live test execution (`passed=26 failed=0`, harness dry-run rc=0, smoke regressions rc=0). Status is `human_needed` solely because three human-only items remain: two VALIDATION Manual-Only rows (real hardware / on-target boot) and the review's flagged untested failure branches.

---

_Verified: 2026-10-08T06:55:25Z_
_Verifier: the agent (gsd-verifier)_
