# Phase 32: Data-Loss & Boot Safety Guards - Context

**Gathered:** 2026-10-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate the two paths that can destroy the eMMC root filesystem or hang systemd at boot (audit C1, C2). Scope is `tools/d330-microsd-setup.sh` only: explicit device selection, pre-write guards, `mkfs`/`parted` safety, `sleep`→`partprobe` sequencing, `nofail` fstab entry with rollback, and an honest `--mount-home` stub. No new tools, no changes to other scripts.

</domain>

<decisions>
## Implementation Decisions

### Device Selection (audit C1)
- `--format` / `--mount-data` / `--mount-home` require an explicit `--device /dev/...`; the `/dev/mmcblk1` default applies only to `--probe`
- Missing `--device` on a destructive action: hard error with usage text, exit 1
- The "any non-`mmcblk0`" sysfs auto-substitution is removed entirely; sysfs scan output is informational only
- Refuse when the target backs `/` (`findmnt -n -o SOURCE /` prefix match) **or** when any partition of the target is mounted

### Pre-Write Guards (audit C1)
- Guard order before `parted`/`mkfs`: (a) `lsblk -nr -o MOUNTPOINT` empty, (b) root-device prefix check, (c) typed `yes` confirmation — each fails fast with its own message
- `-F` removed from `mkfs.ext4`; guards now guarantee a blank, unmounted target
- `sleep 1` replaced by `partprobe "$TARGET_DEV"; udevadm settle`
- `--dry-run` executes every read-only guard, prints PASS/FAIL per guard, then the planned commands

### fstab & Boot Safety (audit C2)
- fstab entry options: `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s`
- Parse proof: `findmnt --verify` on the written entry at install time; the test asserts `systemd-analyze verify` on a generated `.mount` unit when systemd is present
- Failed mount after append: trap rolls the fstab line back and exits non-zero
- Duplicate UUID: re-detect, refuse re-append, verify the existing line's options

### `--mount-home` Stub
- Exits non-zero with a clear "not implemented" message; flag stays in `--help` marked unsupported
- "Storage expansion task complete." prints only when an action genuinely completed

### the agent's Discretion
- Exact log message wording, colour codes, and helper-function naming
- Ordering of informational output and help-text layout

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tools/d330-microsd-setup.sh` — 129 lines, `set -euo pipefail`, colour-coded `log_info/log_ok/log_warn/log_err` helpers (keep)
- Existing option parser loop at `:41-51` — add `--device` here

### Established Patterns
- Bash guards fail fast with `log_err` + `exit 1` (see root check at `:81-84`)
- Dry-run path prints `[DRY-RUN] <cmd>` instead of executing (`:90-93`, `:103-107`)
- Test harness convention: `scripts/test_storage_cellular.sh` covers this tool today

### Integration Points
- `scripts/install_dkms.sh` installs `tools/` scripts to `/usr/local/bin`
- `scripts/test_storage_cellular.sh` — must keep passing, extended for the new guards
- `CHANGES_AUDIT.md` §on MicroSD — claims updated in Phase 42

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the ROADMAP component list — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

- Full `/home` migration implementation (would need its own phase: rsync, user homedir moves, rollback)

</deferred>