# Phase 32: Data-Loss & Boot Safety Guards - Research

**Researched:** 2026-10-07
**Domain:** Bash safety-hardening of a single disk-partitioning/fstab tool (`tools/d330-microsd-setup.sh`)
**Confidence:** MEDIUM (official man pages fetched and quoted this session; exact target-hardware values and distro package mappings remain unverified)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Device Selection (audit C1)
- `--format` / `--mount-data` / `--mount-home` require an explicit `--device /dev/...`; the `/dev/mmcblk1` default applies only to `--probe`
- Missing `--device` on a destructive action: hard error with usage text, exit 1
- The "any non-`mmcblk0`" sysfs auto-substitution is removed entirely; sysfs scan output is informational only
- Refuse when the target backs `/` (`findmnt -n -o SOURCE /` prefix match) **or** when any partition of the target is mounted

#### Pre-Write Guards (audit C1)
- Guard order before `parted`/`mkfs`: (a) `lsblk -nr -o MOUNTPOINT` empty, (b) root-device prefix check, (c) typed `yes` confirmation — each fails fast with its own message
- `-F` removed from `mkfs.ext4`; guards now guarantee a blank, unmounted target
- `sleep 1` replaced by `partprobe "$TARGET_DEV"; udevadm settle`
- `--dry-run` executes every read-only guard, prints PASS/FAIL per guard, then the planned commands

#### fstab & Boot Safety (audit C2)
- fstab entry options: `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s`
- Parse proof: `findmnt --verify` on the written entry at install time; the test asserts `systemd-analyze verify` on a generated `.mount` unit when systemd is present
- Failed mount after append: trap rolls the fstab line back and exits non-zero
- Duplicate UUID: re-detect, refuse re-append, verify the existing line's options

#### `--mount-home` Stub
- Exits non-zero with a clear "not implemented" message; flag stays in `--help` marked unsupported
- "Storage expansion task complete." prints only when an action genuinely completed

### the agent's Discretion
- Exact log message wording, colour codes, and helper-function naming
- Ordering of informational output and help-text layout

### Deferred Ideas (OUT OF SCOPE)
- Full `/home` migration implementation (would need its own phase: rsync, user homedir moves, rollback)
</user_constraints>

## Summary

Phase 32 rewrites the safety posture of one 129-line bash script, `tools/d330-microsd-setup.sh`, which today can destroy disks through three cooperating defects: an unconditional sysfs auto-substitution that reassigns `TARGET_DEV` to "any non-`mmcblk0` device" [VERIFIED: tools/d330-microsd-setup.sh:55-66], a `parted -s ... mklabel gpt` that writes the moment the `format` branch runs with zero guards [VERIFIED: tools/d330-microsd-setup.sh:94], and `mkfs.ext4 -F` [VERIFIED: tools/d330-microsd-setup.sh:96]. The boot-hang path (audit C2) is the fstab append at `:112` which writes `noatime,lazytime,commit=60` with no `nofail`, combined with `mount "$MOUNT_POINT" || true` [VERIFIED: tools/d330-microsd-setup.sh:113] that swallows failure while line `:129` unconditionally prints success. All research this session converges on three planner-critical facts: (1) the ROADMAP's literal guard (b) wording ("`findmnt -n -o SOURCE /` must not be a prefix of `TARGET_DEV`") is **directionally wrong for the most dangerous case** — root source `/dev/mmcblk0p3` is *not* a prefix of whole-disk target `/dev/mmcblk0`, so the check must be bidirectional; (2) `systemd-analyze verify` returns exit 0 regardless of warnings unless `--recursive-errors=MODE` is passed (added systemd v250), so success criterion 2 cannot be asserted on exit code alone; and (3) `PART_DEV="${TARGET_DEV}p1"` [VERIFIED: tools/d330-microsd-setup.sh:86] breaks the moment `--device /dev/sdX` is accepted (partition would be `/dev/sdX1`, not `/dev/sdXp1`), a defect that only becomes reachable once explicit `--device` ships.

**Primary recommendation:** plan the phase as a single-file rewrite of `tools/d330-microsd-setup.sh` (parser loop included — the current `for arg in "$@"` loop at `:41-51` cannot consume a `--device` *value*), plus a narrowly scoped extension of `scripts/test_storage_cellular.sh` for the three success criteria, using dry-run + mocked-PATH command stubs as the default test technique and loop devices as the optional root-only integration path.

## Architectural Responsibility Map

This phase is a single-tier local CLI tool — no browser/API/database tiers exist. The map records *which layer of the local system* owns each capability so tasks are not misassigned:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Device selection & pre-write guards | CLI tool (user-space, `tools/*.sh`) | — | Only the tool itself can refuse before `parted`/`mkfs` write |
| `--device` parsing / validation | CLI tool (argument parser) | — | Lock: missing `--device` on destructive action = exit 1 |
| Partition re-read after `parted` | OS kernel via `partprobe` + `udevadm settle` | CLI tool invokes | Tool must delegate to kernel/udev, not `sleep` |
| fstab boot behavior (`nofail`, device timeout) | OS init (`systemd-fstab-generator` → `.mount` units) | CLI tool writes the line | Semantics are defined by systemd at boot, not by the script |
| Parse proof of fstab entry | Test harness (`scripts/test_*.sh`) | `findmnt --verify` / `systemd-analyze verify` | Locked: `findmnt --verify` at install time, `systemd-analyze verify` in test |
| Guard regression coverage | Test harness | — | Success criteria 1–3 must be machine-checked |

## Current State

**File:** `tools/d330-microsd-setup.sh` — 129 lines, `set -euo pipefail` [VERIFIED: tools/d330-microsd-setup.sh:8], colour helpers `log_info/log_ok/log_warn/log_err` [VERIFIED: tools/d330-microsd-setup.sh:16-19].

### Control flow today (line-by-line)

1. `:37-39` — `TARGET_DEV="/dev/mmcblk1"`, `ACTION="probe"`, `DRY_RUN=0`.
2. `:41-51` — parser loop `for arg in "$@"; do case "$arg" in --probe|--format|--mount-data|--mount-home|--dry-run|--help|-h ...`. **Iteration-style loop: no `shift`, cannot consume an option value.** Adding `--device /dev/...` requires converting to a `while [[ $# -gt 0 ]]` / `shift` loop (house precedent below).
3. `:55-66` — **Unsafe path A (audit C1):** if default `/dev/mmcblk1` is not a block device, scan `/sys/block/mmcblk*` and adopt the first device whose name is not `mmcblk0`:
   ```bash
   if [ "$NAME" != "mmcblk0" ]; then
       log_ok "Found secondary SD card: /dev/$NAME"
       TARGET_DEV="/dev/$NAME"
   ```
   [VERIFIED: tools/d330-microsd-setup.sh:60-63] — on hardware where the SD reader enumerates differently (or the default *does* exist but is the wrong disk), the tool formats whatever it picked. Runs for **all** actions, not just `probe`.
