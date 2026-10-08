---
phase: 32-data-loss-boot-safety-guards
reviewed: 2026-10-08T06:11:29Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - tools/d330-microsd-setup.sh
  - scripts/test_microsd_guards.sh
  - scripts/test_storage_cellular.sh
findings:
  critical: 0
  warning: 5
  info: 8
  total: 13
status: findings
---

# Phase 32: Code Review Report

**Reviewed:** 2026-10-08T06:11:29Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** findings

## Summary

Reviewed the Phase 32 delta (baseline `037424d` → HEAD: `9ca130c`, `9d3d4b9`, `e7efd94`, `3b91176`, `2a24464`, `b62c3d1`, `266cb78`) across the tool rewrite, the PATH-shim guard suite, and the harness dry-run wiring — ~1112 insertions. The core safety architecture holds: guards execute before the first `parted` write, the root-device refusal is genuinely bidirectional, no `mkfs -F`, no auto-substitution, `nofail` locked string present, rollback trap armed after append, mount-home stub fails before any disk work, and the success line has exactly one reachable-genuine path (verified top-to-bottom). Adversarial probes confirmed the harness never reaches a real write path and found one false-positive refusal (WR-01). No Critical issues; 5 Warnings are fail-open edges, a locked-refusal coverage gap, and harness fail-safety assumptions.

**Verification evidence (WSL bash, repo root):**
- `bash -n` on all three files → rc=0, no output.
- `bash scripts/test_microsd_guards.sh` → `passed=26 failed=0`, `SUITE_RC=0` (one environmental `[WARN] fstab-parse-proof` as designed, zero `[SKIP]`).
- `bash scripts/test_storage_cellular.sh --dry-run` → `HARNESS_RC=0`, 3× `[OK] bash -n ...` + delegated `passed=26 failed=0` + `[OK] dry-run verification complete`.
- Probe A (commented-out UUID line in fstab): `PROBE_RC=1` with `Existing ... entry for UUID=1111-2222 is missing: nofail,...` despite no real entry → WR-01 reproduced.
- Probe B: `findmnt --verify --tab-file` on the locked line with fake UUID + absent target → rc=1 (`0 parse errors, 2 errors`) on this machine; `blkid -s UUID -o value ""` → rc=2, empty output.

## Warnings

### WR-01: Duplicate detection matches comments, then refuses with a misleading remediation

**File:** `tools/d330-microsd-setup.sh:398-409`
**Issue:** Existence is tested with substring match `grep -Fq "UUID=$UUID"` but options are extracted with exact-field match `awk '$1==u ...'`. A commented-out or otherwise non-field-1 reference to the UUID (e.g. `# UUID=1111-2222 /data ...` left by an operator) passes the grep, yields an empty `EXISTING_OPTS`, and falls into the legacy-refusal branch: exit 1 with `Existing ... entry for UUID=... is missing: nofail,...` and a `sed` command anchored on `^UUID=` that can never match the comment it is supposed to fix. Reproduced (probe A above): `PROBE_RC=1`, `UUID_LINES_AFTER=1`. The operation is blocked fail-closed but permanently until the user finds and deletes the comment — and the printed remediation is a dead end.
**Fix:** derive both existence and options from one exact match:
```bash
EXISTING_LINE=$(awk -v u="UUID=$UUID" '$1==u {print; exit}' "$FSTAB_FILE")
if [ -n "$EXISTING_LINE" ]; then
    EXISTING_OPTS=$(awk -v u="UUID=$UUID" '$1==u {print $4; exit}' "$FSTAB_FILE")
    ...
fi
```
(or `grep -q "^UUID=$UUID "` instead of the substring grep).

### WR-02: mount-data path runs no mount-in-use refusal (locked "or when any partition of the target is mounted" only enforced for `--format`)

