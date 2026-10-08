# Phase 33: Low-Battery Hibernate Feasibility — Research

**Researched:** 2026-10-08
**Domain:** Linux hibernation/resume (swsusp, swap files, resume_offset), systemd/udev service semantics, GRUB cmdline injection, install/packaging enablement
**Confidence:** HIGH (kernel/systemd sources fetched directly; on-device items flagged UNVERIFIED)

<user_constraints>
## User Constraints (from 33-CONTEXT.md)

### Locked Decisions (verbatim)
- **Resume Swap Strategy (audit C3 core)**: Ship a disk-backed resume swap, do NOT declare hibernate unsupported: create a swapfile on the root eMMC at install time (root eMMC, never the MicroSD — the card can be absent when the battery dies), managed by a new oneshot systemd unit under `patches/power_hibernate/`
- Evidence-gated fallback: if research proves swapfile-based resume is impossible on the target kernel range (5.15–6.x, ext4 root), downgrade to the documented "hibernate unsupported" behavior (daemon must then degrade safely and say so loudly) — that decision is recorded in 33-RESEARCH with the blocking evidence, not taken silently
- Swap size = physical RAM read at install time (`/proc/meminfo` MemTotal), clamped to a sane floor (4 GB) and ceiling (8 GB); creation guarded by a free-space check (skip with a loud `[WARN]` if root lacks headroom), `chmod 600`, `mkswap` at install
- Never ship a pre-built swapfile in the repo; the unit creates it only when absent (idempotent)
- **Resume Activation**: Prefer kernel cmdline activation: `resume=UUID=<root-uuid>` plus `resume_offset=<swapfile offset>` (offset computed at install with `filefrag -v` / `swapon --show=OFFSET`), delivered through a `/etc/default/grub.d/`-style snippet + `grub-mkconfig` when GRUB is detected
- If no GRUB is present, print the exact required cmdline as a manual step and exit non-zero from the installer step (honest, actionable) — never silently install an inactive hibernate path
- Research (33-RESEARCH) must confirm: swapfile resume support on kernel ≥5.15, ext4 contiguity requirements (`fallocate` vs `dd`), and the correct offset tooling on Debian/Fedora/Arch
- **Daemon Honest Degradation**: Add `has_non_zram_swap()` reading `/proc/swaps`; when only zram swap exists: **refuse** `systemctl hibernate`, fall back to `sync` + `systemctl suspend`, log `[ERROR]` explaining why hibernate was skipped (roadmap-locked)
- `--dry-run` reports the full swap situation: each swap area, type (partition/file/zram), size, whether a valid resume device exists, and what the daemon would do — this is success criterion 2
- Threshold policy stays 5% discharging; no behavior change outside the hibernate decision
- **Service & Enablement**: Keep `Type=oneshot` (the checker exits promptly) — confirm in research; switch to `Type=simple` only if research shows the oneshot + udev `SYSTEMD_WANTS` trigger pattern cannot re-fire per udev event
- Fix the ExecStart path mismatch: service says `/usr/local/bin/d330-auto-hibernate.py` but `scripts/install_dkms.sh:243-245` installs `/usr/local/bin/d330-auto-hibernate` (no `.py`) — align them (install path is the contract; the service file changes)
- Add `systemctl enable d330-auto-hibernate.service` next to the existing enable block (`scripts/install_dkms.sh:283-289`) and in `packaging/debian/postinst` + `packaging/rpm/lenovo-d330-fix.spec` %post (success criterion 3)
- Add a comment on the udev rule line `ATTR{capacity}=="[0-5]"` stating it is a udev glob (single char 0–5) and must not be "fixed" into a regex

### the agent's Discretion (verbatim)
- Exact log wording beyond the required `[ERROR]` / `[DRY-RUN]` markers
- Unit file ordering (`After=`) refinements and README prose
- Whether the swapfile unit is named `d330-swapfile.service` or `d330-resume-swap.service`

### Deferred Ideas (OUT OF SCOPE) (verbatim)
- Swap on the MicroSD card (defeats the point: card may be absent at 5% battery)
- Removing or resizing the 3 GB zram swap (would fix "only zram exists" at the source — too risky for this phase, zram is load-bearing for daily perf)
- btrfs/xfs swapfile support (root is ext4 on this device)
- Changing the 5% threshold or adding AC/unplug heuristics
- Grub-burg / systemd-boot automation beyond the documented GRUB path
</user_constraints>

## Summary

**The evidence-gated fallback is NOT triggered: swapfile-based hibernation resume is fully supported on the entire target kernel range (5.15–6.x, ext4).** Kernel documentation for `resume=` + `resume_offset=` exists unchanged from v5.15 to current mainline, and explicitly states that swap files "need not be contiguous". Phase 33 proceeds with the disk-backed swapfile strategy as locked.

The other two locked threads are confirmed by source: systemd **explicitly ignores zram swap for hibernation** (`hibernate-util.c`: `"Swap partition '%s' is a zram device, ignoring."`), so the refuse+degrade gate is not just honest, it matches upstream behavior; and the udev `SYSTEMD_WANTS` + `Type=oneshot` pattern **does re-fire per udev event** (`device.c` re-enqueues `JOB_START` whenever the wanted unit is listed but not active), so `Type=oneshot` stays.

The real risks are in **activation plumbing**, not in feasibility: (a) the repo copies `/etc/default/grub.d/` snippets but **never runs `grub-mkconfig`/`update-grub` anywhere** (zero grep hits), (b) upstream `grub-mkconfig` sources only `/etc/default/grub` — grub.d is a Debian/Ubuntu (and Fedora ≥40) feature, absent on Arch, (c) whether Debian's initramfs-tools resume hook handles swap files on this device is UNVERIFIED and is the top failure mode, and (d) Secure Boot + kernel lockdown removes hibernation entirely (`LOCKDOWN_HIBERNATION`).

**Primary recommendation:** dd-create an fstab-activated `/var/swapfile` (RAM-sized, 4–8 GB clamp, free-space guarded), inject `resume=UUID=… resume_offset=…` via a `grub.d` snippet + distro-appropriate mkconfig **with post-regeneration grep verification** and manual-step non-zero fallback, gate the daemon on a `/proc/swaps`-based readiness report (`[ERROR]` + suspend fallback when not ready), keep `Type=oneshot`, fix `ExecStart`, add the three enable sites, and cover it all with a Phase-32-style env-seam guard suite wired into `scripts/test_storage_cellular.sh --dry-run`.

## Phase Requirements

No requirement IDs were provided by the orchestrator. Roadmap success criteria mapped to research (work contract = `.planning/ROADMAP.md` `### Phase 33:`, Audit Ref C3, M2 partial [VERIFIED: .planning/ROADMAP.md:124-142]):