4. `:68-79` — `probe` action: `lsblk` display, exit 0. Non-root safe (exits before root check).
5. `:81-84` — root check: `if [ "$EUID" -ne 0 ] && [ $DRY_RUN -eq 0 ]` → dry-run permitted unprivileged (keep — tests depend on it).
6. `:86` — `PART_DEV="${TARGET_DEV}p1"` — **p-suffix hard-coded**; wrong for `/dev/sdX`/`/dev/vdX` targets (`/dev/sdXp1` does not exist).
7. `:88-99` — **Unsafe path B:** `format` branch. Dry-run prints `[DRY-RUN] parted ...` and `[DRY-RUN] mkfs.ext4 -F ...` [VERIFIED: tools/d330-microsd-setup.sh:91-92]. Real run executes with **no guards whatsoever**:
   ```bash
   parted -s "$TARGET_DEV" mklabel gpt mkpart primary ext4 1MiB 100%
   sleep 1
   mkfs.ext4 -F -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE "$PART_DEV"
   ```
   [VERIFIED: tools/d330-microsd-setup.sh:94-96] — `parted -s` is non-interactive and silent; it destroys the partition table of any device before `mkfs` is even reached. The mount-empty/root-prefix/typed-`yes` guards must therefore all sit **before line 94**, not merely before `mkfs`.
8. `:101-122` — `mount-data` branch. Dry-run line 106 prints the fstab entry **without** `nofail`: `echo "[DRY-RUN] Append to /etc/fstab: UUID=... $MOUNT_POINT ext4 noatime,lazytime,commit=60 0 2"` [VERIFIED: tools/d330-microsd-setup.sh:106]. Real run: `UUID=$(blkid ...)`, grep for duplicate, append `echo "UUID=$UUID $MOUNT_POINT ext4 noatime,lazytime,commit=60 0 2" >> /etc/fstab` [VERIFIED: tools/d330-microsd-setup.sh:112], then `mount "$MOUNT_POINT" || true` [VERIFIED: tools/d330-microsd-setup.sh:113] — failure swallowed, no rollback. Note `:109` sets `UUID` but on the empty path only logs `log_err` at `:119` and **falls through** to the success message (no `exit 1` under `set -e` because the `|| true` at `:109` already succeeded).
9. `:124-127` — **Unsafe path C:** `mount-home` stub: prints two log lines, does nothing, falls through.
10. `:129` — `log_ok "Storage expansion task complete."` — printed unconditionally for `mount-data` (even on UUID failure) and for the `mount-home` no-op.

### What "abort before any write" must cover
The first write in the whole program is `parted -s ... mklabel gpt` at `:94` (probe writes nothing; dry-run writes nothing). Success criterion 1 ("`--format` on a device with a mounted partition aborts before any write") is satisfied only if guard (a) runs and exits before `:94`.

## Invocation Surface

| Caller | How it invokes | What changes for Phase 32 |
|--------|----------------|---------------------------|
| `scripts/install_dkms.sh:246-248` | `cp tools/d330-microsd-setup.sh /usr/local/bin/d330-microsd-setup && chmod +x` — deploy only, never executes it | None (deploy unchanged; uninstall `:410` `rm -f /usr/local/bin/d330-microsd-setup`) |
| `scripts/test_storage_cellular.sh:63` | `bash tools/d330-microsd-setup.sh --probe` (cwd-relative path) | `--probe` must keep working **without** `--device` (lock: default `/dev/mmcblk1` applies only to `--probe`) and without root |
| `scripts/test_storage_cellular.sh:78` | `--test-microsd` mode = byte-identical `bash tools/d330-microsd-setup.sh --probe` | Same as above. Audit already flags this alias + the fake `fcc-unlock.d/8086:7360` `[OK]` print as Phase 41 items (ROADMAP:258) — do **not** re-litigate in Phase 32 |
| `scripts/test_storage_cellular.sh:51-58` | `--dry-run` mode prints three hardcoded paths, never calls the tool | New guard-output assertions need a **new** mode or direct calls to the tool's own `--dry-run` (see Test Strategy) |
| `scripts/build_live_iso.sh` / CI workflows | No reference to the tool anywhere | None |
| `README.md` | **No mention** of `d330-microsd-setup`, `--format`, `--mount-data`, `--mount-home`, or `mmcblk1` (grep-verified this session) | No README edit required this phase |
| `CHANGES_AUDIT.md:441` | Table row: `tools/d330-microsd-setup.sh` → `/usr/local/bin/d330-microsd-setup` "MicroSD automated partitioner" | Unchanged |
| `CHANGES_AUDIT.md:477` | Checklist: "`tools/d330-microsd-setup.sh` only targets user-specified removable media" — **false today, true after Phase 32** | Doc claim becomes honest automatically; claims-update ownership is Phase 42 per CONTEXT integration notes |
| `docs/research/MICROSD_CELLULAR_LTE.md:5` | Claims fstab options are `noatime,commit=60,errors=remount-ro` — **already drifted** from code (`noatime,lazytime,commit=60`) and will drift further with `nofail,x-systemd.device-timeout=10s` | Phase 42 doc-parity owns the fix; note only |
| `.gsd/WORKLOG.md:266` | Claims tool mounts `/data` **or `/home`** | Drifts again when `--mount-home` starts exiting non-zero; Phase 42 |
| `.github/workflows/build-packages.yml:26` | `cp tools/d330-* build/deb/usr/local/bin/ \|\| true` on tag push — ships whatever the file becomes | No CI check of content; no lint gate exists |
| Packaged installs (`.deb`/`.rpm`/`PKGBUILD`) | All three install `tools/d330-*` to `/usr/local/bin` | Script gains runtime need for `partprobe` (parted) — **not declared** in any packaging deps today |

No other caller exists (grep-verified: `d330-microsd-setup|partprobe|udevadm settle|findmnt|lsblk` across the repo).

## Repo Conventions

House style for shell tools and tests, all verified this session:

