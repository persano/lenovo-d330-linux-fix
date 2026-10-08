---
phase: 32-data-loss-boot-safety-guards
fixed_at: 2026-10-08T06:36:45Z
review_path: .planning/phases/32-data-loss-boot-safety-guards/32-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 32: Code Review Fix Report

**Fixed at:** 2026-10-08T06:36:45Z
**Source review:** `.planning/phases/32-data-loss-boot-safety-guards/32-REVIEW.md` (commit `764f75d`)
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01, WR-03, WR-04, WR-05)
- Fixed: 4
- Skipped: 0
- Out of scope: WR-02 (do-not-fix, note appended below), IN-01..IN-08 (Info tier)

**Execution environment:** all edits and fix commits were made in an isolated git worktree (`gsd-reviewfix/32-13352`, path `.claude/worktrees/rf-32-13352-1791440355`) and fast-forwarded onto `main`. Worktree files came out CRLF from `core.autocrlf=true` while the main checkout holds LF, so the four executed/edited files were normalized back to LF before editing; that normalization produced zero content diff against the index, so no commit carries line-ending churn.

## Fixed Issues

### WR-01: Duplicate detection matches comments, then refuses with a misleading remediation

**Files modified:** `tools/d330-microsd-setup.sh`
**Commit:** 05687e7
**Applied fix:** Replaced the substring `grep -Fq "UUID=$UUID"` existence test with an exact first-field `awk -v u="UUID=$UUID" '$1==u {print; exit}'` match, so both existence and the options lookup agree on the same rule. A non-zero awk exit (unreadable fstab) now fails closed with its own `[ERR]` message instead of silently falling through to the append path. A commented-out `# UUID=...` line no longer triggers the false "missing nofail" refusal or its dead-end sed hint.

### WR-03: `rollback_fstab_line` fails open: grep error can truncate fstab via unconditional `mv`, and the rollback claim is unconditional

**Files modified:** `tools/d330-microsd-setup.sh`
**Commit:** 0bc62de
**Applied fix:** Restructured the EXIT-trap payload: `mv` runs only after `grep -vxF` itself proved the rewrite succeeded (explicit rc check), a failed grep removes the empty temp and logs `[ERR] Rollback FAILED: could not read ...`, a failed `mv` logs `[ERR] Rollback FAILED: could not rewrite ...`, and the "Rolled back fstab entry after failed mount." success message prints only after a successful `mv`. The fstab can no longer be replaced by an empty/truncated temp file, and a failed rollback is never reported as a success.

### WR-04: Install-time parse proof gates on findmnt exit status alone; the test classifies output, the tool does not

**Files modified:** `tools/d330-microsd-setup.sh`
**Commit:** d4c2dcf
**Applied fix:** findmnt output is now captured to `$CAND.out` instead of being discarded; on a non-zero rc the tool prints `findmnt --verify rejected the candidate fstab line (rc=N):` via `log_err` followed by every captured output line, then cleans up both temp files and aborts. Per the fix scope the gate stays rc-based (the locked rule is "never append an unproven line") and no `[E]`/WARN classification was added to the tool.

### WR-05: Guard harness never asserts its shims actually activated; four destructive cases leave stdin inherited

**Files modified:** `scripts/test_microsd_guards.sh`
**Commit:** acb9b23
**Applied fix:** Before any case runs, the suite now asserts `command -v parted` and `command -v mkfs.ext4` resolve inside `$SHIM_DIR` under `PATH="$SHIM_DIR:$PATH"`, and executes the parted shim once to prove the temp dir is runnable (catches a noexec mount, which `command -v` alone cannot); any failure exits 1 up front. The four non-piped destructive invocations (`case_mounted_target_abort` and the three `root-refusal-*` cases) now redirect `</dev/null`, so a degraded-shim run aborts at `read` instead of waiting on a TTY.

## Review file note (do-not-fix entry)

### WR-02: mount-data path runs no mount-in-use refusal

**Files modified:** `.planning/phases/32-data-loss-boot-safety-guards/32-REVIEW.md`
**Commit:** 22b59c7
**Applied fix:** No code change (wontfix by locked decision). A "Deferred WR-02" note was appended to the finding entry in the review file explaining that `guard_mountpoint_empty` is the pre-parted/mkfs guard, that `--mount-data` must still reach the duplicate check on re-run, and that the plan documents this trade-off.

## Skipped Issues

None — all in-scope findings were fixed.

## Verification

All gates below ran in the **isolated worktree** (`.claude/worktrees/rf-32-13352-1791440355`) under WSL bash (`bash /mnt/c/.../<script>` script files, never inlined), before the fast-forward onto `main`. The fast-forward moved the identical content to `main`, so the same commands from the project root reproduce these numbers.

1. `bash -n` syntax gate:

```
bash -n tools/d330-microsd-setup.sh -> rc=0
bash -n scripts/test_microsd_guards.sh -> rc=0
bash -n scripts/test_storage_cellular.sh -> rc=0
GATE1_RC=0
```

2. `bash scripts/test_microsd_guards.sh`:

```
 Guard suite summary: passed=26 failed=0
GATE2_RC=0
```

(one environmental `[WARN] fstab-parse-proof: unreachable source/target on this machine`, same as the review recorded; zero `[FAIL]`)

3. `bash scripts/test_storage_cellular.sh --dry-run`:

```
[OK] bash -n tools/d330-microsd-setup.sh
[OK] bash -n scripts/test_microsd_guards.sh
[OK] bash -n scripts/test_storage_cellular.sh
...
 Guard suite summary: passed=26 failed=0
[OK] dry-run verification complete
GATE3_RC=0
```

4. Regression `bash tools/d330-microsd-setup.sh --mount-data` (no device):

```
[ERR]  Action 'mount-data' requires an explicit --device /dev/... argument.
...
GATE4_RC=0 (exit=1, message present)
```

5. Extra WR-01 probe (reviewer's probe A: fstab containing only `# UUID=1111-2222 ...`): runs past the duplicate check and stops at confirmation instead of refusing, `UUID_LINES_AFTER=1`, `RESULT=PASS`.

6. After the fast-forward, the same four gates were re-run in the **main checkout** (project root, WSL bash script files) and all passed again: `GATE1_RC=0` (three `bash -n -> rc=0`), `GATE2_RC=0` with `Guard suite summary: passed=26 failed=0`, `GATE3_RC=0` ending `[OK] dry-run verification complete`, `GATE4_RC=0 (exit=1, message present)`. One environment note: the fast-forward wrote the updated files through `core.autocrlf=true`, which smudged them to CRLF and broke `bash -n`; I restored the three working copies to LF (byte-for-byte identical to the committed blobs, `git hash-object` equals `HEAD:`, empty diff, nothing staged), so the working tree matches its pre-ff line endings and every gate above is reproducible from the tree as it sits now.

**Flagged for human verification:** WR-01 and WR-03 change control-flow logic (existence matching and rollback state handling); the suite and probe A exercise their success paths, but the failure branches (awk read error, grep/mv failure inside `rollback_fstab_line`) have no test coverage and deserve a manual look.

---

_Fixed: 2026-10-08T06:36:45Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