| Criterion | Research support |
|-----------|------------------|
| 1. `systemctl hibernate` returns 0 with a resume device present | Findings Q1, Q3, Q4: swapfile resume supported (Q1); readiness signals to check (`/sys/power/resume`, `/proc/swaps`, `disk` in `/sys/power/state`) in Q3/Q4; exact upstream refusal strings in Q4 |
| 2. `d330-auto-hibernate --dry-run` reports the swap situation | Q4 gives `/proc/swaps` format + zram detection rule; Q6 gives test-harness design |
| 3. service enabled after `--install` | Repo enable-block facts in Q5/recommended approach; packaging enable sites verified in-repo |

## Standard Stack (what to use)

| Concern | Tool/library | Version/availability | Why standard |
|---------|--------------|----------------------|--------------|
| Swapfile creation | `dd if=/dev/zero bs=1M count=N` + `mkswap` + `swapon` | coreutils/util-linux — always present | man swapon: "The most portable solution to create a swap file is to use dd(1) and /dev/zero" [CITED: man7.org/linux/man-pages/man8/swapon.8.html] |
| Offset computation | `filefrag -v <file>` (first extent `physical`), fallback `FIEMAP` | e2fsprogs — always present on ext4 systems | Same computation systemd uses: `offset_raw = fiemap->fm_extents[0].fe_physical;` → `swap->offset = offset_raw / page_size()` [VERIFIED: github.com/systemd/systemd src/shared/hibernate-util.c:247-250] |
| Cmdline injection | `/etc/default/grub.d/53-lenovo-d330-resume.cfg` + distro mkconfig | repo already ships 50/51/52 snippets | matches existing repo pattern `scripts/install_dkms.sh:186-194` [VERIFIED: scripts/install_dkms.sh:186-194] |
| Swap inspection | parse `/proc/swaps` directly (or `swapon --show`) | kernel/procfs | systemd does exactly this (`fopen("/proc/swaps", "re")` + sscanf) [VERIFIED: github.com/systemd/systemd src/shared/hibernate-util.c:254-313] |
| Tests | bash suite, `passed`/`failed` counters, env/PATH seams | repo convention | Phase 32 `scripts/test_microsd_guards.sh` (26-case PATH-shim suite) |

**⚠️ Correction to a locked detail:** `swapon --show=OFFSET` **does not exist**. util-linux swapon's column enum is exactly `COL_PATH, COL_TYPE, COL_SIZE, COL_USED, COL_PRIO, COL_UUID, COL_LABEL` (headers NAME/TYPE/SIZE/USED/PRIO/UUID/LABEL) — asking for `OFFSET` prints `unknown column: OFFSET` and exits non-zero [VERIFIED: github.com/util-linux/util-linux sys-utils/swapon.c, `static const struct colinfo infos[]` + `column_name_to_id`]. Use `filefrag -v` (or a small FIEMAP ioctl call) as the single source of truth for `resume_offset`. This must be noted in the plan so the installer step does not ship a broken command.

**Installation:** no new packages (see Package Legitimacy Audit). Runtime dependencies: `filefrag` (e2fsprogs), `mkswap`/`swapon` (util-linux), `blkid`/`lsblk`, distro mkconfig binary — all present on any of the target distros.

## Package Legitimacy Audit

No external packages are installed by this phase. Python stdlib only; shell tools are coreutils/util-linux/e2fsprogs (pre-installed on Debian/Fedora/Arch). Nothing to gate.

## Findings

### Q1 — Hibernation resume from a swap FILE on ext4: kernel support, contiguity, mechanics, tooling

**Verdict: SUPPORTED across the whole 5.15–6.x range. The fallback to "hibernate unsupported" is not required.**

1. **Kernel version support.** The kernel documentation page "Using swap files with software suspend (swsusp)" (header: `> 3.  2006 Rafael J. Wysocki`) exists identically in v5.15 and current mainline — fetched both [VERIFIED: www.kernel.org/doc/html/v5.15/power/swsusp-and-swap-files.html; VERIFIED: www.kernel.org/doc/html/latest/power/swsusp-and-swap-files.html]. The feature predates 5.15 by ~13 years, so both Debian bookworm (5.15) and Fedora/Arch 6.x are covered. The `resume_offset=` parameter is listed in the kernel-parameters doc: "Specify the offset from the beginning of the partition given by \"resume=\" at which the swap header is located, in <PAGE_SIZE> units (needed only for swap files)." [VERIFIED: www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html, `resume_offset=` entry].

