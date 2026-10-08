---
phase: 41-test-harness-trustworthiness
fixed_at: 2026-10-08T20:46:48Z
review_path: .planning/phases/41-test-harness-trustworthiness/41-REVIEW.md
iteration: 1
findings_in_scope: 12
fixed: 12
skipped: 0
status: all_fixed
---

# Phase 41: Code Review Fix Report

**Fixed at:** 2026-10-08T20:46:48Z
**Source review:** `.planning/phases/41-test-harness-trustworthiness/41-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 12 (2 High, 7 Medium, 3 Low) + 1 additional hardening item requested by the fix plan (`test_tablet_osk.sh` anchor, WR-09)
- Fixed: 12
- Skipped: 0

All fixes were applied, verified and committed under WSL bash 5.2. Each finding
is committed atomically; unrelated pre-existing CRLF working-copy noise was not
staged ("Do not touch unrelated leftovers").

## Fixed Issues

### WR-01: SC1 never checks the intact subject, so an always-failing script is reported trustworthy

**Files modified:** `scripts/test_harness_trust.sh`
**Commit:** `0a878c6`
**Applied fix:** `sc1_case` now runs the subject command against the intact tree
first and requires `baseline_rc == 0` before mutating. A subject that is already
red reports `[FAIL] SC1 ...: baseline '<cmd>' already exits N on the intact
subject` instead of `[PASS]`. Byte-exact snapshot restore (`cp -p` + `cmp`) is
unchanged. Verified with a negative control that injected `exit 1` into
`test_power_stack.sh` (SC1 correctly failed; file restored, `git diff` clean).

### WR-02: SC2 treats any occurrence of the literal `--apply` as proof of a gate

**Files modified:** `scripts/test_harness_trust.sh`
**Commit:** `0a878c6`
**Applied fix:** The `grep -Fq -- '--apply' "$script"` whole-file token test is
gone. A command-position mutator or sysfs write is now gated only when the
script parses `--apply` into a gate variable (the `--apply)` case arm) AND
branches on that variable (an `[[ ... APPLY ... ]]` conditional) at a line
*before* the mutation. `--help`/comment mentions can no longer bless an ungated
mutation. Verified with a negative control that neutralised the
`if [[ "$APPLY" -ne 1 ]]` guard in `test_hardware_controls.sh` (SC2 correctly
reported `present with no --apply gate`; file restored).

### WR-03: SC2 misses vendored/variable-path mutations and delegated tool mutations

**Files modified:** `scripts/test_harness_trust.sh`
**Commit:** `0a878c6`
**Applied fix:** Broadened the mutation vocabulary to
`insmod`/`rmmod`/`sysctl -w`/`--write`/`rfkill`/`ip link|addr|address|route|rule`/`mount`/`umount`/`mkfs`/`dd if=`/`nmcli radio`
in addition to the existing `systemctl`/`fstrim`/`modprobe`. Added sysfs/proc
redirect detection for literal, quoted and **variable** targets via an iterative
taint pass (a variable assigned from a `/sys`|`/proc` path — or from a
`for ... in /sys/...` list, or from another tainted variable — is tracked; a
redirect to it is flagged). This catches `echo 1 > "$node"` in
`test_hardware_controls.sh`. Delegated `bash|sh .../tools/* --apply`
invocations are now followed and flagged (`delegated-apply`), catching
`test_thermals.sh:71` and `test_boot_speed.sh:69`. The scan stays
command-position-only on quote/comment-stripped source, so assertion literals
and help prose do not trip it. Current result: `test_boot_speed.sh`,
`test_hardware_controls.sh`, `test_memory_storage.sh` and `test_thermals.sh`
are all correctly reported as gated; no false positives across the other
`test_*.sh`.

### WR-04: `--monitor` libinput invocation is malformed and now hard-fails the harness

**Files modified:** `scripts/test_touch_calibration.sh`
**Commit:** `1c90654`
**Applied fix:** `libinput debug-events --device /dev/input/event*` ->
`libinput debug-events /dev/input/event*` (device paths are positional;
`--device` takes a single value).

### WR-05: Unconditional `[OK]` for the cellular rules file (false OK)

**Files modified:** `scripts/test_storage_cellular.sh`
**Commit:** `c6975e0`
**Applied fix:** The rules line is now guarded by `[ -s "$cellular_rules" ]`;
a missing or empty `78-lenovo-d330-cellular.rules` prints
`[FAIL] Cellular Rules file missing or empty: ...` to stderr and exits 1.
The `[OK]` only prints for a non-empty file.

### WR-06: Empty FCC-unlock hook is only `[INFO]`; the shipped hook is 0 bytes

**Files modified:** `scripts/test_storage_cellular.sh`, `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086`
**Commit:** `c6975e0`
**Applied fix:** A present-but-empty FCC hook is now a hard failure
(`[FAIL] ... present but empty (non-functional)` + `exit 1`). Because the
shipped `8086` hook was a 0-byte blob (so the fixed check would correctly fail
the dry-run), the artifact was also given real content: the upstream
ModemManager `data/dispatcher-fcc-unlock/8086:7360` CC0 Intel XMM7360 RPC FCC
unlock script, with a header note that the Windows checkout cannot store the
colon and tracks it as `8086` (rename to `8086:7360` on POSIX; ROADMAP N2). The
aggregate dry-run now prints `[OK] ModemManager FCC unlock hook: .../8086` and
exits 0 while remaining non-vacuous.

### WR-07: `test_dock_switching.sh` cannot fail in its default/status path

**Files modified:** `scripts/test_dock_switching.sh`
**Commit:** `4cf2e8c`
**Applied fix:** Added a `FAILED` counter. The daemon query is now
`if ! python3 "$DAEMON_SCRIPT" --status; then log_err ...; FAILED=$((FAILED+1)); fi`
(`|| true` dropped), and a missing daemon script also increments `FAILED`. A new
final block exits 1 when `FAILED > 0`. Kernel-module probing stays a `log_warn`
(it is host/hardware-dependent, not a harness defect) so the default gate stays
green on a non-D330 host.

### WR-08: `--test-toggle` leaves `conservation_mode` toggled if interrupted

**Files modified:** `scripts/test_hardware_controls.sh`
**Commit:** `7808629`
**Applied fix:** `trap 'echo "$original" > "$node" 2>/dev/null' EXIT INT TERM`
is installed immediately before the first write, so SIGINT/SIGTERM or an early
exit restores the original conservatation mode. The trap is cleared
(`trap - EXIT INT TERM`) only after the restore is verified.

### WR-09 (fix-plan addition): `test_tablet_osk.sh` lacked the SCRIPT_DIR anchor

**Files modified:** `scripts/test_tablet_osk.sh`
**Commit:** `463c6ff`
**Applied fix:** Added the
`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` + `cd` anchor and
routed the `patches/touchscreen/...` grep and both
`python3 tools/d330-tablet-daemon.py` invocations through
`"$SCRIPT_DIR/..."`, matching the other 15 anchored harnesses.

### IN-01: `test_ci_workflows.sh` `"on:" in content` can match `runs-on:`

**Files modified:** `scripts/test_ci_workflows.sh`
**Commit:** `2ba761b`
**Applied fix:** `has_on = "on:" in content` -> `has_on = re.search(r'(?m)^on:', content) is not None`
(added `import re`). A workflow missing the real top-level `on:` trigger now
fails even if it contains `runs-on:`.

### IN-02: `--stress-zram` still swallows its own failures

**Files modified:** `scripts/test_memory_storage.sh`
**Commit:** `f9a5971`
**Applied fix:** Dropped both `|| true`s. The `head -c 1500M` allocation and the
`free -h` report are now checked; either failing prints `[FAIL] ...` to stderr,
cleans up the tmpdir and exits 1.

### IN-03: Output directory claimed "writable" but only existence is checked

**Files modified:** `scripts/build_live_iso.sh`
**Commit:** `d03ab91`
**Applied fix:** The dry-run now distinguishes missing vs present-but-not-writable
parents (`[[ ! -d ]]` / `[[ ! -w ]]`), incrementing `dry_failed` and printing a
distinct message for each; the pass line reads "present and writable".

## Verification

All gates run under WSL bash 5.2 (`/mnt/d/...`, i.e. the main checkout).

```
harness-trust          rc=0  |  Harness-trust meta-guard summary: passed=9 failed=0
storage-cellular       rc=0  |  [OK] ModemManager FCC unlock hook: .../8086
                                [OK] Cellular Rules: .../78-lenovo-d330-cellular.rules
                                [OK] dry-run verification complete
dock-switching         rc=0
hardware-controls      rc=0
tablet-osk             rc=0
touch-calibration      rc=0  |  (--dry-run: shipped config audit complete)
ci-workflows           rc=0  |  All GitHub Actions workflows validated.
memory-storage         rc=0
symmetry               rc=0  |  Guard suite summary: passed=17 failed=0
hibernate              rc=0  |  Guard suite summary: passed=21 failed=0
display                rc=0  |  Guard suite summary: passed=10 failed=0
microsd                rc=0  |  Guard suite summary: passed=26 failed=0
noop                   rc=0  |  No-op guard summary: passed=5 failed=0
udev-match             rc=0  |  udev/hwdb match guard summary: passed=10 failed=0
power-stack            rc=0  |  power-stack guard summary: passed=12 failed=0
audio                  rc=0  |  Speaker DSP structure: passed=17 failed=0
rnnoise                rc=0  |  RNNoise structure: passed=7 failed=0
bash -n                OK    |  9/9 changed scripts + the FCC hook
```

Negative controls (both reverted after the run, `git diff` clean):

- SC1 baseline: injecting `exit 1` into `test_power_stack.sh` makes
  `test_harness_trust.sh` report `[FAIL] SC1 power-stack: baseline ... already
  exits 1 on the intact subject`.
- SC2 structural gate: neutralising the APPLY guard in
  `test_hardware_controls.sh` makes it report
  `[FAIL] SC2 test_hardware_controls.sh: mutation(s) sysfs-write($node) present
  with no --apply gate`.

Environment note: the un-flagged `scripts/test_touch_calibration.sh` (default
hardware probe) and `scripts/test_mic_rnnoise.sh --probe` exit non-zero on this
non-D330 WSL host because no touchscreen controller / LADSPA plugin is present.
Those are pre-existing, hardware-dependent paths unrelated to these fixes; the
repo-artifact gates (`--dry-run`) are green as listed above.

## Skipped Issues

None.

---

_Fixed: 2026-10-08T20:46:48Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