**File:** `tools/d330-microsd-setup.sh:347-412` (guard skipped per comment at :352-354)
**Issue:** RESEARCH locked Device Selection decision says refuse when the target backs `/` **or** when any partition of the target is mounted. The mount-data branch deliberately runs only `guard_not_root_device`, so a card already mounted elsewhere (desktop automount at `/media/...`, another tool's mount) passes straight through: duplicate check finds no fstab entry, user confirms, and the tool appends a permanent fstab line and mounts the same filesystem a second time at `/data` with zero objection that the target is in active use. The plan documents this trade-off (duplicate-check reachability), but the resulting behavior only enforces half of the locked refusal rule.
**Fix:** keep duplicate-check reachability while honoring the lock — run a mountpoints guard that treats `$MOUNT_POINT` itself as acceptable and FAILs on any *other* mountpoint:
```bash
out=$(lsblk -nr -o MOUNTPOINT "$TARGET_DEV" 2>/dev/null) || rc=$?
# FAIL if any non-empty mountpoint line is != "$MOUNT_POINT"
```

**Deferred WR-02 (resolved at fix time as wontfix by locked decision):** `guard_mountpoint_empty` is the pre-parted/mkfs guard, and `--mount-data` deliberately still has to reach the duplicate check on a re-run against an already mounted `/data` (see the guard comment in the mount-data branch of `tools/d330-microsd-setup.sh`). The plan documents this trade-off, so I left the code as-is instead of breaking duplicate-check reachability to enforce the other half of the locked refusal rule here.

### WR-03: `rollback_fstab_line` fails open: grep error can truncate fstab via unconditional `mv`, and the rollback claim is unconditional

**File:** `tools/d330-microsd-setup.sh:198-205`
**Issue:** `grep -vxF "$LINE" "$FSTAB_FILE" > "$FSTAB_FILE.gsdtmp" || true` followed by `mv -f "$FSTAB_FILE.gsdtmp" "$FSTAB_FILE" || true` then `log_warn "Rolled back..."` unconditionally. If grep exits 2 (read error/race mid-rollback) the redirect has already created a 0-byte temp file, `|| true` hides the failure, and `mv` replaces fstab with an **empty file** (mechanics verified: grep-select-nothing produces a 0-byte temp). If `mv` fails, the tool still prints `Rolled back fstab entry after failed mount.` while the stale line remains. Likelihood is low (root, local file), but this is the phase's boot-safety trap: it must fail closed, never claim a rollback it did not perform, and never trade a stale line for an emptied fstab.
**Fix:**
```bash
rollback_fstab_line() {
    local f="${FSTAB_FILE:-/etc/fstab}"
    [ -f "$f" ] && [ -n "${LINE:-}" ] || return 0
    grep -qxF "$LINE" "$f" 2>/dev/null || return 0
    if grep -vxF "$LINE" "$f" > "$f.gsdtmp" 2>/dev/null; then
        if mv -f "$f.gsdtmp" "$f"; then
            log_warn "Rolled back fstab entry after failed mount."
        else
            log_err "Rollback FAILED: could not rewrite $f; entry may remain."
        fi
    else
        rm -f "$f.gsdtmp"
        log_err "Rollback FAILED: could not read $f; entry may remain."
    fi
    return 0
}
```

### WR-04: Install-time parse proof gates on findmnt exit status alone; the test classifies output, the tool does not

**File:** `tools/d330-microsd-setup.sh:419`
**Issue:** `if ! findmnt --verify --tab-file "$CAND"` trusts rc only. RESEARCH Risk 7 explicitly recommended asserting output text in addition to rc because `findmnt --verify` exit semantics are not firmly documented, and the suite's `fstab-parse-proof` case already classifies `[E]` lines instead of trusting rc. On this machine rc=1 accompanies `[E]` output (measured this review), so the gate works today — but the project's own evidence is contradictory: `32-02-SUMMARY.md:110` records this exact candidate as `rc=0` with `0 parse errors, 2 errors`, i.e. the recorded raw evidence describes a findmnt whose rc-0-with-errors would let an unverified line into fstab (reopening audit C2) while the test's rc-shim case (`D330_SHIM_VERIFY_RC=1`) can never exercise that mode.
**Fix:** belt-and-braces, same classification the test uses:
```bash
if ! findmnt --verify --tab-file "$CAND" > "$CAND.out" 2>&1 || grep -qE '\[E\]' "$CAND.out"; then
    rm -f "$CAND" "$CAND.out"
    log_err "fstab entry failed verification; $FSTAB_FILE not modified."
    exit 1
fi
```
(and correct the rc recorded in 32-02-SUMMARY.md:110 — measured rc=1).

### WR-05: Guard harness never asserts its shims actually activated; four destructive cases leave stdin inherited

**File:** `scripts/test_microsd_guards.sh:157` (activation), `:248-290` (non-piped cases)
**Issue:** The "no real block device is ever written" invariant rests on `chmod +x "$SHIM_DIR"/* || true` succeeding and `$SHIM_DIR` being executable. If the temp dir lands on a `noexec` mount (or chmod fails — its error is swallowed at :157), `command -v` silently falls through to the real `parted`/`mkfs.ext4`, and the four destructive invocations that never pipe stdin (`case_mounted_target_abort`, three `root-refusal-*` cases, all `> "$CASE_OUT" 2>&1` with inherited stdin) depend on the guards failing before `confirm_destructive`. In the degraded-shim scenario on a root run (WSL default) against an unmounted candidate disk (e.g. `/dev/sdb` when loop devices are absent), an operator typing `yes` at a stray prompt inside a test run would execute the **real** `parted` — and the canary check would still pass (real parted never touches the canary), reporting `[OK]`.
**Fix:** (1) assert shim activation once before any case: with `PATH="$SHIM_DIR:$PATH"`, require `command -v parted` to resolve inside `$SHIM_DIR`, else `exit 1`; (2) redirect `</dev/null` on the four non-piped destructive invocations — they never legitimately read stdin, so `confirm_destructive` can never pass in them.

## Info

### IN-01: Trap disarmed after `log_ok`, so a failed echo rolls back a successful mount

**File:** `tools/d330-microsd-setup.sh:436-437`
**Issue:** Between successful `mount` (430) and `trap - EXIT` (437) the only statement is `log_ok ...`. Under `set -e`, an `echo` failure (e.g. EPIPE when output is piped) exits the script with the trap still armed → the fstab line for a *live* mount is removed and `Rolled back fstab entry after failed mount.` prints — a false claim about a successful action.
**Fix:** disarm immediately after the mount rc check, before `log_ok`.

### IN-02: Empty `PART_DEV` produces a misleading error message

**File:** `tools/d330-microsd-setup.sh:391-396`
**Issue:** When the card has no partition (or lsblk fails — `|| true` at :391 swallows rc), `PART_DEV` is empty, `blkid ... ""` returns empty (measured rc=2), and the user sees `Could not resolve UUID for . Format card first.` with an interpolated-empty device name; the real cause (no partition node) is hidden.
**Fix:** check `[ -z "$PART_DEV" ]` first and emit `No partition found on $TARGET_DEV; run --format first.` before resolving the UUID.

### IN-03: `SIZE` interpolated into awk program text

**File:** `tools/d330-microsd-setup.sh:263-264`
**Issue:** `awk "BEGIN {printf \"%.1f\", $SIZE / 1073741824}"` splices raw lsblk output into the program. The `|| echo 0` fallback can append a second line when lsblk fails after partial output (pipeline under pipefail), yielding malformed program text and a non-zero awk exit → `set -e` aborts `--probe`, breaking the probe contract "exits 0 with or without a card" on a hot-removal race.
**Fix:** sanitize (`SIZE="${SIZE//[^0-9]/}"`; default `0` on empty) or pass via `awk -v size="$SIZE" 'BEGIN {printf "%.1f", size/1073741824}'`.

### IN-04: mount-data dry-run preview ignores the duplicate check

**File:** `tools/d330-microsd-setup.sh:363-374`
**Issue:** Dry-run prints `[DRY-RUN] Append to ...` unconditionally, but the real path may exit 0 with `already present` (noop) or exit 1 on a legacy line. The preview can tell the user an entry will be added when the real run will not append — a small honesty gap in a phase whose locked rule is honest dry-run output.
**Fix:** run the same `grep -Fq "UUID=$UUID"` duplicate branch in the dry-run report and print `would noop (entry already present)` / `would refuse (legacy line)` accordingly.

### IN-05: `expect_fstab_count` passes vacuously when the fstab file is missing

**File:** `scripts/test_microsd_guards.sh:212-219`
**Issue:** `n=$(grep -c ... || true)` swallows grep's read error, so `n="" → ${n:-0}` = 0 — an expectation of `0` passes even when `$CASE_FSTAB` does not exist, masking a broken fixture (e.g. failed `fresh_fstab`) as green.
**Fix:** fail the assertion when the file is absent: `[ -f "$1" ] || { echo "    [detail] fstab missing: $1"; CASE_FAIL=1; return; }`.

### IN-06: No global `D330_FSTAB` tripwire in the harness fixture

**File:** `scripts/test_microsd_guards.sh:159-162`
**Issue:** All 10 current mount-data invocations set `D330_FSTAB` (verified — no path writes the real `/etc/fstab` today), but the "never write the real fstab" invariant is per-case convention only; one future case that forgets the seam, run as root, appends to the real file.
**Fix:** export a suite-wide default in the fixture: `export D330_FSTAB="$TAB_DIR/default-fstab"` (cases override per-run as they already do).

### IN-07: Block-device candidate list omits NVMe naming

**File:** `scripts/test_microsd_guards.sh:59`
**Issue:** `loop0/loop1/sda/sdb/vda` — on an NVMe-only host with no loop devices the suite (and therefore the harness `--dry-run` entry point) dies with `no block device available`. Plan-pinned list, but worth noting for portability.
**Fix:** extend candidates with `/dev/nvme0n1`.

### IN-08: Guard (b) is string-prefix only — no fallback when root SOURCE is not a `/dev` path

**File:** `tools/d330-microsd-setup.sh:114-135`
**Issue:** RESEARCH §2/Risk 5/A3 flagged that `findmnt -n -o SOURCE /` may print `/dev/mapper/...`, `/dev/root`, or `rootfs` on some systems, in which case the bidirectional prefix checks pass trivially and guard (b) goes blind (guard (a) still catches mounted descendants, so this is defence-in-depth erosion, not a hole). The PKNAME/major:minor fallback contemplated as a contingency has not shipped and no target-hardware capture of the SOURCE string is recorded in the phase artifacts.
**Fix:** when either prefix case fails to match, cross-check `lsblk -no PKNAME "$ROOT_SRC"` basenames against `basename "$TARGET_DEV"` (contingency already specified in RESEARCH §2), or record the captured on-hardware SOURCE string as manual-validation evidence.

---

_Reviewed: 2026-10-08T06:11:29Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
