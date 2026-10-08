# Phase 33: Low-Battery Hibernate Feasibility — Discussion Log

**Mode:** auto-accepted (operator standing instruction for the autonomous full-milestone run: no questions, recommended option taken for every gray area)

## Gray Areas and Resolutions

| # | Area | Options presented | Selection | Rationale |
|---|------|-------------------|-----------|-----------|
| 1 | Resume swap strategy | (a) disk-backed swapfile unit shipped under `patches/power_hibernate/`, (b) declare hibernate unsupported and remove the daemon | **(a)** with evidence-gated fallback to (b) | Goal is "make hibernate actually able to complete"; (b) only if 33-RESEARCH proves swapfile resume impossible on 5.15–6.x |
| 2 | Swap size / placement | (a) RAM-sized file on root eMMC, clamped 4–8 GB with free-space guard, (b) fixed 4 GB, (c) swap on MicroSD | **(a)** | Device ships in 4 GB and 8 GB RAM variants — 4 GB file cannot hold an 8 GB resume image; MicroSD can be absent |
| 3 | Resume activation | (a) GRUB cmdline snippet (`resume=` + `resume_offset=`) with manual-step fallback, (b) systemd resume tooling, (c) leave manual | **(a)** | Automated where GRUB exists; honest manual instruction otherwise — never install a silently-inactive path |
| 4 | Daemon degradation | roadmap-locked: refuse hibernate when only zram, `sync` + suspend, `[ERROR]` log | **accepted as locked** | Prior decision from ROADMAP component list |
| 5 | Service semantics | `Type=oneshot` vs `simple`; ExecStart path mismatch | **oneshot kept, ExecStart aligned to installed name** | Checker exits promptly; mismatch is a latent install bug (`d330-auto-hibernate.py` vs `d330-auto-hibernate`) |
| 6 | Enablement | enable in `install_dkms.sh` + deb postinst + rpm %post; udev glob comment | **accepted as locked** | Success criterion 3; comment prevents a future "fix" of a correct glob |

## Noted for Later

- Swap on MicroSD, zram removal, btrfs/xfs swapfile, threshold policy changes → `<deferred>` in 33-CONTEXT.md