1. **Strict mode:** every `tools/*.sh` and `scripts/*.sh` starts `set -euo pipefail` (e.g. tools/d330-microsd-setup.sh:8, scripts/install_dkms.sh:9, scripts/test_storage_cellular.sh:5). Keep.
2. **Colour log helpers, fail fast:** `log_err "..."; exit 1` pattern — precedent is the root check [VERIFIED: tools/d330-microsd-setup.sh:81-84]. Note `install_dkms.sh:29` sends `log_err` to stderr (`>&2`), the microsd tool sends to stdout — either is house-acceptable; stderr is the better pick for new guard errors (agent's discretion).
3. **Option parsing:** two coexisting styles — `for arg in "$@"` (microsd tool, cannot take values) and `while [[ $# -gt 0 ]] ... shift` (install_dkms.sh:456-464, all `scripts/test_*.sh`). **`--device /dev/...` requires the `while`/`shift` style**; converting the microsd parser matches the majority house pattern.
4. **Dry-run:** print `[DRY-RUN] <cmd>` instead of executing [VERIFIED: tools/d330-microsd-setup.sh:90-93, 104-107]; `install_dkms.sh` additionally prints a banner `log_warn "Operating in DRY-RUN mode..."` (`:466-468`). Phase 32 extends this: dry-run prints `PASS`/`FAIL` per guard (locked), then the planned commands.
5. **Help text:** `show_help() { cat <<EOF ... EOF }` with `--help|-h) show_help; exit 0` [VERIFIED: tools/d330-microsd-setup.sh:21-35, 48].
6. **Optional-tool tolerance:** repo convention `command -v X >/dev/null 2>&1` fallbacks (install_dkms.sh:154, d330-fastboot-tune.sh:13, CHANGES_AUDIT auditor checklist item 2 at `:480`). New dependencies (`partprobe`, `udevadm`, `findmnt`) should follow this instead of hard-failing, where safety permits (see Linux/Distro Notes for which may be skipped).
7. **Test scripts:** plain bash, `MODE="probe"` + `while`/`shift` parser, banner echoes, `--probe`/`--dry-run`/`--help`. No bats/pytest/shellcheck anywhere in the repo (glob-verified: no `.shellcheckrc`, no `Makefile`, no `package.json`, no `*.bats`).
8. **CWD anchoring:** `install_dkms.sh:11-12` uses `SCRIPT_DIR`/`REPO_ROOT`; most `test_*.sh` (including `test_storage_cellular.sh:63`) use cwd-relative `tools/...`. ROADMAP Phase 41 owns the repo-wide fix — Phase 32 test additions should use the `test_resume_loop.sh:17-18` `SCRIPT_DIR` pattern for *new* lines but must not refactor the whole file.

## Standard Stack

No new packages are installed by this phase. The stack table documents the **runtime tools the rewritten script calls** and where their behaviour was verified.

### Core (invoked by the tool)
| Tool | Source package | Purpose | Why Standard / Status |
|------|----------------|---------|------------------------|
| `lsblk` | util-linux (essential on all target distros) | Guard (a): mountpoint emptiness of target + children | `lsblk(8)` official man fetched [CITED: https://man7.org/linux/man-pages/man8/lsblk.8.html] |
| `findmnt` | util-linux | Guard (b): root SOURCE; install-time parse proof `findmnt --verify` | `findmnt(8)` official man fetched [CITED: https://man7.org/linux/man-pages/man8/findmnt.8.html] |
| `parted` / `partprobe` | parted (**not** in any packaging Depends today) | Partition + kernel table re-read | `partprobe(8)` from Debian packaged man [CITED: https://manpages.debian.org/stable/parted/partprobe.8.en.html] |
| `udevadm` | systemd (guaranteed: phase requires systemd anyway) | Post-parted device-node settle | [ASSUMED: package ownership per distro — Debian/Fedora/Arch all ship udevadm in the `systemd` package; not verified this session] |
| `mkfs.ext4` | e2fsprogs (Debian essential; present on all targets) | Format, **without** `-F` after guards | `mke2fs(8)` official man fetched [CITED: https://manpages.debian.org/stable/e2fsprogs/mke2fs.8.en.html] |
| `blkid` | util-linux | UUID resolve (already used `:109`) | Existing |
| `systemd-analyze verify` | systemd | Test-side proof of generated `.mount` unit | `systemd-analyze(1)` official man fetched [CITED: https://manpages.debian.org/stable/systemd/systemd-analyze.1.en.html] |
| `bash` ≥ 4 | bash | Script runtime; `[[ ]]`, arrays | Git Bash 5.2.21 present locally; WSL available (Environment Availability) |

**Installation:** none (no package changes). ⚠️ Open question: whether adding `parted` to `packaging/debian/control` Depends / PKGBUILD `depends` / RPM `Requires` belongs to this phase or Phase 42 — CONTEXT scopes changes to the one script (see Risks #4).

**Version verification:** no `npm view`/registry step applies (not a package-install phase). Man-page versions actually fetched: util-linux 2.43.devel, systemd 257.13 (Debian trixie), e2fsprogs 1.47.2, parted 3.6-5.

## Package Legitimacy Audit

Not applicable — this phase installs **zero** external packages (bash edits only). No `package-legitimacy check` required.

## Test Strategy

### What the harness asserts today (`scripts/test_storage_cellular.sh`)
- `--probe` (and its alias `--test-microsd`): runs `bash tools/d330-microsd-setup.sh --probe` and exits 0 [VERIFIED: scripts/test_storage_cellular.sh:60-80]. No assertions; no failure counter (always-green pattern — Phase 41 audit item, ROADMAP:258).
- `--dry-run`: echoes three hardcoded paths including the non-existent `fcc-unlock.d/8086:7360` as verified, then `exit 0` [VERIFIED: scripts/test_storage_cellular.sh:51-57]. Never touches the tool.
- Therefore **none of the three Phase 32 success criteria is checkable by the harness as-is.** New coverage must be added; keep it minimal and self-contained so Phase 41 (test-trust overhaul) can rework it later without conflict.

### Recommended test layers (in order of cost)

1. **`--dry-run` guard assertions (locked success criterion 3, no root, no disks).**
   Run the tool with a chosen `--device` and grep its output:
   - `--format --dry-run --device /dev/mmcblk1` → expect three `PASS`/`FAIL` guard lines + `[DRY-RUN] parted ...` / `[DRY-RUN] mkfs.ext4 ...` planned commands (updated, no `-F`).
   - Missing `--device` with `--format` → expect exit 1 + usage text (locked decision).
   - `--mount-home` → expect exit non-zero + "not implemented" (locked decision).
   Dry-run executes the read-only guards against the real system (locked: "`--dry-run` executes every read-only guard") — on a dev box with no `/dev/mmcblk1`, guards must **FAIL/abort cleanly**, not crash: this is itself a useful assertion (lsblk exit 32 handling, see Pitfall 4).
2. **Mocked-command PATH shims (fast, no root, deterministic PASS *and* FAIL cases).**
   Create a temp dir containing fake `lsblk`, `findmnt`, `blkid`, `parted`, `mkfs.ext4`, `mount`, `udevadm`, `partprobe` scripts that print canned outputs and record invocations (a "canary" file: if `parted`/`mkfs.ext4` ever run in a must-abort case, the canary proves the guard failed). Invoke the tool as `PATH="$SHIM_DIR:$PATH" bash tools/d330-microsd-setup.sh ...`. This is the only technique that can simulate "root SOURCE overlaps target" on any machine. **Technique rationale is [ASSUMED]** (standard bash practice; no repo precedent exists — first shim-based test in this codebase).
3. **Loop-device integration (root-only, optional, real end-to-end).**
   `truncate -s 64M disk.img && losetup -f --show disk.img`, run real `parted`/`mkfs`/`partprobe` against the loop device; mount a loop partition to a temp dir and assert `--format` aborts before writing (guard (a) true-positive on a genuinely mounted partition). Requires Linux + root (WSL or target hardware). `losetup` is util-linux [CITED: https://man7.org/linux/man-pages/man8/losetup.8.html — general availability; loop-device recipe itself is [ASSUMED]]. Not required by the success criteria; mark as manual/optional so the wave gate does not depend on it.
4. **fstab parse proof (success criterion 2).**
   - Install-time (locked): `findmnt --verify` against the written entry — run it on a **temp tab file**: `findmnt --verify --tab-file <candidate>` (supported: "It's possible to use this option also with `--tab-file`" [CITED: https://man7.org/linux/man-pages/man8/findmnt.8.html]); or env `LIBMOUNT_FSTAB=<path>` override. Never append to the *real* `/etc/fstab` inside tests.
   - Test-side (locked): generate a `.mount` unit from the fstab line and run `systemd-analyze verify` when systemd is present. **Two hard constraints from the man page** (Linux/Distro Notes 5): filename must end in `.mount`, and exit code is 0-on-warnings unless `--recursive-errors=yes` is passed (systemd ≥ 250). On older systemd, parse output text instead of exit code.

### Requirement → test map

| Criterion (ROADMAP) | Behavior under test | Test type | Automated command (sketch) | File |
|---|---|---|---|---|
| SC1 | `--format` aborts before any write when a partition of target is mounted | unit (shim: canned non-empty lsblk output → assert no `parted` canary) + optional loop integration | `PATH="$SHIM:$PATH" bash tools/d330-microsd-setup.sh --format --device /dev/mmcblk1` → exit ≠ 0, canary absent | `scripts/test_storage_cellular.sh` (new mode) or new `scripts/test_microsd_guards.sh` — see Risks #2 |
| SC1b | root-overlap target refused (guard b, bidirectional) | unit (shim: `findmnt` returns `/dev/mmcblk0p3`, target `/dev/mmcblk0` **and** the reverse) | as above, two cases, both exit ≠ 0 before `parted` | same |
| SC1c | missing `--device` on destructive action | unit | `bash tools/d330-microsd-setup.sh --format --dry-run` → exit 1 + usage | same |
| SC2 | fstab line parses | integration (temp tab) + unit (generated `.mount`) | `findmnt --verify --tab-file tmp` ; `systemd-analyze verify ./data.mount [--recursive-errors=yes]` | same |
| SC3 | dry-run prints guard outcomes | unit | `bash tools/d330-microsd-setup.sh --format --dry-run --device /dev/mmcblk1` → grep `PASS`/`FAIL` per guard | same |
| SC4 | `--mount-home` exits non-zero "not implemented" | unit | `bash tools/d330-microsd-setup.sh --mount-home --device /dev/x` → exit ≠ 0, no "task complete" | same |
| regression | `--probe` unchanged, non-root, no `--device` | smoke | `bash tools/d330-microsd-setup.sh --probe` (existing harness line 63/78 keeps passing) | existing file |

**Quick run command:** `bash -n tools/d330-microsd-setup.sh && bash scripts/test_storage_cellular.sh --probe` (syntax + existing smoke).
**Full suite:** `for f in scripts/test_*.sh; do bash -n "$f"; done` plus the new guard-mode invocation (full 27-script run is Phase 41's concern).

## Linux/Distro Notes

### 1. Guard (a): `lsblk -nr -o MOUNTPOINT` semantics [CITED: https://man7.org/linux/man-pages/man8/lsblk.8.html]
- `-r` = raw (one line per device row, no header with `-n`, columns whitespace-separated), `-n` = no headings. Output covers the **whole disk row first, then each partition row** (dependency order).
- Unmounted rows print an **empty line** (empty MOUNTPOINT field). So "output must be empty" = every row unmounted. Must be scoped: `lsblk -nr -o MOUNTPOINT "$TARGET_DEV"` — *without* the device argument it lists **every** block device on the system, whose non-empty root mountpoint would make guard (a) always FAIL (roadmap wording omits the arg; planner must add it).
- Man page: "The column MOUNTPOINT displays only one mount point ... MOUNTPOINTS displays ... all mount points" — use `MOUNTPOINT` as locked; fine for this tool.
- Raw mode "hex-escapes" unsafe characters in MOUNTPOINT (e.g. space → `\x20`) — irrelevant for emptiness testing but matters if the test greps mountpoint text.
- **Exit codes: 0 success, 1 failure, 32 "none of specified devices found", 64 "some found some not."** Under `set -e` + command substitution with `|| true`, a vanished/nonexistent device yields *empty output* → guard (a) would PASS vacuously. Guard (a) must be preceded by an explicit `[ -b "$TARGET_DEV" ]` existence check for destructive actions (the current `-b` check at `:55` only covers the default path).
- Man page endorses this phase's sequencing decision: "it is recommended to use `udevadm settle` before `lsblk` to synchronize with udev" — apply the same settle before guard evaluation right after `parted`.

### 2. Guard (b): `findmnt -n -o SOURCE /` and the prefix-direction bug
- `findmnt -n -o SOURCE /` prints the kernel-mountinfo source of `/` — on this device expected to be the eMMC partition `/dev/mmcblk0p?` **[ASSUMED**: exact string must be captured on target hardware with the command itself; some setups show `/dev/mapper/...` or `/dev/root`**]**. [CITED for command semantics: https://man7.org/linux/man-pages/man8/findmnt.8.html]
- **Critical logic finding:** ROADMAP:90 says the check is "root SOURCE must not be a **prefix of** `TARGET_DEV`". Evaluate the dangerous case: TARGET = `/dev/mmcblk0` (user explicitly passes the whole root disk), SOURCE = `/dev/mmcblk0p3`. Is `/dev/mmcblk0p3` a prefix of `/dev/mmcblk0`? **No (SOURCE is longer)** → guard passes → `parted mklabel gpt` wipes the root disk. The literal one-directional check only catches the case where the user passes a *partition of* the root disk (`TARGET=/dev/mmcblk0p3`, SOURCE equal or shorter... equality does pass). **The guard must be bidirectional:**
  ```bash
  # FAIL if either string is a prefix of the other (boundary-safe enough for /dev/* naming)
  case "$ROOT_SRC" in
    "$TARGET_DEV"|"$TARGET_DEV"*) log_err "...target is root or parent of root"; exit 1 ;;
  esac
  case "$TARGET_DEV" in
    "$ROOT_SRC"*) ... same ... ;;
  esac
  ```
  This stays within the locked decision ("`findmnt -n -o SOURCE /` prefix match") — it fixes the *direction*, which is a correctness matter, not a wording/ discretion matter. **Flag prominently in the plan.**
- Robustness upgrade if the string prefix proves fragile on hardware: resolve the parent disk of root (`lsblk -no PKNAME "$(findmnt -n -o SOURCE /)"` → `mmcblk0`) and compare basenames. [ASSUMED: `PKNAME` availability — util-linux ≥ 2.27; present on all modern targets.]
- Guard (a) and (b) overlap: if root's partition is mounted (always true for root disk), guard (a) scoped to the target already fails when target *is* root's disk or contains it. Guard (b) remains necessary for: target = parent disk where lsblk rows show only *unmounted* siblings… realistically (b) is defence-in-depth and is **locked**, so implement both regardless.

### 3. `partprobe` + `udevadm settle` replacing `sleep 1`
- `partprobe`: "informs the operating system kernel of partition table changes" [CITED: https://manpages.debian.org/stable/parted/partprobe.8.en.html]; ships in the **`parted` package on Debian** (manpage provenance: "from parted 3.6-5"). [ASSUMED: `parted` is the providing package on Fedora/RHEL and Arch as well — verify with `dnf whatprovides`/`pacman -Qo` at execution time.]
- `udevadm`: [ASSUMED] provided by the `systemd` package on Debian/Fedora/Arch (not verified this session; systemd is guaranteed present because success criterion 2 requires `systemd-analyze`).
- Sequencing per lsblk man (recommends settle before lsblk): `parted ... ; partprobe "$TARGET_DEV"; udevadm settle` then mkfs on the new partition node. Under `set -e`, a `partprobe` failure aborts the tool **before** mkfs — correct fail-safe behaviour; keep it un-`||true`-ed or log-and-abort explicitly.
- Availability caveat: **none of the three packaging recipes declares `parted`** (verified: `packaging/debian/control:11-12` Depends/Recommends, `packaging/arch/PKGBUILD:9-11`, `packaging/rpm/lenovo-d330-fix.spec:10-14`). On a minimal install `partprobe` may be absent while `parted`… is also absent — the tool already hard-requires `parted` (`:94`) without a `command -v` check. Recommend a `command -v parted partprobe udevadm` prerequisite check with actionable `log_err` (house pattern, install_dkms.sh:50-68) — falls within "helper-function naming/wording" discretion.

### 4. `mkfs.ext4` and `-F` [CITED: https://manpages.debian.org/stable/e2fsprogs/mke2fs.8.en.html]
Man page verbatim: "`-F` — Force mke2fs to create a file system, even if the specified device is not a partition on a block special device, or if other parameters do not make sense. In order to force mke2fs to create a file system even if the file system appears to be in use or is mounted (a truly dangerous thing to do), this option must be specified twice."
- Today's **single** `-F` therefore does *not* override the mounted check (that needs `-FF`) — but it does override the "parameters do not make sense" / non-partition-device protections, and combined with `parted` having already wiped the table the data is gone regardless. Removing `-F` entirely (locked) means mke2fs falls back to its interactive/defensive path; because guard (c) requires a typed `yes` before any write and stdin will be the user's terminal, this is coherent. **[ASSUMED]** the exact prompt/abort behaviour of `mke2fs` on an existing signature when stdin is non-interactive (man page fetched does not document the prompt) — if a test drives `mkfs` without `-F` on a signed device via shim it does not matter; on loop integration, expect an interactive prompt or refusal.
- `-n` exists ("Causes mke2fs to not actually create a file system, but display what it would do") — useful for dry-run fidelity if desired (discretion).

### 5. `systemd-analyze verify` on a generated `.mount` unit [CITED: https://manpages.debian.org/stable/systemd/systemd-analyze.1.en.html]
- `verify FILE...` loads unit files; detects "unknown sections and directives", "missing dependencies which are required to start the given unit", missing man pages, missing `ExecStart` commands.
- **Filename must be a unit name:** a plain file fails with `Failed to prepare filename /tmp/source: Invalid argument` (man example); the test must write e.g. `data.mount` (unit name for `/data` — mount units are named after the mount point, "the mount point /home/lennart must be configured in a unit file home-lennart.mount" [CITED: https://manpages.debian.org/stable/systemd/systemd.mount.5.en.html]). Colon-aliasing (`./tmpfile:data.mount`) also works.
- **Exit-code trap (planner-critical):** "If this option [`--recursive-errors=MODE`] is not specified, **zero is returned as the exit status regardless whether warnings arise** during verification or not." `--recursive-errors` was added in **systemd v250** (Debian bookworm 252 ✓, trixie 257 ✓; Ubuntu 22.04 = 249 ✗). Test must either pass `--recursive-errors=yes` when `systemd-analyze --help` advertises it, or assert on captured output text (fail on `Unknown`/`Failed`/`Error` patterns) — and still run `findmnt --verify` as the locked install-time proof.
- **fstab-only option caveat:** `x-systemd.device-timeout=` "can only be used in `/etc/fstab`, and will be ignored when part of the `Options=` setting in a unit file" [CITED: systemd.mount(5)]. A generated `.mount` carrying `Options=noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s` will have the device-timeout silently ignored (not an error). The `nofail` half *does* translate to unit semantics ("this mount will be only wanted, not required, by local-fs.target ... boot will continue without waiting ... regardless whether the mount point can be mounted successfully" [CITED: systemd.mount(5), added v215]) — that is exactly audit C2's remediation.

### 6. fstab entry format (locked option string + dump/pass fields)
Locked options verbatim from CONTEXT: `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s`. Full line shape follows existing `:112` (`UUID=$UUID /data ext4 <opts> 0 2`) — pass/dump numbers `0 2` unchanged unless a doc-parity reason emerges (discretion). `findmnt --verify` checks "parsability and usability" of the entry — run it on a temp tab file pre-append; if it reports problems, abort without touching `/etc/fstab` (aligns with the locked rollback intent).
- Existing-line path (locked: "Duplicate UUID: re-detect, refuse re-append, verify the existing line's options"): `grep -q "$UUID" /etc/fstab` at `:111` already detects; extend to parse the found line's options and FAIL if `nofail` is missing (old deployments) with an actionable message — deciding whether to auto-upgrade such lines is **open question #3**.

### 7. Swap caveat [ASSUMED]
`lsblk MOUNTPOINT` is empty for a partition actively used as **swap** (swap is not a mountpoint). Guard (a) as specified would PASS, then `parted`/`mkfs` would rewrite an active-swap device (kernel keeps writing → corruption). Low likelihood on this device (zram-only swap per audit C3), but the cheap hardening is to also refuse when `TARGET_DEV` or any child appears in `/proc/swaps`. Not in the locked guard list — flag for discuss/planner as optional guard (a2), wording at discretion.

### 8. Target distro packaging matrix
- `.deb` build (CI, tag-only): copies `tools/d330-*` raw — no lint, no `bash -n`, no test execution anywhere in `.github/workflows/` (both workflow files read in full this session: build-packages.yml, build-iso.yml — no lint/test step exists).
- Repo's only "gate" is the human/auditor checklist claim `CHANGES_AUDIT.md:482`: "Bash scripts: Checked via `bash -n` across all scripts with zero syntax errors" — make `bash -n tools/d330-microsd-setup.sh` part of the phase's per-commit verification (house rule mirrors global AGENTS.md verification requirement).
- Distro runtime deps for the new calls are undeclared (see Note 3) → open question #4.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting what's mounted on target | custom `/proc/mounts` parsing with awk | `lsblk -nr -o MOUNTPOINT "$TARGET_DEV"` | handles partitions, holders, udev races (plus `udevadm settle` first) |
| Checking whether target backs `/` | manual `stat` of `/` device numbers vs target | `findmnt -n -o SOURCE /` + prefix/`PKNAME` compare | resolves mountinfo once, no reinvented devnode logic |
| Telling kernel about new partition table | fixed `sleep 1` | `partprobe "$TARGET_DEV"; udevadm settle` | deterministic, event-driven; endorsed by lsblk(8) |
| Validating an fstab line | hand-written regexes for fstab grammar | `findmnt --verify --tab-file <file>` | util-linux implements full fstab parse/usability rules |
| Validating a `.mount` unit | bespoke unit-syntax linter | `systemd-analyze verify <file>.mount --recursive-errors=yes` | authoritative systemd parser |
| Deriving `p1` partition name | string concat `"${dev}p1"` | `lsblk -lnpo NAME,TYPE "$TARGET_DEV" \| awk '$2=="part"{print $1; exit}'` (first partition, field 1 only — a bare `awk` action prints the whole line and would yield `/dev/xxx1 part`) after settle | correct for `sdX`/`mmcblk`/`nvme` naming alike |

**Key insight:** every guard delegates to the same five util-linux/systemd binaries the OS itself uses; hand-rolled equivalents diverge exactly at the edge cases (naming schemes, udev lag, mountinfo formats) where this tool's audit failures originated.

## Common Pitfalls

### Pitfall 1: Guard (b) prefix direction (planner-critical)
**What goes wrong:** literal one-directional prefix check misses `TARGET=/dev/mmcblk0` vs `SOURCE=/dev/mmcblk0p3` → root disk wiped.
**Why it happens:** ROADMAP wording reads "SOURCE must not be a prefix of TARGET"; human intuition assumes the dangerous device is always the *longer* string.
**How to avoid:** bidirectional prefix test (Linux/Distro Notes §2) + both cases in the shim test matrix (SC1b).
**Warning signs:** a test that only covers "target is a partition of root" but never "target is the whole root disk".

### Pitfall 2: Unscoped `lsblk` in guard (a)
**What goes wrong:** `lsblk -nr -o MOUNTPOINT` without `"$TARGET_DEV"` lists the whole system → guard always FAILs (annoying but safe), or is then "fixed" by dropping the check → unsafe.
**How to avoid:** always scope to the device; assert in test.

### Pitfall 3: Guards placed before `mkfs` but after `parted`
**What goes wrong:** abort logic added at the `mkfs` line still lets `parted -s ... mklabel gpt` (first write, `:94`) destroy the table.
**How to avoid:** all three guards execute before line 94; shim canary on `parted` proves it.

### Pitfall 4: `lsblk` exit 32/64 + `set -e` + command substitution
**What goes wrong:** nonexistent/vanished device → empty substitution → guard vacuous-PASS, or unexpected script exit with no message.
**How to avoid:** explicit `[ -b "$TARGET_DEV" ]` for destructive actions before guards; capture with `|| rc=$?` and treat non-zero as guard FAIL with `log_err`.

### Pitfall 5: Asserting `systemd-analyze verify` on exit code alone
**What goes wrong:** verify prints warnings but exits 0 (no `--recursive-errors`, or systemd < 250) → false-green success criterion 2.
**How to avoid:** `--recursive-errors=yes` when supported, else output-pattern assertion; keep `findmnt --verify --tab-file` as second, independent proof.

### Pitfall 6: `x-systemd.device-timeout` in a generated unit's `Options=`
**What goes wrong:** silently ignored in unit context; test "proves" a timeout the boot path never applies.
**How to avoid:** assert the *fstab* line (install-time `findmnt --verify` + grep) for that option; treat unit verify as syntax proof only.

### Pitfall 7: Parser cannot carry `--device` value
**What goes wrong:** bolting `--device)` onto the `for arg in "$@"` loop makes `/dev/mmcblk1` hit the `*) Unknown option` branch → exit 1 (or worse, silently ignored if wildcard loosened).
**How to avoid:** convert to `while [[ $# -gt 0 ]] ... shift` (house pattern, install_dkms.sh:456-464); test both orders (`--format --device X` and `--device X --format`).

### Pitfall 8: `PART_DEV="${TARGET_DEV}p1"` vs `/dev/sdX1`
**What goes wrong:** explicit `--device /dev/sda` (USB stick) → tool tries `mkfs.ext4 ... /dev/sdap1` → fails after the table is already rewritten; user sees error, disk is already wiped (by design at that point — but the *format* reported failure misleadingly), and re-run confusion follows.
**How to avoid:** derive the partition node from `lsblk` after `partprobe; udevadm settle` (Don't Hand-Roll row 6).

### Pitfall 9: `mount ... || true` + unconditional success line
**What goes wrong:** rollback trap never fires because `|| true` swallows the failure; "Storage expansion task complete." prints anyway (current `:113`+`:129`).
**How to avoid:** locked design — trap on failed mount, remove appended fstab line, exit non-zero; print completion only on genuine success paths.

### Pitfall 10: Dry-run without `--device` on a diskless CI/dev box
**What goes wrong:** success criterion 3 test runs `--format --dry-run` with default device absent → guards produce confusing output or crash instead of deterministic FAIL lines.
**How to avoid:** tests always pass `--device` explicitly; guard (a)/(b) failures print their own `log_err` and dry-run still prints `FAIL` per guard (locked PASS/FAIL output) rather than aborting silently — decide exact dry-run-vs-fail interplay in the plan (guard FAIL in dry-run = print FAIL + skip planned commands; wording discretionary).

## Validation Architecture

> Enabled: `.planning/config.json` → `workflow.nyquist_validation: true` (read this session).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — plain bash scripts with `set -euo pipefail` (no bats/pytest/shellcheck in repo; glob-verified) |
| Config file | none |
| Quick run command | `bash -n tools/d330-microsd-setup.sh && bash scripts/test_storage_cellular.sh --probe` |
| Full suite command | `for f in scripts/test_*.sh; do bash -n "$f" \|\| exit 1; done` + new guard-mode run (see below) |
| Per-commit repo rule | `bash -n` on touched scripts (CHANGES_AUDIT.md:482 auditor checklist + global AGENTS.md verification rule: paste raw output) |

### Phase Requirements → Test Map
(Success criteria from ROADMAP Phase 32; no REQUIREMENTS.md / REQ IDs exist in this project.)

| ID | Behavior | Test Type | Automated Command | File exists? |
|----|----------|-----------|-------------------|--------------|
| SC1 | `--format` aborts before any write when target has a mounted partition | unit (PATH shims) + optional loop integration | `PATH="$SHIM:$PATH" bash tools/d330-microsd-setup.sh --format --device /dev/mmcblk1` → rc≠0, parted-canary absent | ❌ Wave 0 (extend `scripts/test_storage_cellular.sh` or add `scripts/test_microsd_guards.sh` — Risks #2) |
| SC2 | fstab line parses under `systemd-analyze verify` | integration | `findmnt --verify --tab-file tmp.fstab` + `systemd-analyze verify ./data.mount --recursive-errors=yes` (fallback: output pattern) | ❌ Wave 0 |
| SC3 | `--dry-run` prints guard outcomes | unit | `bash tools/d330-microsd-setup.sh --format --dry-run --device /dev/mmcblk1` → grep PASS/FAIL ×3 | ❌ Wave 0 |
| +locks | missing `--device` → exit 1 + usage; `--mount-home` → exit ≠ 0 "not implemented"; `--probe` unchanged | unit/smoke | direct invocations, assert rc + message | ❌ Wave 0 (probe part exists at test_storage_cellular.sh:63) |

### Sampling Rate
- **Per task commit:** `bash -n tools/d330-microsd-setup.sh` (raw output pasted) + new guard test invocation.
- **Per wave merge:** `bash scripts/test_storage_cellular.sh --probe` must stay green (existing smoke), plus all new assertions.
- **Phase gate:** all SC1–SC3 assertions green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] Guard-assertion test mode — either new `--test-guards` mode in `scripts/test_storage_cellular.sh` or new `scripts/test_microsd_guards.sh` (scope question, Risks #2)
- [ ] PATH-shim fixture directory (fake `lsblk`/`findmnt`/`parted`/`mkfs.ext4`/`blkid`/`mount`) — first of its kind in this repo
- [ ] `.mount`-unit generator snippet (fstab line → `data.mount` file) for SC2
- [ ] Optional: loop-device fixture (root/WSL only, manual tier)
- [ ] Framework install: none (bash-only)
- [ ] CI wiring: **none exists and none is added this phase** — workflows run only on tag/dispatch and execute no tests (verified); test execution is local/target-hardware

## Runtime State Inventory

Not a rename/migration phase — file edits only. Explicit per-category answers anyway:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Possible **legacy `/etc/fstab` lines** on already-deployed devices written by the old code (`UUID=... /data ext4 noatime,lazytime,commit=60 0 2`, no `nofail`) — only on machines where a user already ran `--mount-data` | None automatic this phase (CONTEXT locks "refuse re-append, verify the existing line's options" → detect + report at next run; auto-upgrade = open question #3) |
| Live service config | None (tool deploys no services) | none |
| OS-registered state | None (`/usr/local/bin/d330-microsd-setup` is a plain file, reinstalled by `install_dkms.sh`) | none |
| Secrets/env vars | None | none |
| Build artifacts | None for this script (packages copy it verbatim at build time) | none — next `.deb`/`.rpm`/`PKGBUILD` build picks it up |

**Nothing else found in category** — verified by repo-wide grep of `d330-microsd-setup|microsd|--mount-data|--mount-home|mmcblk1` (this session): only callers/docs listed in Invocation Surface.

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: "high"` (config read this session).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no network/auth surface in a local root CLI |
| V3 Session Management | no | — |
| V4 Access Control | no (partial: root gate `:81-84` retained) | existing `EUID` check + `sudo` requirement |
| V5 Input Validation | **yes** | `--device` must be validated: require absolute `/dev/...` path **and** `[ -b "$TARGET_DEV" ]`; reject `..`/relative/`UUID=`/`LABEL=` forms for destructive actions (locked: explicit `--device /dev/...`); guard messages via `log_err` + `exit 1` |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Formatting a mounted/root disk (audit C1) | Tampering / DoS | three ordered guards before first write (`parted`), `-F` removed, typed `yes` |
| Boot hang via fstab entry when card absent (audit C2) | DoS | `nofail,x-systemd.device-timeout=10s` (locked string); rollback trap on failed mount |
| TOCTOU: device state changes between guard and `parted` | Tampering | guards immediately before write; `udevadm settle` after `parted`; residual risk noted (single-user local tool, LOW) |
| Confirmation bypass when stdin is not a TTY / piped | Elevation of risk | guard (c) `read` under `set -e`: EOF → non-zero → abort (verify in test); dry-run never writes |
| Prompt/automation injection: `--dry-run` piped into shells | Tampering | dry-run output is informational only; never `eval`'d by tool |

**Note:** success criterion wording ("aborts before any write") is the security control this phase exists to prove; SC1's parted-canary assertion is the machine check for it.

## Risks & Open Questions

1. **Prefix-direction contradiction between ROADMAP wording and physical reality.** ROADMAP:90/CONTEXT line 20 describe one direction ("SOURCE prefix of TARGET"); the whole-disk-`/dev/mmcblk0` case requires the other. *Recommendation:* plan implements bidirectional check and states why in the plan; no user confirmation needed (it is the only reading consistent with the stated goal "Refuse when the target backs `/`"), but discuss-phase may want to confirm.
2. **Scope contradiction: "no changes to other scripts" (CONTEXT domain line) vs "`scripts/test_storage_cellular.sh` — must keep passing, extended for the new guards" (CONTEXT integration line).** *Recommendation:* production behavior changes confined to `tools/d330-microsd-setup.sh`; test-harness extension permitted for SC1–SC3 coverage only; no drive-by fixes of the Phase 41 items in that file (fake `fcc-unlock` OK, `--test-microsd` alias). Planner should surface this interpretation explicitly.
3. **Legacy fstab lines on deployed devices** (written by the old code without `nofail`): locked decision says verify existing line's options — but does the tool *migrate* an old line (rewrite options in place) or only refuse/report? Migration = file edit outside the current line-append code path; report-only = safer. *Recommendation:* refuse + instruct (log exact `sed` command for the human), migration out of scope.
4. **`parted`/`partprobe` not declared in any packaging recipe** (control/PKGBUILD/spec read this session). Adding deps = changes to `packaging/*`, outside CONTEXT's one-file scope. *Recommendation:* in-script `command -v` preflight with distro-agnostic message this phase; packaging dep declaration → Phase 42 (N9 packaging audit) unless user says otherwise.
5. **Exact `findmnt -n -o SOURCE /` string on target hardware unknown** (`/dev/mmcblk0p3` vs `/dev/mapper/...` vs `/dev/root`). *Recommendation:* first task in execution runs the command on hardware (or WSL) and captures output; keep `PKNAME`-based fallback in the plan as contingency [ASSUMED].
6. **`systemd-analyze verify` noise/exit-code variance across systemd versions** (v249 < v250 no `--recursive-errors`; device-unit dependency warnings possible). *Recommendation:* test asserts output patterns + `findmnt --verify` dual proof; calibrate once on target and record actual output in the plan's execution notes.
7. **`findmnt --verify` exit semantics on failure not fully documented** in the fetched man ("exit 0 if there is something to display, 1 on any error"). *Recommendation:* assert on stderr/stdout text in addition to rc; confirm on target during Wave 0.
8. **Guard (c) + `--dry-run` interplay:** locked "dry-run executes every read-only guard" — guard (c) is not read-only; how is it reported (PASS with "would prompt"? SKIP?). Discretionary wording, but the *behavior* (dry-run must not hang on a prompt) needs an explicit plan statement.
9. **`--mount-home` + `--device`:** locked decision requires `--device` for `--mount-home` even though it now always exits non-zero. Order of checks (missing-device error vs not-implemented error) unspecified. *Recommendation:* not-implemented wins (cheap, deterministic) — confirm in plan.
10. **Swap-backed target not covered by locked guards** (Linux/Distro Notes §7) — optional guard (a2) against `/proc/swaps`; needs user OK to add a fourth guard, or document as accepted risk.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `udevadm` is provided by the `systemd` package on Debian/Fedora/Arch | Linux/Distro Notes §3 | preflight check message names wrong package; low impact |
| A2 | `parted` package provides `partprobe` on Fedora/RHEL and Arch (Debian verified) | Linux/Distro Notes §3 | wrong install hint in `log_err`; low |
| A3 | Root SOURCE on target is `/dev/mmcblk0p?` (eMMC partition) | Linux/Distro Notes §2 | guard (b) string logic needs `PKNAME`/maj:min fallback; medium — mitigated by Wave 0 capture |
| A4 | `lsblk -no PKNAME` available (util-linux ≥ 2.27) on all targets | Linux/Distro Notes §2 | fallback unavailable; low |
| A5 | `mke2fs` prompt/abort behaviour without `-F` on signed/non-tty devices (man page silent) | Linux/Distro Notes §4 | dry-run/integration expectations off; low (guards run first) |
| A6 | PATH-shim and loop-device testing techniques (no repo precedent for either) | Test Strategy | test design rework; medium — first-of-kind in repo |
| A7 | `findmnt --verify --tab-file` accepts a candidate line without touching `/etc/fstab` (flag documented; exact CLI surface best confirmed on target) | Test Strategy / SC2 | SC2 test needs `LIBMOUNT_FSTAB` env fallback; low |
| A8 | `losetup` recipe works in WSL/CI without extra setup (no CI wiring this phase anyway) | Test Strategy | optional integration tier dropped; low |
| A9 | No other repo caller invokes the tool with flags beyond `--probe` (grep-verified absence, but absence claims are inherently bounded) | Invocation Surface | missed caller breaks on parser conversion; low |

**If this table were empty:** not the case — A1–A9 all need target-side or user confirmation before becoming locked facts.

## Sources

### Primary (HIGH-intent — fetched and quoted this session; provider tier `classify-confidence --provider webfetch` = LOW, see Metadata)
- [CITED: https://man7.org/linux/man-pages/man8/lsblk.8.html] — raw/noheadings semantics, MOUNTPOINT vs MOUNTPOINTS, hex-escape, exit codes 32/64, udevadm-settle recommendation (util-linux 2.43.devel, fetched 2026-08-04 revision)
- [CITED: https://man7.org/linux/man-pages/man8/findmnt.8.html] — `-n/-o SOURCE`, `--verify` + `--tab-file`, `LIBMOUNT_FSTAB`, exit-status text
- [CITED: https://manpages.debian.org/stable/systemd/systemd.mount.5.en.html] — `nofail` verbatim semantics, `x-systemd.device-timeout=` fstab-only rule, mount-unit naming, implicit device deps (systemd 257.13)
- [CITED: https://manpages.debian.org/stable/systemd/systemd-analyze.1.en.html] — `verify` verb, detected-error list, filename-must-be-unit-name example, `--recursive-errors` (v250) exit-code rule
- [CITED: https://manpages.debian.org/stable/e2fsprogs/mke2fs.8.en.html] — `-F`/`-FF` verbatim rule, `-n` dry-run (e2fsprogs 1.47.2)
- [CITED: https://manpages.debian.org/stable/parted/partprobe.8.en.html] — partprobe purpose/options, Debian package provenance (parted 3.6-5)
- [CITED: https://manpages.debian.org/stable/systemd/systemd-fstab-generator.8.en.html] — fstab→unit conversion at boot (context for SC2)

### Secondary (MEDIUM confidence)
- Repo files read this session: `tools/d330-microsd-setup.sh`, `scripts/install_dkms.sh`, `scripts/test_storage_cellular.sh`, `scripts/test_ci_workflows.sh`, `scripts/test_distro_packaging.sh`, `tools/d330-fastboot-tune.sh`, `tools/lenovo-d330-power-tune.sh`, `packaging/{debian/control,arch/PKGBUILD,rpm/lenovo-d330-fix.spec}`, `.github/workflows/{build-packages,build-iso}.yml`, `docs/DISTRO_INSTALL_GUIDE.md`, `docs/research/MICROSD_CELLULAR_LTE.md`, `CHANGES_AUDIT.md`, `.planning/{config.json,STATE.md,PROJECT.md,ROADMAP.md}`, `32-CONTEXT.md` — all in-repo line claims in this document carry `VERIFIED: path:lines` tags from these reads.
- WebSearch/webfetch fallback providers: context7, ref, jina, exa, tavily MCP tools **not available in this session** (verified via `list_mcp_resources`/`list_mcp_resource_templates` → empty); seam-directed queries were fulfilled by direct official-man-page fetches instead.

### Tertiary (LOW confidence — marked for validation)
- Fedora/Arch package mappings for `partprobe`/`udevadm` (A1/A2)
- Target-hardware `findmnt -n -o SOURCE /` output (A3)
- Prompt behaviour of `mkfs.ext4` without `-F`, `findmnt --verify` failure exit semantics (A5/A7)

## Metadata

**Confidence breakdown:**
- Standard stack: **MEDIUM** — every tool's semantics quoted from official man pages this session; no registry/version-install risk (zero new packages); distro package mapping unverified (A1/A2)
- Architecture/patterns: **HIGH for in-repo facts** (all line claims read+quoted this session), **MEDIUM for design synthesis** (prefix-direction finding is analysis over quoted facts; flagged for planner)
- Pitfalls: **MEDIUM-HIGH** — each pitfall grounded in either a quoted man-page rule or a quoted repo line; Pitfall 1 and 5 are the highest-value findings
- **Seam discrepancy disclosure:** `gsd_run query classify-confidence --provider webfetch` returns **LOW** (both with and without `--verified`); all six research digests were cached at LOW per protocol. The RESEARCH.md tags above use `[CITED: url]` for claims read verbatim from official distribution man pages, matching the provenance contract's "official documentation → CITED/MEDIUM" rule. The discrepancy is recorded here rather than hidden; planner may apply a tier-floor if it treats provider tier as authoritative.

**Research date:** 2026-10-07
**Valid until:** 30 days (target stack stable: util-linux/systemd/e2fsprogs man semantics move slowly; re-check only if the phase slips past a systemd major on the target distro)
**No REQUIREMENTS.md / phase requirement IDs** in this project — success-criteria mapping substitutes (see Validation Architecture).
**No `AGENTS.md`, project skills, or `rules/` in the repo** (glob-verified) — only the global `~/.config/opencode/AGENTS.md` applied (style + verification-paste rules).