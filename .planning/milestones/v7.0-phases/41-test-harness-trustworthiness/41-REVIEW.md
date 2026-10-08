---
phase: 41-test-harness-trustworthiness
reviewed: 2026-10-08T00:00:00Z
depth: deep
files_reviewed: 20
files_reviewed_list:
  - scripts/build_live_iso.sh
  - scripts/test_acpi_cleanliness.sh
  - scripts/test_audio_profiles.sh
  - scripts/test_auto_hibernate.sh
  - scripts/test_battery_power.sh
  - scripts/test_boot_speed.sh
  - scripts/test_cameras.sh
  - scripts/test_ci_workflows.sh
  - scripts/test_distro_packaging.sh
  - scripts/test_dock_switching.sh
  - scripts/test_hardware_controls.sh
  - scripts/test_harness_trust.sh
  - scripts/test_iso_integrity.sh
  - scripts/test_memory_storage.sh
  - scripts/test_oom_protection.sh
  - scripts/test_resume_loop.sh
  - scripts/test_storage_cellular.sh
  - scripts/test_tablet_osk.sh
  - scripts/test_thermals.sh
  - scripts/test_touch_calibration.sh
findings:
  critical: 0
  high: 2
  medium: 7
  low: 3
  total: 12
status: issues_found
---

# Phase 41: Code Review Report

**Reviewed:** 2026-10-08
**Depth:** deep
**Files Reviewed:** 20
**Status:** issues_found

## Summary

Phase 41 turns the `test_*.sh` harnesses from always-green into suites that
`exit 1` on a broken subject, adds `--apply` gates, fixes the `--stress N` /
`--cycle-test N` / daemon-flag parsers, anchors `tools/`/`patches/` to the
script dir, makes `build_live_iso.sh --dry-run` validate real prerequisites, and
adds `scripts/test_harness_trust.sh` (SC1 mutation + SC2 static mutation scan).

The parser/arith fixes, the new failure counters, the `--apply` gates where
implemented, the SCRIPT_DIR anchoring (15 scripts), and the ISO dry-run
prerequisite validation all check out. However the new meta-guard — the artifact
whose whole job is to prove the other harnesses can fail — is itself unsound in
two ways (no baseline check for SC1; a token-only `--apply` gate for SC2), so it
can report PASS over a permanently-failing or ungated-mutating script. A handful
of smaller honesty gaps remain (false unconditional `[OK]`, an empty FCC hook
treated as non-fatal, an ungated-by-design status path).

## Critical Issues

None. No security vulnerability, data-loss path, or crash was found. All
in-scope scripts pass `bash -n`.

## Warnings

### WR-01: SC1 never checks the intact subject, so an always-failing script is reported trustworthy

**File:** `scripts/test_harness_trust.sh:947`
**Issue:** `sc1_case` mutates the subject, runs `cmd`, and asserts `rc != 0`.
It never runs `cmd` against the intact subject first, so a test script that
already fails (unrelated hardware/tooling, a real bug, or a script that always
exits 1) yields `[PASS] SC1 ... exits non-zero`. `test_tray_applet.sh` is one of
the five SC1 subjects and is not otherwise invoked by the aggregate, so the
meta-guard can be fully green while tray wiring is broken. SC1 is therefore
non-vacuous only if each subject passes before mutation.
**Fix:** Run `( cd "$REPO_ROOT" && eval "$cmd" )` before mutating; require
`baseline_rc == 0` (else `bad "baseline '$cmd' already fails"`) and only then
assert `rc != 0` after mutation.

### WR-02: SC2 treats any occurrence of the literal `--apply` as proof of a gate

**File:** `scripts/test_harness_trust.sh:1034`
**Issue:** `if grep -Fq -- '--apply' "$script"` scans the whole file. A mutation
with `--apply` appearing only in `--help`/a comment (or an unrelated option) is
reported `[PASS] ... gated by --apply`. The gate is never tied to the mutation
line, so removing the real gate while leaving the help text passes SC2. This is
the exact false-negative class the meta-guard exists to prevent.
**Fix:** Determine gating structurally (e.g., require the mutating command to be
lexically inside a branch guarded by the parsed `APPLY` variable, or require an
explicit marker such as `# gated:--apply` on/adjacent to the command line).

### WR-03: SC2 misses vendored/variable-path mutations and delegated tool mutations

**File:** `scripts/test_harness_trust.sh:1017-1031`
**Issue:** The scan only matches a fixed token list at command position. It
cannot see (a) sysfs writes whose target is a variable (`echo 1 > "$node"` in
`test_hardware_controls.sh:106,111`), (b) mutations delegated to another script
(`test_thermals.sh:71`, `test_boot_speed.sh:69` run `tools/*.sh --apply` and are
never scanned), or (c) unlisted mutators (`dd`, `insmod`, `rmmod`, `sysctl -w`,
`rfkill`, `ip`, `mount`, `mkfs`, block-device writes). Removing the `--apply`
gate from those scripts would not be caught.
**Fix:** Broaden the mutation vocabulary, flag writes to any `>/sys`/`>/proc`
target including quoted/variable paths, and follow `bash|sh "$SCRIPT_DIR"/tools/*`
invocations (or require the invoked tool to carry/deny an apply flag).

### WR-04: `--monitor` libinput invocation is malformed and now hard-fails the harness

