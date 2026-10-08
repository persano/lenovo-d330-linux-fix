# Phase 33: Low-Battery Hibernate Feasibility - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning (all gray areas auto-accepted per operator standing instruction: autonomous full-milestone run, accept recommended options, no questions)

<domain>
## Phase Boundary

Make the 5% emergency hibernate path actually able to complete (audit C3, M2 partial): give the machine a real disk-backed resume device, make the daemon refuse-and-degrade honestly when hibernate cannot work, and make the service actually enabled at install. Scope: `tools/d330-auto-hibernate.py`, `patches/power_hibernate/**`, the enable lines in `scripts/install_dkms.sh` and packaging postinst scripts, plus one new oneshot swapfile unit asset. No changes to suspend/RTC/resume hooks, no zram removal, no threshold policy change.

</domain>

<decisions>
## Implementation Decisions

### Resume Swap Strategy (audit C3 core)
- **Ship a disk-backed resume swap**, do NOT declare hibernate unsupported: create a swapfile on the root eMMC at install time (root eMMC, never the MicroSD — the card can be absent when the battery dies), managed by a new oneshot systemd unit under `patches/power_hibernate/`
- Evidence-gated fallback: if research proves swapfile-based resume is impossible on the target kernel range (5.15–6.x, ext4 root), downgrade to the documented "hibernate unsupported" behavior (daemon must then degrade safely and say so loudly) — that decision is recorded in 33-RESEARCH with the blocking evidence, not taken silently
- Swap size = physical RAM read at install time (`/proc/meminfo` MemTotal), clamped to a sane floor (4 GB) and ceiling (8 GB); creation guarded by a free-space check (skip with a loud `[WARN]` if root lacks headroom), `chmod 600`, `mkswap` at install
- Never ship a pre-built swapfile in the repo; the unit creates it only when absent (idempotent)

### Resume Activation
- Prefer kernel cmdline activation: `resume=UUID=<root-uuid>` plus `resume_offset=<swapfile offset>` (offset computed at install with `filefrag -v` / `swapon --show=OFFSET`), delivered through a `/etc/default/grub.d/`-style snippet + `grub-mkconfig` when GRUB is detected
- If no GRUB is present, print the exact required cmdline as a manual step and exit non-zero from the installer step (honest, actionable) — never silently install an inactive hibernate path
- Research (33-RESEARCH) must confirm: swapfile resume support on kernel ≥5.15, ext4 contiguity requirements (`fallocate` vs `dd`), and the correct offset tooling on Debian/Fedora/Arch

### Daemon Honest Degradation
- Add `has_non_zram_swap()` reading `/proc/swaps`; when only zram swap exists: **refuse** `systemctl hibernate`, fall back to `sync` + `systemctl suspend`, log `[ERROR]` explaining why hibernate was skipped (roadmap-locked)
- `--dry-run` reports the full swap situation: each swap area, type (partition/file/zram), size, whether a valid resume device exists, and what the daemon would do — this is success criterion 2
- Threshold policy stays 5% discharging; no behavior change outside the hibernate decision

### Service & Enablement
- Keep `Type=oneshot` (the checker exits promptly) — confirm in research; switch to `Type=simple` only if research shows the oneshot + udev `SYSTEMD_WANTS` trigger pattern cannot re-fire per udev event
- **Fix the ExecStart path mismatch**: service says `/usr/local/bin/d330-auto-hibernate.py` but `scripts/install_dkms.sh:243-245` installs `/usr/local/bin/d330-auto-hibernate` (no `.py`) — align them (install path is the contract; the service file changes)
- Add `systemctl enable d330-auto-hibernate.service` next to the existing enable block (`scripts/install_dkms.sh:283-289`) and in `packaging/debian/postinst` + `packaging/rpm/lenovo-d330-fix.spec` %post (success criterion 3)
- Add a comment on the udev rule line `ATTR{capacity}=="[0-5]"` stating it is a udev glob (single char 0–5) and must not be "fixed" into a regex

### the agent's Discretion
- Exact log wording beyond the required `[ERROR]` / `[DRY-RUN]` markers
- Unit file ordering (`After=`) refinements and README prose
- Whether the swapfile unit is named `d330-swapfile.service` or `d330-resume-swap.service`

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tools/d330-auto-hibernate.py` — 57 lines, flat script: `find_battery()`, `get_battery_info()`, `check_and_hibernate(dry_run)`, `subprocess.run(["systemctl","hibernate"])` at `:48` (the line that silently fails today, no swap gate)
- `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` — `Type=oneshot`, `ExecStart=/usr/local/bin/d330-auto-hibernate.py` (MISMATCH vs installed name), `WantedBy=multi-user.target`
- `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` — `ATTR{status}=="Discharging"`, `ATTR{capacity}=="[0-5]"` (glob, correct), `ENV{SYSTEMD_WANTS}="d330-auto-hibernate.service"`
- `patches/power_hibernate/README.md` — current install docs for this subsystem

### Established Patterns
- Install script pattern: guard with `[ -f ... ] && cp ...`, then `systemctl daemon-reload`, then `systemctl enable ... || true` (`scripts/install_dkms.sh:281-289` copies the service but never enables it; the enable list ends at `d330-sensor-filter.service`)
- Phase 32 established: guards fail closed with their own message, `[DRY-RUN]` lines instead of execution, honest success messages only on genuine completion — reuse that posture in the daemon
- Test convention: `scripts/test_storage_cellular.sh --dry-run` performs real `bash -n` gates + delegates suites; python tooling has no suite today

### Integration Points
- `scripts/install_dkms.sh:243-245` installs the daemon as `/usr/local/bin/d330-auto-hibernate`; `:409` and `:428/:437` remove/disable it — keep uninstall symmetric with whatever this phase adds
- `packaging/debian/postinst`, `packaging/rpm/lenovo-d330-fix.spec` %post — service enablement lands here too (roadmap component list)
- ROADMAP Phase 33 component list is the work contract (Audit Ref: C3, M2 partial)

</code_context>

<specifics>
## Specific Ideas

No operator-specific extras beyond the ROADMAP component list — standard approaches preferred.

</specifics>

<canonical_refs>
## Canonical Refs

- `.planning/ROADMAP.md` — `### Phase 33:` component list (goal, success criteria, audit ref C3/M2)
- `tools/d330-auto-hibernate.py`
- `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service`
- `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules`
- `patches/power_hibernate/README.md`
- `scripts/install_dkms.sh`
- `packaging/debian/postinst`
- `packaging/rpm/lenovo-d330-fix.spec`
- `.planning/phases/32-data-loss-boot-safety-guards/32-CONTEXT.md` — guard/honesty posture carried forward (fail closed, `[DRY-RUN]` reporting, success only on genuine completion)

</canonical_refs>

<deferred>
## Deferred Ideas

- Swap on the MicroSD card (defeats the point: card may be absent at 5% battery)
- Removing or resizing the 3 GB zram swap (would fix "only zram exists" at the source — too risky for this phase, zram is load-bearing for daily perf)
- btrfs/xfs swapfile support (root is ext4 on this device)
- Changing the 5% threshold or adding AC/unplug heuristics
- Grub-burg / systemd-boot automation beyond the documented GRUB path

</deferred>
