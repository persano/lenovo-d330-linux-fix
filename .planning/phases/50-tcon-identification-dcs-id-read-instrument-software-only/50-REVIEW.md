---
phase: 50-tcon-identification-dcs-id-read-instrument-software-only
reviewed: 2026-10-17T02:30:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - .github/workflows/build-kernel.yml
  - patches/d330_dsi_dump.patch
  - scripts/capture_dsi_dumps.sh
  - scripts/dsi_mmio_diff.sh
  - scripts/tcon_i2c_sweep.sh
  - docs/research/DSI_MMIO_DIFF.md
  - docs/research/TCON_IDENTIFICATION.md
  - docs/dumps/re_kit/MANIFEST.sha256
  - docs/dumps/re_kit/tcon_boot_dsi_regs.txt
  - docs/dumps/re_kit/tcon_resume_dsi_regs.txt
  - docs/dumps/re_kit/tcon_i2c_sweep.txt
  - docs/dumps/re_kit/dsi_regs_diff_tcon_boot_vs_resume.txt
findings:
  critical: 0
  warning: 2
  info: 6
  total: 8
status: issues_found
---

# Phase 50: Code Review Report

**Reviewed:** 2026-10-17T02:30:00Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 50 adds the echo-2 DCS ID-read instrument (kernel debugfs extension), extends the capture/diff tooling with a pinned `# DCS ID READ` grammar, adds the I2C sweep script, and registers the device-session artifacts. The implementation is careful and mostly correct by construction: the node is 0600/root-only, read-only by contract (verified: only `intel_de_read` and DCS read transactions; the only register write in the new path is the i915 driver's own internal W1C clear inside `intel_dsi_host_transfer()`), the trigger rejects values > 2, the echo-1 dump stays byte-compatible (DCS rows are DCS-prefixed and never match the `^0x...=...` record regex), and the `avail` post-check semantics were cross-checked against the researched mainline source (the driver clears `GEN_READ_DATA_AVAIL` via W1C at the start of every transfer, so a post-call read of 1 genuinely means data arrived). Verified positively: all 75 manifest entries hash-check OK (including the 9 phase-50 additions), the real device artifacts (`tcon_boot/resume_dsi_regs.txt`) match the new grammar end-to-end, the archived diff shows the comparison block and per-range counts correct with 0 warnings, and `dsi_mmio_diff.sh --selftest` passes 52/52 on this machine. Two `set -e`/pipefail abort hazards I suspected in `tcon_i2c_sweep.sh` were tested empirically (bash 5.2) and are NOT real — no finding. One concrete delivered-artifact defect (i2cdetect provenance line records a getopt error instead of a version) and one overstated safety guarantee (timeout wrapping) are classified Warning; six smaller items are Info.

## Critical Issues

None.

## Warnings

### WR-01: `i2cdetect --version` unsupported — kit provenance line records a getopt error, proven in the delivered artifact

**File:** `scripts/tcon_i2c_sweep.sh:90`
**Issue:** The tool-provenance section runs `i2cdetect --version`. i2c-tools' `i2cdetect` parses options with plain `getopt` (short options only), so `--version` is rejected. This is not hypothetical: the phase-50 delivered artifact `docs/dumps/re_kit/tcon_i2c_sweep.txt:4` contains exactly `i2cdetect: i2cdetect: invalid option -- '-'` (same for the run2 sweep). The script's own header promises "tool provenance (i2cdetect/gpioinfo versions, with an honest note when a tool is absent ...)"; for i2cdetect the archive instead carries an error string, silently degrading auditability of the kit. (`gpioinfo --version` is fine — libgpiod uses `getopt_long`.) No abort results (the substitution sits inside `echo` args, `set -e` does not fire — confirmed against the delivered output), so this is data-quality, not robustness.
**Fix:** Use the short flag and verify on target:
```bash
echo "i2cdetect: $(i2cdetect -V 2>&1 | head -1)"
```
(`i2cdetect -V` is the documented version flag in i2c-tools ≥ 4.x; it prints `i2cdetect version X.Y.Z`.) Consider re-running one sweep so the registered kit carries a real version, or annotate the existing artifacts' provenance line in the session log.

### WR-02: "Can never strand/wedge the session" guarantee is overstated — `timeout` without `-k` cannot bound an uninterruptible kernel sleep

**File:** `scripts/capture_dsi_dumps.sh:198` (claims at lines 12–15, 120, 195–197)
**Issue:** The echo-2 trigger is wrapped as `timeout 15 sh -c "echo 2 > '$NODE'"`, and the header, usage text, and inline comment all assert a wedged DSI read "can never strand the session" / "the session can never wedge on a hanging DSI read". GNU `timeout` without `-k` sends exactly one TERM and then waits for the child to die; a kernel write() stuck in uninterruptible sleep (D state) will not honor TERM, and timeout then blocks indefinitely. Nothing in userspace can bound that case (even SIGKILL does not reap D-state tasks). The real guarantee is the kernel-side bound the research verified (two `intel_de_wait_for_set_ms()` 50 ms waits per read, ≤ ~500 ms for the section) — the userspace wrap only bounds interruptible hangs. The claims as written promise a safety property the mechanism cannot deliver, in a phase whose binding rule is "never wedge the device session".
**Fix:** Reword the guarantees to what is true (e.g. "bounds interruptible hangs; the load-bearing bound is the kernel's 50 ms×2 per-read waits") and optionally harden the wrapper for the signal-ignoring-child case: `timeout -k 5 15 sh -c '...'` — while documenting that a true D-state wedge is unbounded from userspace by design.

## Info

### IN-01: `sh -c "echo 2 > '$NODE'"` interpolates the path through a shell string

**File:** `scripts/capture_dsi_dumps.sh:198`
**Issue:** The node path is embedded in a single-quoted `sh -c` string. Not exploitable today — `NODE` comes from a glob over kernel-created debugfs dentries (`/sys/kernel/debug/dri/*/i915_dsi_regs`) and the script already requires root — but the pattern is string-injection by construction and breaks if a path ever contains a single quote (legal in dentry names).
**Fix:** Pass the path as a positional parameter so it is never re-parsed:
```bash
if ! timeout 15 sh -c 'printf 2 > "$1"' _ "$NODE" 2>"$ERRFILE"; then
```

### IN-02: CI grep "landed" proofs are comment-satisfiable

**File:** `.github/workflows/build-kernel.yml:128-129`
**Issue:** `grep -R 'DCS ID READ'` and `grep -R 'mipi_dsi_dcs_read'` both match text that exists in the patch's own C comment block (`patches/d330_dsi_dump.patch:40` and `:198`), so both anchors would pass even if the executable half of the echo-2 code were absent. The workflow comment claims these "prove the echo-2 code landed in the CI tree"; they only prove the string landed.
**Fix:** Anchor at least one grep to a code-only string, e.g. `grep -q 'kstrtouint_from_user' drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c` or `grep -F 'ret=%zd avail=%u' ...`, so the proof cannot be satisfied by documentation.

### IN-03: Node write-side comment overstates echo-1 input compatibility

**File:** `patches/d330_dsi_dump.patch:421`
**Issue:** The comment "The node still accepts exactly what it accepted before for echo 1" is false for non-numeric bool tokens: `kstrtobool_from_user` accepted `y/Y/yes/on/true`; the new `kstrtouint_from_user` rejects them with `-EINVAL`. Values `0`/`1` behave identically and the repo's scripts only ever write `1`/`2`, so nothing breaks — but the compatibility claim as written would mislead anyone hand-driving the node.
**Fix:** Narrow the comment to what is true: "echo 1 and echo 0 behave identically; the old bool tokens (y/on/true) are no longer accepted."

### IN-04: Diff tool silently drops DCS rows with unknown tags

**File:** `scripts/dsi_mmio_diff.sh:174` (permissive parse) vs `:240` (pinned five-id render order)
**Issue:** `parse_arm` accepts any tag (`/^DCS [^ ]+ ret=.../`), but the comparison block only renders the pinned five (`0x04 0xDA 0xDB 0xDC GEN00`). A future node revision adding a sixth read would produce a `D` record that is counted nowhere: the capture script's (g2) gate still passes (it counts only the five canonical tags), and the diff's comparison block drops the extra row with no warning — exactly the "format drift silently swallowed" failure mode the pinned grammar was designed to prevent.
**Fix:** In the comparison awk's `END`, surface unmatched `seen[]` keys (tags outside the pinned order) as a loud warning line, or make `parse_arm` emit `W` for tags outside the pinned set.

### IN-05: The "read-only instrument" permanently mutates shared driver state

**File:** `patches/d330_dsi_dump.patch:290-291`
**Issue:** `dsi_dev->mode_flags |= MIPI_DSI_MODE_LPM;` and `dsi_dev->channel = 0` mutate the virtual `mipi_dsi_device` in place and are never restored. The instrument's contract language everywhere says "zero register writes, no mode changes"; this is a persistent software-state change on a driver-owned object. It is benign today (the flag change is additive and LP-safe, `channel = 0` matches the port-A default, and the VBT executor rewrites both per packet anyway — as the code comment notes), but the purity claim and the behavior diverge, and a future reader restoring neither could be surprised by debugfs-triggered state.
**Fix:** Save `mode_flags`/`channel` before forcing and restore them at the end of `d330_dsi_dump_id_reads()`, or amend the "read-only by contract" wording to disclose the one-way state nudge.

### IN-06: `MANIFEST.sha256` carries 10 duplicated entries (pre-existing, outside phase-50 lines)

**File:** `docs/dumps/re_kit/MANIFEST.sha256`
**Issue:** Ten files (`spi2.bin`, `vbt.bin`, `bios_raw_8dfae5d4.bin`, `igdkmd64.sys`, `iigd_dch.inf`, `iigd_ext.inf`, `gop_*`, `vbt_*`) each appear on two manifest lines. All lines hash-verify OK (both copies carry the correct hash), so `sha256sum -c` still exits 0 and the phase-50 claim `prepare_safety_kit.sh --verify` exit 0 holds. The duplication pre-dates phase 50 (the phase added only the 9 `tcon_*`/diff lines, each listed once), so this is a note for downstream tooling, not a phase-50 defect.
**Fix:** Optional cleanup: dedupe the manifest (one line per file) in a maintenance pass, and make any future `--verify` consumer tolerant of or strict about duplicates consistently.

---

_Reviewed: 2026-10-17T02:30:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