2. **Contiguity: NOT required for resume; holes ARE rejected by swapon.** Kernel doc, verbatim: "The Linux kernel handles swap files almost in the same way as it handles swap partitions and there are only two differences … (1) swap files need not be contiguous, (2) the header of a swap file is not in the first block of the partition that holds it. From the swsusp's point of view (1) is not a problem, because it is already taken care of by the swap-handling code" [VERIFIED: kernel.org swsusp-and-swap-files, v5.15 + latest]. However, man swapon NOTES, verbatim: "The swap file implementation in the kernel expects to be able to write to the file directly, without the assistance of the filesystem. This is a problem on files with holes … Commands like cp(1) or truncate(1) create files with holes. These files will be rejected by swapon. Preallocated files created by fallocate(1) may be interpreted as files with holes too depending of the filesystem. … The most portable solution to create a swap file is to use dd(1) and /dev/zero." [CITED: man7.org/linux/man-pages/man8/swapon.8.html, "Files with holes"]. util-linux additionally pre-checks in userspace: `if (st.st_blocks * 512L < st.st_size) warnx("%s: skipping - it appears to have holes.")` [VERIFIED: github.com/util-linux/util-linux sys-utils/swapon.c `swapon_checks()`].
   - **→ Use `dd`** (kernel doc's own example: `dd if=/dev/zero of=<swap_file_path> bs=1024 count=…` + `mkswap` + `swapon` [VERIFIED: swsusp-and-swap-files step 1]). `fallocate` is *likely* fine on ext4 (allocated blocks satisfy the hole check) but man swapon explicitly warns it "may be interpreted as files with holes too depending of the filesystem" — for a one-time install on a 4 GB file, `dd` is the safe, documented choice. Contiguity itself is a non-issue for resume.

3. **Mechanics.** Kernel doc verbatim: "In order to use a swap file with swsusp, you need to: … 3. Add the following parameters to the kernel command line: resume=<swap_file_partition> resume_offset=<swap_file_offset>" and "swsusp will use the swap file in the same way in which it would use a swap partition. In particular, the swap file has to be active (ie. be present in /proc/swaps) so that it can be used for suspending." Plus the staleness rule, verbatim: "Note that if the swap file used for suspending is deleted and recreated, the location of its header need not be the same as before. Thus every time this happens the value of the \"resume_offset=\" kernel command line parameter has to be updated." [VERIFIED: kernel.org swsusp-and-swap-files].
   - Known limitation, verbatim: "it requires you to use the \"resume=\" and \"resume_offset=\" kernel command line parameters, so the resume from a swap file cannot be initiated from an initrd or initramfs image." [VERIFIED: www.kernel.org/doc/html/latest/power/swsusp.html, FAQ "Can I suspend to a swap file?"]. See Risks R1 — this is the single biggest unknown for Debian's initramfs-tools.
   - `/sys/power/resume_offset` sysfs knob also exists (alternative to cmdline): "you can also specify a resume offset using resume_offset=<number> on the kernel command line or specify it in /sys/power/resume_offset" [VERIFIED: kernel.org power/swsusp.html (fetched via v6.1 doc search snippet, consistent with latest page)].

4. **Offset tooling across 5.15–6.x.**
   - `filefrag -v` (e2fsprogs, unchanged for years): first extent's `physical:` column = filesystem-block offset of file offset 0 = the swap header location. On ext4 with 4 K filesystem blocks and 4 K pages (standard; UNVERIFIED on device — confirm with `stat -f -c %S /` == `getconf PAGESIZE`), the number is directly the `resume_offset` value. systemd converts exactly this way: `offset_raw = fiemap->fm_extents[0].fe_physical;` … `swap->offset = offset_raw / page_size();` [VERIFIED: github.com/systemd/systemd src/shared/hibernate-util.c:247-250].
   - `swapon --show=OFFSET` is **invalid** (see Standard Stack correction) — the locked CONTEXT mentions it; record the correction here as required by the CONTEXT ("that decision is recorded in 33-RESEARCH with the blocking evidence" applies to the fallback; this is a tooling correction, not a strategy change).
   - `swapon --show` valid columns: `NAME, TYPE, SIZE, USED, PRIO, UUID, LABEL` — usable for the dry-run report, but not for the offset.

5. **Where the image is actually written** (matters for the zram coexistence question): `swsusp_swap_check()` — comment verbatim: "Check if the resume device is a swap device and get its index (if so). This is called before saving the image." Code: `if (swsusp_resume_device) res = find_hibernation_swap_type(swsusp_resume_device, swsusp_resume_block); else res = find_first_swap(&swsusp_resume_device);` [VERIFIED: kernel/power/swap.c:335-349, torvalds master fetched]. So **with `resume=` set, the image goes to the configured swapfile** (zram priority 100 is irrelevant), and **without `resume=` (today's D330), it goes to the first/highest-priority active swap = the 3 GB zram** — which is volatile RAM, destroyed at power-off. That is the precise mechanism of audit C3.

### Q2 — Debian/Fedora/Arch reality: GRUB detection, grub.d snippet, mkconfig, no-GRUB fallback

1. **Upstream GRUB does NOT source `/etc/default/grub.d`.** Upstream `util/grub-mkconfig.in` (savannah git, fetched) contains only: `if test -f ${sysconfdir}/default/grub ; then . ${sysconfdir}/default/grub; fi` [VERIFIED: git.savannah.gnu.org/cgit/grub.git/plain/util/grub-mkconfig.in]. No `grub.d` defaults loop exists in that file.
2. **Debian/Ubuntu: grub.d IS sourced.** Fedora's own change proposal states verbatim: "This is already part of `grub-mkconfig` in Debian and Ubuntu, so it's a low-risk approach" [CITED: fedoraproject.org/wiki/Changes/EtcDefaultGrubD]. Since this project's primary target is Debian-family (repo URL `github.com/lucasgabmoreno/linuxmint_lenovod330` [VERIFIED: packaging/rpm/lenovo-d330-fix.spec:7 `URL:`]), the locked snippet approach works on the primary distro.
3. **Fedora: version-dependent.** The `Changes/EtcDefaultGrubD` proposal targets Fedora Linux 40 (page: "Targeted release: Fedora Linux 40", last updated 2023-12-18) — i.e. Fedora <40 does not source grub.d [CITED: same wiki]. Whether the proposal shipped as written was not confirmed here (MEDIUM confidence) → **detect at runtime, never assume** (see recommendation below).
4. **Arch: grub.d effectively absent.** Arch packages unpatched upstream grub; no evidence Arch sources `/etc/default/grub.d` [ASSUMED — MEDIUM]. On Arch the repo's existing `if [ -d "/etc/default/grub.d" ]` guard (`scripts/install_dkms.sh:187` [VERIFIED]) silently skips the snippet — existing behavior for snippets 50/51/52 too.
5. **Regeneration commands (none currently in the repo!):** grep for `grub-mkconfig|update-grub|grub2-mkconfig` across `scripts/` and root scripts returned **zero hits** — the repo copies grub.d snippets but has never regenerated `grub.cfg`, so existing snippets are dormant until a user regenerates manually. Phase 33 must add regeneration for its snippet to be real:
   - Debian/Ubuntu: `update-grub` (wrapper for `grub-mkconfig -o /boot/grub/grub.cfg`)
   - Fedora: `grub2-mkconfig -o /boot/grub2/grub.cfg` [CITED: docs.fedoraproject.org/en-US/quick-docs/grub2-bootloader/] (Fedora also has `grubby --update-kernel=ALL --args=…` as a distro-native alternative)
   - Arch: `grub-mkconfig -o /boot/grub/grub.cfg`
6. **GRUB-absent detection** (locked fallback): no `update-grub`/`grub-mkconfig`/`grub2-mkconfig` on PATH **and** no `/etc/default/grub` → print exact `resume=UUID=… resume_offset=…` cmdline as manual step, exit non-zero. (systemd-boot/rEFInd automation is deferred by CONTEXT; manual step covers them.)
7. **Bootloader inventory on this device:** D330 ships UEFI; user installs vary (Windows dual-boot → GRUB typically; the repo already targets GRUB via 50/51/52 snippets). Actual bootloader of record: UNVERIFIED (on-device: `bootctl status` / `efibootmgr -v`).

### Q3 — Hibernate prerequisites checklist

| Prerequisite | How to check | Evidence |
|---|---|---|
| `CONFIG_HIBERNATION` | `"disk"` appears in `/sys/power/state` | Kernel only emits it when `hibernation_available()`: `if (hibernation_available()) count += sysfs_emit_at(buf, count, "disk ");` [VERIFIED: kernel/power/main.c:762-763] |
| Firmware/platform mode | `/sys/power/disk` shows modes; systemd defaults `SLEEP_HIBERNATE` to `platform` + `shutdown` | `static const char* const modes…[SLEEP_HIBERNATE] = STRV_MAKE("platform", "shutdown")` [VERIFIED: github.com/systemd/systemd src/shared/sleep-config.c:36] — `shutdown` mode works even without firmware S4 cooperation |
| Swap ≥ image size | swap free ≥ ~Active(anon); kernel needs free space for compressed image | systemd: `#define HIBERNATION_SWAP_THRESHOLD 0.98` and `active <= (size - used) * HIBERNATION_SWAP_THRESHOLD` where `active` is Active(anon) [VERIFIED: src/shared/hibernate-util.c:26,491]; kernel error string `"Not enough free swap\n"` [VERIFIED: kernel/power/swap.c:962]. A 4 GB swapfile vs 4 GB RAM comfortably holds a *compressed* image |
| Image compression | On by default (LZO; LZ4 via `hibernate=nocompress` to disable); compression does NOT affect resume device discovery | `if (nocompress) flags \|= SF_NOCOMPRESS_MODE; else { flags \|= SF_CRC32_MODE; … hib_comp_algo …}` [VERIFIED: kernel/power/hibernate.c:822-838] |
| Secure Boot / lockdown | `cat /sys/kernel/security/lockdown` and presence of `disk` | `lockdown_reasons…[LOCKDOWN_HIBERNATION] = "hibernation"` (integrity group) [VERIFIED: security/security.c:43-65]; `bool hibernation_available(void) { return nohibernate == 0 && !security_locked_down(LOCKDOWN_HIBERNATION) && …}` [VERIFIED: kernel/power/hibernate.c:109-113]; `hibernate()` refuses with debug msg `"Hibernation not available.\n"` returning `-EPERM` [VERIFIED: kernel/power/hibernate.c:768-771]. **Under Secure Boot + lockdown, `disk` disappears from `/sys/power/state` → logind reports hibernate unsupported → hibernate is impossible without disabling Secure Boot/lockdown** |
| `resume=` present at boot | `/proc/cmdline` contains `resume=` and `resume_offset=`; after boot `/sys/power/resume` ≠ `0:0` | `/sys/power/resume` prints `"%d:%d\n"` of `swsusp_resume_device` → `0:0` when unset [VERIFIED: kernel/power/hibernate.c:1258-1259] |
| swapfile active at hibernate time | present in `/proc/swaps` | kernel doc: "the swap file has to be active (ie. be present in /proc/swaps) so that it can be used for suspending" [VERIFIED: swsusp-and-swap-files] |
| systemd-hibernate vs kernel resume | systemd writes `/sys/power/resume`+`resume_offset` right before hibernating if unset (`write_resume_config()`), and refuses when it cannot find a device: `"No valid 'resume=' option found, refusing to hibernate."` / `"Failed to find location to hibernate to: %m"` [VERIFIED: src/sleep/sleep.c:286-298] | resume-at-boot is kernel-side (cmdline) + initrd-dependent (R1) |

**Detection one-liner for the daemon/installer:** `grep -qw disk /sys/power/state` (hibernation offered) + `/sys/power/resume != "0:0"` or `resume=` in `/proc/cmdline` (resume configured) + non-zram swap in `/proc/swaps` (image sink). All read-only, no root needed.

### Q4 — zram-only systems: detection, error text, refuse+degrade logic

1. **`/proc/swaps` format:** header verbatim `Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority` (one line per active swap: path, `partition`|`file`, KiB, KiB, priority) [CITED: man7.org/linux/man-pages/man8/swapon.8.html, `-s/--summary` section "Equivalent to cat /proc/swaps"]. systemd parses it with `"%ms %s %" PRIu64 " %" PRIu64 " %d"`-style sscanf into `SwapEntry{path,type,size,used,priority}` [VERIFIED: src/shared/hibernate-util.c:254-313].
2. **zram detection:** zram shows up as a *partition*-type entry named `/dev/zram0` — distinguish by path, exactly as systemd does: `node = path_startswith(swap.path, "/dev/"); if (node && startswith(node, "zram")) { log_debug("Swap partition '%s' is a zram device, ignoring.", swap.path); … }` [VERIFIED: src/shared/hibernate-util.c:296-299]. (Repo's zram device: `zram-size = min(ram * 0.75, 3072)`, `swap-priority = 100` [VERIFIED: patches/storage_memory/etc/systemd/zram-generator.conf:6-8] — i.e. only zram exists today per audit C3.)
3. **Why zram can never be a resume device:** it is compressed RAM; its contents are gone after power-off, so the image cannot be read back — physical necessity; systemd hard-codes the exclusion (above). With only zram active, `find_suitable_hibernation_device` ends at `"No swap space available for hibernation."` (ENOSPC) [VERIFIED: src/shared/hibernate-util.c:432].
4. **Exact error text if `systemctl hibernate` is invoked without a valid resume path** — `systemctl` tries logind first (`/* First try logind, to allow authentication with polkit */` … `case ACTION_HIBERNATE: … r = logind_reboot(a);` [VERIFIED: src/systemctl/systemctl-start-special.c:195-225]). logind refusal strings (verbatim, `logind-dbus.c`):
   - `"Sleep verb '%s' is not configured or configuration is not supported by kernel"` (:2287) — seen when `disk` is missing from `/sys/power/state` (lockdown/`nohibernate`/no CONFIG_HIBERNATION)
   - `"Not running on EFI and resume= is not set, or noresume is set. No available method to resume from hibernation"` (:2292)
   - `"Specified resume device is missing or is not an active swap device"` (:2296)
   - `"Invalid resume config: resume= is not populated yet resume_offset= is"` (:2300)
   - `"Not enough suitable swap space for hibernation available on compatible block devices and file systems"` (:2304)
   [VERIFIED: github.com/systemd/systemd src/login/logind-dbus.c:2278-2304] — these `SLEEP_RESUME_*` checks were introduced with `hibernation_is_safe` (commit 805deec0, 2023-10-16 → systemd v255+); Debian bookworm ships systemd 252, which predates them [CITED: GitHub commit history for src/shared/hibernate-util.c] → **error strings are version-dependent; tests must assert only daemon-produced markers.**
   - Older path (systemd-hibernate unit): `"Failed to find location to hibernate to: %m"` then `"No valid 'resume=' option found, refusing to hibernate."` [VERIFIED: src/sleep/sleep.c:288,294].
   - Kernel-side (if it ever reaches the kernel): `"Not enough free swap"` [VERIFIED: kernel/power/swap.c:962], `"Cannot find swsusp signature!"` [VERIFIED: kernel/power/swap.c:1645], `"Hibernation not available."` (debug) [VERIFIED: kernel/power/hibernate.c:769].
5. **Recommended refuse+degrade logic (roadmap-locked, shaped by the above):**
   1. Read `/proc/swaps`; classify each row (`/dev/zram*` → zram; path ends `/`-less block → partition; else file).
   2. **Refuse hibernate when no non-zram swap exists** → print `[ERROR] hibernate skipped: only zram swap present (volatile, cannot hold a resume image); falling back to suspend` → `sync` + `systemctl suspend`, propagate suspend's rc.
   3. Additional read-only refusals (cheap, honest, all optional-but-recommended): `disk` not in `/sys/power/state` (lockdown/`nohibernate`); `/sys/power/resume` == `0:0` and no `resume=` in `/proc/cmdline` (resume not configured yet — daemon installed but activation pending).
   4. `--dry-run` prints the full table (path, type, size, used, priority, zram?, resume-device verdict) + `[DRY-RUN]` action line — success criterion 2. In dry-run, *never* refuse silently: print the `[ERROR]` verdict too.

### Q5 — udev + systemd trigger semantics: does SYSTEMD_WANTS re-fire per event for a oneshot?

**Yes — verified in systemd source. `Type=oneshot` is correct and stays.**

1. Mechanism: on every udev event for a tagged device, PID 1 runs `device_add_udev_wants()` (called from `device_setup_unit`, `if (main) (void) device_add_udev_wants(u, dev);`) [VERIFIED: src/core/device.c:687-689]. For each unit named in `SYSTEMD_WANTS`, when the device unit is **already up** (`d->state != DEVICE_DEAD`), the code (verbatim comments preserved):
   ```c
   if (strv_contains(d->wants_property, *i)) {
       Unit *v;
       v = manager_get_unit(u->manager, *i);
       if (v && UNIT_IS_ACTIVE_OR_RELOADING(unit_active_state(v)))
           continue; /* The unit was already listed and is running. */
   }
   r = manager_add_job_by_name(u->manager, JOB_START, *i, JOB_FAIL, NULL, &error, NULL);
   ```
   [VERIFIED: src/core/device.c:573-587, v252]
   → If the wanted oneshot has finished (inactive/dead), the **next udev event enqueues a fresh start job**. Only a *still-running* unit is skipped — which is exactly the pile-up protection you want.
2. Why oneshot exits "dead": systemd.service(5), verbatim: "without RemainAfterExit= the service will never enter \"active\" unit state, but will directly transition from \"activating\" to \"deactivating\" or \"dead\" … after a service of this type ran (and which has RemainAfterExit= not set) it will not show up as started afterwards, but as dead." [CITED: man7.org/linux/man-pages/man5/systemd.device.5.html companion systemd.service.5, `Type=oneshot` description, fetched]. So each capacity change → new run. **`Type=simple` would be wrong**: a long-running process stays ACTIVE → every later event is skipped by the `continue` above → the "re-fire per event" behavior would stop after the first trigger.
3. The man-page caveat, verbatim: "systemd will only act on Wants= dependencies when a device first becomes active. It will not act on them if they are added to devices that are already active." [CITED: man7.org/linux/man-pages/man5/systemd.device.5.html, SYSTEMD_WANTS=] — read together with the code above, this refers to *newly added* wants during reload cycles; the per-event start-if-inactive path (device.c:573-587) is the operative behavior for our repeated same-unit case, and it has been stable since ≤v252. The rule's `TAG+="systemd"` is mandatory (man page: properties are "not taken into account unless the device is tagged with the \"systemd\" tag") — the repo rule already has it [VERIFIED: patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules:4].
4. **udev glob confirmation for the comment task:** udev(7), verbatim: "\"[]\" Matches any single character specified within the brackets. For example, the pattern string \"tty[SR]\" would match either \"ttyS\" or \"ttyR\". The pattern string \"[0-9]\" could be used to match any digit. Ranges are also supported via the \"-\" character." [VERIFIED: man7.org/linux/man-pages/man7/udev.7.html, "Special characters"]. So `ATTR{capacity}=="[0-5]"` matches the single characters `0`–`5` (capacity 0%–5%) and is correct as-is; the comment must warn against rewriting it as `0-5` range semantics of regex or `[0-9]|[0-5]` style "fixes" (note: it deliberately does NOT match `10`, `20`… which is intended for a *critical* threshold).
5. ExecStart mismatch, re-verified: service `ExecStart=/usr/local/bin/d330-auto-hibernate.py` [VERIFIED: patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service:7] vs installer `cp … /usr/local/bin/d330-auto-hibernate && chmod +x /usr/local/bin/d330-auto-hibernate` [VERIFIED: scripts/install_dkms.sh:243-245] — the service as shipped would fail with "No such file or directory". Fix the service file (install path is the contract), per lock.
6. Enablement sites, re-verified: install copies the service but the enable block ends at `d330-thermal.service` (no hibernate enable) [VERIFIED: scripts/install_dkms.sh:281-294]; `postinst` enables 6 units, not hibernate [VERIFIED: packaging/debian/postinst:13-18]; RPM `%post` enables only 3 units [VERIFIED: packaging/rpm/lenovo-d330-fix.spec:38-44]. Uninstall already handles `rm /usr/local/bin/d330-auto-hibernate` [VERIFIED: scripts/install_dkms.sh:409], `systemctl disable --now d330-auto-hibernate.service` [VERIFIED: scripts/install_dkms.sh:428], `rm /etc/systemd/system/d330-auto-hibernate.service` [VERIFIED: scripts/install_dkms.sh:437] — the *new* swapfile unit must be added to the same three uninstall lists for symmetry.

### Q6 — Test harness design (no root/hardware)

1. **Repo conventions to match:**
   - `scripts/test_microsd_guards.sh`: PATH-prefix shims so no real block device is written; `passed=0 failed=0` counters; header block documents case count; exits non-zero on any failure [VERIFIED usage model: scripts/test_storage_cellular.sh:68-70 comment "its non-zero exit propagates under set -e, so any failing case fails this mode; its passed=N failed=M summary flows into this output" + invocation `bash scripts/test_microsd_guards.sh` at :70].
   - `scripts/test_storage_cellular.sh --dry-run`: runs `bash -n` syntax gates then delegates suites [VERIFIED: scripts/test_storage_cellular.sh:51-77]. This is where the new suite plugs in (it is in the Phase 33 component list).
   - `scripts/test_auto_hibernate.sh` already exists with `--probe/--simulate/--dry-run` and calls `python3 tools/d330-auto-hibernate.py --dry-run` [VERIFIED: scripts/test_auto_hibernate.sh:55,72,76] — must keep passing; note its `--dry-run` mode uses the always-green pattern (`python3 … || true` then unconditional success) which the v7 roadmap already flags as a defect pattern [VERIFIED: .planning/ROADMAP.md:311 lists `test_auto_hibernate.sh:55-56`].
   - No pytest/python test infra exists anywhere in the repo (glob for `*test*.py`, `conftest.py`, `pytest.ini`, `pyproject.toml` → none) — do not introduce one for this phase; keep tests in bash + inline python like `test_ci_workflows.sh` does (`python3 - << 'EOF' …` heredoc assertions) [VERIFIED: scripts/test_ci_workflows.sh:46-75].
2. **Unit-testing swap detection without root:** add a hidden env seam in `tools/d330-auto-hibernate.py`:
   ```python
   PROC_SWAPS = os.environ.get("D330_PROC_SWAPS", "/proc/swaps")
   SYS_POWER = os.environ.get("D330_SYS_POWER", "/sys/power")
   ```
   Tests write fixture files (`Filename Type Size Used Priority` tables for: zram-only, disk-partition swap, swapfile+zram, empty) plus fake `resume` (`0:0` vs `253:0`) into a temp dir, run `D330_PROC_SWAPS=… D330_SYS_POWER=… python3 tools/d330-auto-hibernate.py --dry-run`, and assert on daemon-produced markers only (`[DRY-RUN]`, `[ERROR]`, verdict lines, exit codes). **Never assert on systemd/kernel error strings** — Q4 showed they are version-dependent (v252 vs v255+).
3. **Suggested suite:** new `scripts/test_hibernate_guards.sh` with the phase-32 shape (banner, `-h/--help`, `passed`/`failed`, final `passed=N failed=M`, exit 1 on failure), cases: fixtures above + refuse→suspend-fallback command construction (assert via `[DRY-RUN]` line, no real systemctl), ExecStart/install-name consistency check (grep service file vs `install_dkms.sh` — a static regression guard for the mismatch bug), udev glob presence/comment check, enable-site presence checks in the 3 installers, `bash -n` on touched scripts, python syntax gate (`python3 -m py_compile tools/d330-auto-hibernate.py`). Wire into `scripts/test_storage_cellular.sh --dry-run` next to line 70.
4. **Local execution:** this Windows dev box has bash 5.2.21 (Git Bash) with Python 3.12.3 at `/usr/bin/python3`, plus WSL Ubuntu available — bash/python suites are runnable locally; systemd/filefrag/grub commands are target-only (see Environment Availability).

### Q7 — Where hibernate failure is currently silent (exact current failure mode)

1. **The silent line, verbatim:** `subprocess.run(["systemctl", "hibernate"])` with the return value discarded [VERIFIED: tools/d330-auto-hibernate.py:48] and `os.system("sync")` before it [VERIFIED: tools/d330-auto-hibernate.py:47]. No rc check, no journal breadcrumb — audit N5 in the v7 roadmap already records ":48 ignored subprocess.run return" [VERIFIED: .gsd/milestones/v7.0-ROADMAP.md:151].
2. **There is no swap gate at all today:** dry-run prints only battery state plus `"[DRY-RUN] sync && systemctl hibernate (skipped in dry run)"` [VERIFIED: tools/d330-auto-hibernate.py:44-45] — nothing about swap/resume (success criterion 2 is entirely new output).
3. **Failure mode on the device today (both branches documented):**
   - **systemd ≥ 255** (modern Fedora/Arch): logind refuses before any kernel call with the strings in Q4; `systemctl hibernate` returns non-zero; the daemon swallows it → *silent failure*.
   - **systemd ≤ 252 / if it reaches the kernel:** `swsusp_swap_check()` with no `resume=` set does `find_first_swap(&swsusp_resume_device)` [VERIFIED: kernel/power/swap.c:346] → the only active swap is zram (prio 100, 3 GB) → image written to zram → `power_down()` [VERIFIED: kernel/power/hibernate.c:847] → at next power-on there is no resume signature target (`swsusp_resume_device` unset) → **fresh boot, session silently lost, looks like an ordinary shutdown/reboot**. Either way the "safety net" does not work — audit C3 confirmed.
4. **The audit's candidate string "Platform does not support [hibernation]" does not exist.** Searched verbatim across kernel `security/security.c`, `kernel/power/{main,suspend,swap,snapshot,process,user,hibernate}.c` and systemd `logind-dbus.c`/`sleep-config.c`/`sleep.c` — zero hits; DuckDuckGo exact-phrase search also returns nothing. Treat it as a paraphrase. The real observable equivalents are: `disk` absent from `/sys/power/state` (lockdown/`nohibernate`), logind's `"Sleep verb 'hibernate' is not configured or configuration is not supported by kernel"`, systemd-hibernate's `"No valid 'resume=' option found, refusing to hibernate."`, and kernel `"Hibernation not available."` / `"Not enough free swap"`.
5. **Second silent layer:** even `systemctl enable` never happens (Q5.6) — the service may not run at all after `--install` on a fresh system, so success criterion 3 (enabled after `--install`) is currently false on all three install paths.

## Risks / Unknowns

| # | Risk | Severity | Status | Mitigation |
|---|------|----------|--------|------------|
| R1 | **Debian initramfs resume-from-swap-file.** Kernel FAQ: swap-file resume "cannot be initiated from an initrd or initramfs image" (cmdline only); the eMMC controller driver (sdhci-pci/mmc) is likely a *module*, so the kernel's own lateinit resume attempt may run before the device is probed and "the resume process fails and bootup continues" — if Debian's `hooks/resume` doesn't handle `RESUME_OFFSET` for files, hibernate silently degrades to a shutdown (image never restored). Debian bug #945497 ("initramfs-tools: Resume function does not check for swap file") exists; its fix status in bookworm's initramfs-tools 0.142 could not be read (Debian infra blocked by anti-bot challenge). | HIGH | UNVERIFIED | On-device verification task: `grep mmc /lib/modules/$(uname -r)/modules.builtin`, `lsinitramfs /boot/initrd.img-* \| grep resume`, `grep -r RESUME_OFFSET /usr/share/initramfs-tools /etc/initramfs-tools`; run `update-initramfs -u` after activation (postinst already does `update-initramfs -u` [VERIFIED: packaging/debian/postinst:21-23]). **Gate success criterion 1 on a real hibernate → power-cycle → resume test on the tablet, not on `systemctl hibernate` rc alone** (rc only proves the image was written). If the hook lacks offset support: rely on kernel-lateinit (works iff mmc builtin) or document the blocker in the phase's fallback record. |
| R2 | **grub.d snippet never takes effect**: upstream grub-mkconfig doesn't source `/etc/default/grub.d` (Arch, Fedora <40), and the repo has never run *any* mkconfig — an inactive resume path would be installed "successfully". | HIGH | VERIFIED (mechanism) | After copying the snippet, run the detected mkconfig, then **verify**: `grep -q "resume_offset=" /boot/grub/grub.cfg` (or distro path). On failure → print exact cmdline, exit non-zero (locked). Consider also falling back to appending `resume=… resume_offset=…` to `/etc/default/grub:GRUB_CMDLINE_LINUX_DEFAULT` (works on every GRUB) before declaring manual-step. |
| R3 | **Secure Boot + kernel lockdown disables hibernation entirely** (`LOCKDOWN_HIBERNATION`) — swapfile work is then moot on that install. | MED | VERIFIED (kernel) | Detect `disk` absent from `/sys/power/state` / `lockdown` file; daemon degrades loudly (fits the honest-degradation lock); document in README: hibernate requires Secure Boot off or lockdown relaxed. |
| R4 | **Swapfile recreation invalidates `resume_offset`** (kernel doc warning). The idempotent unit must create only-if-absent and must **never** silently recreate (e.g. on size-mismatch); if the file is ever replaced, cmdline must be recomputed + mkconfig rerun. | MED | VERIFIED (kernel doc) | Unit: absent → create+mkswap+swapon; present → verify active (`swapon` if listed in fstab but inactive), never rewrite; add installer-side offset re-check with loud `[WARN]` when file's current offset ≠ cmdline offset. |
| R5 | **Swap must be ACTIVE at hibernate time** (kernel doc: present in `/proc/swaps`); systemd additionally refuses with "Specified resume device is missing or is not an active swap device". A swapfile that exists but isn't swapon'ed breaks criterion 1. | MED | VERIFIED | Persist via fstab swap entry (`/var/swapfile none swap sw 0 0`) appended with the Phase 32 verify-before-append/duplicate-refusal pattern; swapfile unit `Before=`/`Wants` ordering + `swapon -a` idempotency at boot. |
| R6 | **Free space on the 64 GB eMMC** for a 4 GB swapfile (locked free-space guard) — device may be near-full. | MED | — | Locked: `[WARN]` + skip + daemon degrades to suspend-only path (no false hibernate promise). Threshold: require size + margin (suggest ≥ 6 GB free) before dd. |
| R7 | `resume_offset` unit mismatch if fs block ≠ page size (4K/8K mixes). | LOW | UNVERIFIED (device) | Installer asserts `stat -f -c %S /` == `getconf PAGESIZE`; mismatch → manual-step path. |
| R8 | RPM spec has no `%preun` (no uninstall path at all) — symmetric removal for the new unit cannot land there. | LOW | VERIFIED (spec read) | Phase 33 adds `%post` enable only (component list); note the gap for Phase 35 (installer/uninstaller symmetry phase). |
| R9 | logind/systemd error strings differ across versions (v252 vs v255+ `hibernation_is_safe`). | LOW | VERIFIED | Tests assert only daemon markers (Q6.2). |

**Open questions (resolve on-device during execution):** bootloader identity (GRUB vs systemd-boot/rEFInd); systemd version; Secure Boot/lockdown state; initramfs resume hook swap-file support (R1); mmc driver builtin (R1); ext4 block size == page size (R7).

## Recommended Implementation Approach

### 1. Disk-backed resume swap (locked strategy — CONFIRMED FEASIBLE)
- **Creation:** `dd if=/dev/zero of=/var/swapfile bs=1M count=$SIZE conv=fsync` (SIZE = clamp(`MemTotal` from `/proc/meminfo`, 4096, 8192) MiB), `chmod 600`, `mkswap`, then activate.
- **Free-space guard:** `df --output=avail -B1 /` ≥ SIZE + margin else `[WARN] "insufficient free space for /var/swapfile (need N, have M); hibernate stays unavailable"` and exit the step non-zero (honest, phase-32 posture).
- **Activation persistence:** append `/var/swapfile none swap sw 0 0` to `/etc/fstab` using the Phase 32 pattern (verify-before-append, duplicate refusal, `findmnt --verify`-style check). zram keeps priority 100 so runtime swap behavior is unchanged; the swapfile sits idle until hibernation (image targeting is by `resume=`, not priority — Q1.5).
- **New oneshot unit** `patches/power_hibernate/etc/systemd/system/d330-swapfile.service` (name per discretion; recommend `d330-swapfile.service`), `DefaultDependencies=no`-free simple form: `ConditionPathExists=!/var/swapfile` create path; else ensure active. Enabled alongside the others. Never recreate an existing file (R4).

### 2. Resume activation (GRUB cmdline — locked, with verification hardening)
- After the swapfile is active: `OFFSET=$(filefrag -v /var/swapfile | awk '/^ 0:/{print $NF; exit}')` — first extent physical, filesystem blocks; assert block==page (R7).
- `ROOT_UUID=$(blkid -s UUID -o value "$(findmnt -n -o SOURCE /)")`.
- Snippet `patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg`:
  `GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} resume=UUID=<uuid> resume_offset=<offset>"` (generated at install with real values — do not hardcode in the repo asset; ship a template + install-time render, consistent with "never ship machine-specific state").
- **mkconfig + verify:** detect `update-grub` → `grub2-mkconfig` → `grub-mkconfig`; run it; then grep the generated `grub.cfg` for `resume_offset=`; failure → print exact required cmdline, exit non-zero (locked). Also run `update-initramfs -u` (Debian) so hooks pick up `resume=`/`RESUME_OFFSET` (R1).
- No mkconfig binary + no `/etc/default/grub` → same manual-step + non-zero (locked; covers systemd-boot/rEFInd, deferred automation).

### 3. Daemon honest degradation (`tools/d330-auto-hibernate.py`)
- Add `read_proc_swaps()` (env-seamed, Q6.2) + `has_non_zram_swap()`; readiness = non-zram swap AND (`disk` in `/sys/power/state`) AND resume configured (`/sys/power/resume != 0:0` or `resume=` in `/proc/cmdline`).
- Not ready → `[ERROR] <reason>` + `os.system("sync")` + `subprocess.run(["systemctl","suspend"])` **with rc captured**; ready → `subprocess.run(["systemctl","hibernate"])` **with rc checked**, `[ERROR]` on non-zero (fixes audit N5 at :48).
- `--dry-run` → swap table (path/type/size/used/priority/zram flag), resume-device verdict, `[DRY-RUN]` action line (criterion 2).
- Fix the two unclosed `open()` calls at `:30-31` while touching the file (N5, cheap).
- Threshold logic untouched (5% discharging — locked).

### 4. Service & enablement
- `ExecStart=/usr/local/bin/d330-auto-hibernate` (align to install path; service file changes — locked).
- Keep `Type=oneshot` (Q5 evidence), add a comment in the unit citing the re-fire rationale.
- Add `systemctl enable d330-auto-hibernate.service` (and the new swapfile unit) after `scripts/install_dkms.sh:293`, in `packaging/debian/postinst` after :18, and in `packaging/rpm/lenovo-d330-fix.spec` `%post` after :44 (all three verified as currently missing).
- Uninstall symmetry: add the new unit to `install_dkms.sh` disable (:421-429) and rm (:430-438) lists; decide whether `/var/swapfile` is removed on uninstall (recommend: leave the file, `swapoff` + remove fstab line only — deleting a 4 GB file on an eMMC mid-uninstall is unnecessary risk; document either way).
- udev rule: add the glob comment (udev(7) quote, Q5.4) — no functional change.

### 5. Tests (Phase 32 posture)
- New `scripts/test_hibernate_guards.sh` (Q6.3): fixture-driven swap/`resume` cases via env seam, static regression guards (ExecStart ↔ install path, enable sites ×3, udev glob comment), `python3 -m py_compile`, `bash -n`, passed/failed summary, non-zero on failure.
- Wire into `scripts/test_storage_cellular.sh --dry-run` (component list) beside `bash scripts/test_microsd_guards.sh` (line 70 pattern).
- Keep `scripts/test_auto_hibernate.sh` green; optionally replace its always-green `|| true` line 55 with a real assertion (roadmap defect #311 lists it — only if in scope; otherwise note for the audit-remediation owner).
- On-device acceptance: `systemctl is-enabled d330-auto-hibernate.service` → `enabled` (criterion 3); `d330-auto-hibernate --dry-run` shows table (criterion 2); hibernate→power-cycle→resume round trip (criterion 1, R1).

## Validation Architecture

`workflow.nyquist_validation: true` in `.planning/config.json` [VERIFIED: .planning/config.json:9].

| Property | Value |
|----------|-------|
| Framework | bash assertion suites (repo convention; no pytest exists) |
| Quick run | `bash scripts/test_hibernate_guards.sh` (new) |
| Full suite | `bash scripts/test_storage_cellular.sh --dry-run` (delegates + `bash -n` gates) |
| Phase gate | full suite green + on-device criteria 1–3 |

| Req (ROADMAP) | Behavior | Type | Command | File exists? |
|---|---|---|---|---|
| SC3 | service enabled by all 3 installers | static/unit | `bash scripts/test_hibernate_guards.sh` (enable-site cases) | ❌ Wave 0 (new) |
| SC2 | `--dry-run` swap report | unit (env-seam) | same suite, fixture cases | ❌ Wave 0 (new suite + fixtures) |
| SC1 | hibernate with valid resume device | on-device manual | hibernate → power cycle → resume | manual-only (hardware; VERIFICATION override precedent from Phase 32) |

**Wave 0 gaps:** `scripts/test_hibernate_guards.sh` + fixtures; env seam in `tools/d330-auto-hibernate.py`; delegate line in `scripts/test_storage_cellular.sh`.

## Security Domain

`security_enforcement: true` (level 1, block on high) [VERIFIED: .planning/config.json:11-13].

| ASVS Category | Applies | Standard control |
|---|---|---|
| V5 Input Validation | yes | Parse `/proc/swaps` defensively (tolerate malformed/short lines, skip header, never crash the daemon); validate integer offset/size before use |
| V6 Cryptography | no | No crypto in this phase (kernel's suspend-image encryption not in scope) |
| V4 Access Control | incidental | units run as root by design; swapfile `chmod 600` + root ownership (util-linux warns on insecure swapfile perms: `"insecure permissions %04o, 0600 suggested"` [VERIFIED: swapon.c `swapon_checks`]) |
| Secure Boot interplay | yes | Do not instruct disabling lockdown to make hibernate pass; detect and degrade (R3) |

Known threat pattern: writing machine state to unencrypted disk (kernel doc's own "Encrypt suspend image" warning) — out of scope, but README should note the swapfile holds a memory image after hibernate (document, don't silently ship).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| bash | test suites | ✓ (Git Bash) | 5.2.21 | — |
| python3 | daemon + tests | ✓ (`/usr/bin/python3` in bash; `python` 3.13.14 in pwsh) | 3.12.3 | — |
| WSL Ubuntu | running Linux-side checks locally | ✓ | 2 (distro default) | — |
| systemctl / filefrag / grub-mkconfig / udevadm | install + on-device verification | ✗ on this Windows box | — | target-device tasks; mark VERIFICATION-overridable (Phase 32 precedent) |
| Target tablet (D330) | criterion 1 round-trip | ✗ in this environment | — | deferred to `/gsd-verify-work` on hardware |

**Missing with fallback:** all Linux-runtime tools (installer steps must be `--dry-run`-testable locally, executed on device).
**Missing, blocking:** nothing for planning; R1 verification blocks final "criterion 1" sign-off only.

## State of the Art / Notable

- `hibernation_is_safe()` + `SLEEP_RESUME_*` refusal strings: systemd ≥ v255 (commits 805deec0 2023-10-16 … 500ec22d 2023-11-17) — Debian bookworm's v252 predates them [CITED: GitHub commits API for src/shared/hibernate-util.c].
- Fedora `/etc/default/grub.d` support: proposed for F40 (2023-12) — version-dependent, detect at runtime [CITED: fedoraproject.org/wiki/Changes/EtcDefaultGrubD].
- `swapon --show` OFFSET column: never existed (util-linux source) — correct the CONTEXT assumption.

## Sources

### Primary (HIGH confidence)
- kernel.org docs fetched: `admin-guide/kernel-parameters.html` (`resume=`, `resume_offset=`), `power/swsusp.html`, `power/swsusp-and-swap-files.html` (latest + v5.15)
- torvalds/linux source fetched: `kernel/power/{hibernate,swap,main}.c`, `security/security.c`
- systemd/systemd source fetched: `src/login/logind-dbus.c`, `src/shared/{sleep-config,hibernate-util}.c`, `src/sleep/sleep.c`, `src/core/device.c` (v252), `src/systemctl/systemctl-start-special.c`
- util-linux source fetched: `sys-utils/swapon.c`
- man-pages fetched: udev(7), systemd.device(5), systemd.service(5), swapon(8)
- savannah: `util/grub-mkconfig.in`
- In-repo files read this session (all `file:line` citations above)

### Secondary (MEDIUM confidence)
- Fedora wiki `Changes/EtcDefaultGrubD` (F40 target, Debian-parity claim)
- Fedora docs grub2-bootloader quick-doc
- Debian bug #945497 title/excerpt via search index (page itself blocked by anti-bot challenge)
- DDG-indexed community strings (`Failed to hibernate system via logind: Sleep verb "hibernate" not supported` — ubuntuhandbook)

### Tertiary (LOW confidence / marked)
- Arch `/etc/default/grub.d` non-support [ASSUMED]
- Debian initramfs-tools `RESUME_OFFSET` support status [ASSUMED/UNVERIFIED] → R1
- Fedora F40 grub.d change actually shipping as proposed [ASSUMED]

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | ext4 root uses 4 K blocks and 4 K pages (offset unit match) | Q1.4 | wrong `resume_offset` → resume fails; guarded by R7 assert |
| A2 | Arch does not source `/etc/default/grub.d` | Q2.4 | snippet inert on Arch; guarded by R2 post-mkconfig verification |
| A3 | Fedora grub.d change shipped in F40 as proposed | Q2.3 | same guard (R2) |
| A4 | eMMC/mmc driver is modular (not builtin) on Debian target | R1 | lateinit resume fails → R1 verification decides |
| A5 | D330 RAM = 4 GB (zram conf header says so) → 4 GB swapfile ≥ MemTotal | context | clamp floor still ≥ RAM; fine either way |
| A6 | Device primarily boots GRUB (repo already ships grub.d snippets) | Q2 | no-GRUB manual-step fallback (locked) covers it |

## Metadata

**Confidence breakdown:**
- Standard stack / swapfile feasibility: HIGH — kernel docs (v5.15 + latest) and systemd/util-linux source read directly
- Architecture (systemd/udev semantics): HIGH — systemd source, per-event start-job logic read in full
- GRUB activation: MEDIUM — Debian confirmed, Fedora version-dependent, Arch assumed (R2 guard makes plan robust either way)
- Pitfalls (initramfs resume): MEDIUM — mechanism documented from kernel FAQ; device-specific status UNVERIFIED (R1)

**Research date:** 2026-10-08
**Valid until:** 90 days (kernel/systemd facts stable; re-check Fedora grub.d and Debian bug #945497 only if those distros become primary targets)