**File:** `scripts/test_touch_calibration.sh:172`
**Issue:** `if ! libinput debug-events --device /dev/input/event*; then` relies on
a glob that expands to every input node being accepted after a single-value
`--device` flag. `libinput debug-events` documents device paths as positional;
with several `/dev/input/eventN` this invocation errors, which the old `|| true`
hid and the new code now counts as `FAILED`, so `--monitor` reports failure for a
command-construction problem rather than a real touchscreen fault.
**Fix:** Use positional device(s), e.g. `libinput debug-events /dev/input/event*`,
or resolve and pass the single Goodix event node.

### WR-05: Unconditional `[OK]` for the cellular rules file (false OK)

**File:** `scripts/test_storage_cellular.sh:162`
**Issue:** `echo "[OK] Cellular Rules: .../78-lenovo-d330-cellular.rules"` is
printed with no `-f`/`-s` check. The file is never validated; if it is deleted or
emptied the dry-run still prints `[OK]` and exits 0. This is the false-`[OK]`
anti-pattern the phase set out to remove.
**Fix:** Guard it like the FCC hook: `[ -s "$f" ] && echo "[OK] ..." || { echo "[FAIL] ..." >&2; exit 1; }`.

### WR-06: Empty FCC-unlock hook is only `[INFO]`; the shipped hook is 0 bytes

**File:** `scripts/test_storage_cellular.sh:155-160`
**Issue:** The only shipped hook `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086`
is 0 bytes, so the loop emits `[INFO] ... present but empty`, the block falls
through, and the dry-run prints `[OK] dry-run verification complete` and exits 0.
An empty FCC-unlock hook is non-functional; the check passes vacuously.
**Fix:** Treat a present-but-empty hook as a failure (increment/exit 1) unless an
explicit placeholder convention is documented.

### WR-07: `test_dock_switching.sh` cannot fail in its default/status path

**File:** `scripts/test_dock_switching.sh:87`
**Issue:** `python3 "$DAEMON_SCRIPT" --status || true` swallows daemon-query
failure, missing kernel modules only `log_warn` (line 80), and the script has no
`FAILED` counter. Default and `--status` invocation therefore always exit 0 even
with a broken daemon or absent hardware.
**Fix:** Add a `FAILED` counter and fail on a non-zero daemon query (drop
`|| true`, or convert to `if ! ...; then FAILED=$((FAILED+1)); fi` plus a final
`exit 1`).

### WR-08: `--test-toggle` leaves `conservation_mode` toggled if interrupted

**File:** `scripts/test_hardware_controls.sh:106-115`
**Issue:** The apply path writes `1` to the real sysfs node, then restores the
original. There is no `trap`/rollback, so SIGINT/SIGTERM or a crash between the
write and the restore leaves the user's battery in conservation mode. This is a
real hardware side effect, not a test artifact.
**Fix:** `trap 'echo "$original" > "$node" 2>/dev/null' EXIT INT TERM` before the
first write, and clear the trap after a verified restore.

## Info

### IN-01: `test_ci_workflows.sh` `"on:" in content` can match `runs-on:`

**File:** `scripts/test_ci_workflows.sh:84`
**Issue:** `has_on = "on:" in content` is a substring test; `runs-on:` (and any
`*on:` key) satisfies it, so a workflow missing the real top-level `on:` trigger
key is reported `[OK]`. The new strict/dry-run failure logic depends on this.
**Fix:** Match a line-anchored key, e.g. `re.search(r'(?m)^on:', content)`.

### IN-02: `--stress-zram` still swallows its own failures

**File:** `scripts/test_memory_storage.sh:127,129`
**Issue:** `head -c 1500M </dev/zero > "$tmpdir/test.img" || true` and
`free -h || true` mean the zram stress path cannot report a failed allocation.
It is behind `--apply`, but the phase's premise is that a failing check must be
able to fail.
**Fix:** Drop `|| true`; check the `head` rc and increment/exit on failure.

### IN-03: Output directory claimed "writable" but only existence is checked

**File:** `scripts/build_live_iso.sh:90-96`
**Issue:** The comment says the output parent "must exist and be writable", but
the code only tests `[[ -d "$out_parent" ]]`. A read-only parent passes the
dry-run and fails later at write time.
**Fix:** Add `[[ -w "$out_parent" ]]` (and fail with a distinct message when the
directory exists but is not writable).

## Clean Categories

- **Parser/arith fixes:** `--stress N` and `--cycle-test N` are consumed and
  validated `^[0-9]+$`; no `((x++))`-under-`set -e` hazards remain; daemon flags
  (`--dry-run --simulate-dock|--simulate-undock`) match `tools/d330-tablet-daemon.py`.
- **`--apply` gating (battery `--tune`, memory `--stress-*`/`--trim`,
  hardware `--test-toggle`):** the mutating command genuinely sits behind the
  parsed `APPLY` flag, not just a help string.
- **SCRIPT_DIR anchoring:** the 15 edited anchored scripts resolve `tools/`/
  `patches/`/`packaging/` identically from the repo root and from `scripts/`;
  `test_storage_cellular.sh`'s inner dry-run anchor still resolves correctly.
- **`build_live_iso.sh --dry-run`:** genuinely exits 1 with a specific `[ERR]`
  on missing `xorriso`/`unsquashfs`/`mksquashfs`, missing `--base-iso` file,
  missing output parent, missing source paths, or absent `tools/d330-*` payload;
  `test_iso_integrity.sh --dry-run` inherits the non-zero.
- **SC2 current false positives:** none (verified against all 40 `test_*.sh`;
  only `test_memory_storage.sh` trips, and it carries `--apply`).
- **Syntax:** all in-scope scripts pass `bash -n`.

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
