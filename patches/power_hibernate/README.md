# Low-Battery Auto-Hibernate for the Lenovo IdeaPad D330-10IGL

Emergency safety net for audit C3: at 5% battery while discharging the system must be
able to suspend to disk (hibernate) instead of dying with unsaved work. This README is
the subsystem's single source of truth — what ships, how the resume swap is created and
activated, what the daemon refuses to do, known limits, enablement, uninstall, and how
to verify everything locally and on the device.

## Components

- `etc/systemd/system/d330-auto-hibernate.service` — trigger unit (`Type=oneshot`).
  Its `ExecStart=/usr/local/bin/d330-auto-hibernate`, i.e. the **installed daemon name**:
  the installer copies `tools/d330-auto-hibernate.py` to `/usr/local/bin/d330-auto-hibernate`
  (no `.py` suffix), and the unit targets that path. The unit re-fires on every udev
  event because a finished `oneshot` is dead, not active (see the comment in the unit).
- `etc/systemd/system/d330-swapfile.service` — oneshot unit that creates the
  disk-backed resume swap on the root eMMC and keeps it active.
- `etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` — udev trigger: battery
  `Discharging` with capacity glob `[0-5]` (a udev **glob**, single character 0–5, not a
  regex — do not "fix" it into a range expression) → `SYSTEMD_WANTS` of
  `d330-auto-hibernate.service`.
- `etc/default/grub.d/53-lenovo-d330-resume.cfg` — template for the kernel resume
  parameters, rendered with real machine values at install time.
- `tools/d330-auto-hibernate.py` — the Python daemon (monitor, report, decision).

## The 5% emergency path (threshold policy unchanged)

The threshold policy is unchanged: **5% and discharging** triggers the emergency path;
anything else prints `[OK] Battery level safe.` The daemon first prints its swap report
(one `[SWAP] path=… type=… size=… used=… priority=…` row per active swap area, followed
by exactly one `hibernate readiness: READY` or `hibernate readiness: NOT-READY (<reason>)`
verdict — this is success criterion 2) and then decides:

- **Ready** (hibernation offered by the kernel, resume configured, and a non-zram swap
  active): `sync` + `systemctl hibernate`, with the return code captured and reported
  (`[ERROR] systemctl hibernate failed (rc=…)` on failure).
- **Not ready**: refuse-and-degrade. The daemon prints
  `[ERROR] hibernate skipped: <reason>` and falls back to `sync` + `systemctl suspend`
  so the machine still gets a chance to suspend gracefully. It never claims hibernate
  succeeded when it did not run.

The four refusal reasons are: `hibernation not offered by kernel` (no `disk` in
`/sys/power/state`), `resume not configured` (no `resume=`/`resume_offset=` active),
`no swap present`, and `only zram swap present` (zram is compressed RAM — after
power-off the image is gone; systemd hard-codes the same exclusion).

`d330-auto-hibernate --dry-run` prints the same swap table and readiness verdict without
invoking any power action, then the `[DRY-RUN]` line for what it *would* do. It is the
on-device honest report used for verification.

## The resume swap (never recreated)

`d330-swapfile.service` creates `/var/swapfile` **on the root eMMC only** (never on the
MicroSD — the card can be absent when the battery dies; MicroSD swap is deferred):

- Size is derived from `MemTotal` in `/proc/meminfo` and clamped to the 4096–8192 MiB
  range (floor 4 GB, ceiling 8 GB).
- Free-space guarded: if `/` lacks headroom for size + margin the unit prints
  `[WARN] … insufficient free space` and skips creation — hibernate stays unavailable,
  root is never shrunk.
- Creation sequence: `dd if=/dev/zero` (a `dd`-created file has no holes; `fallocate`
  files can be rejected by `swapon`), `chmod 600`, `mkswap`, `swapon`.
- Persistence: the fstab entry `/var/swapfile none swap sw 0 0` is appended by the
  installer (verify-before-append, no duplicates), so the swap comes back at every boot.
- **The file must never be deleted or recreated.** The swap header's physical location
  is baked into the boot-time kernel cmdline as `resume_offset=`; deleting and
  recreating the file moves the header, the stored offset goes stale, and resume
  silently fails (research R4). The unit therefore creates it only when absent and only
  ever `swapon`s an existing file — it never rewrites one.

`chmod 600` + root ownership matters: after a hibernate the swapfile holds an
**unencrypted memory image** of the machine's RAM until it is overwritten. That is a
disclosed property of this design, not an accident — anyone with root (or disk access if
the file were world-readable) can read the last session's memory. Full-disk encryption
of the suspend image is out of scope for this phase.

## Resume activation (render → mkconfig → grep-verify → manual step)

Activation is kernel-cmdline based, executed by `scripts/install_dkms.sh` after the
swapfile exists:

1. `filefrag -v /var/swapfile` gives the first extent's physical offset — the swap
   header location; divided by page size (installer asserts filesystem block size ==
   page size via `stat -f -c %S /` vs `getconf PAGESIZE`) it is the `resume_offset`.
   (`swapon --show=OFFSET` does **not** exist; `filefrag -v` is the single source of
   truth.)
2. The result plus the root UUID are rendered into
   `/etc/default/grub.d/53-lenovo-d330-resume.cfg`, producing:
   `GRUB_CMDLINE_LINUX_DEFAULT="… resume=UUID=<root-uuid> resume_offset=<offset>"`.
   The repo ships only placeholders (`__D330_RESUME_UUID__`, `__D330_RESUME_OFFSET__`)
   — no machine-derived value is ever committed.
3. The distro mkconfig runs (`update-grub`, then `grub2-mkconfig`, then
   `grub-mkconfig` — first one found), and the generated config is then
   **grep-verified**: `grep resume_offset= /boot/grub/grub.cfg` must hit.
4. On success `update-initramfs -u` runs so the initramfs resume hooks pick up the new
   parameters (see R1 below).
5. **No GRUB machinery** (no mkconfig tool / no `/etc/default/grub` — systemd-boot,
   rEFInd, Arch-style setups): the installer prints the exact
   `resume=UUID=… resume_offset=…` line to add to the kernel command line and **exits
   non-zero**. You must add it manually and re-run mkconfig yourself. Nothing here
   promises hibernate works while activation was skipped — with no resume parameters
   active the daemon reports `resume not configured` and degrades to suspend.

## Known limits

- **Secure Boot + kernel lockdown** disables hibernation entirely
  (`LOCKDOWN_HIBERNATION`): `disk` disappears from `/sys/power/state` and the daemon
  degrades loudly instead of claiming success. Relaxing lockdown is an owner decision,
  never a fix this project will instruct you to make — treat a locked-down install as
  "hibernate unavailable" and rely on the suspend fallback.
- **Unencrypted suspend image**: see the disclosure in the swap section above.
- **R1 — Debian initramfs-tools swap-file resume is UNVERIFIED on this device.** The
  kernel FAQ says resume from a swap file "cannot be initiated from an initrd or
  initramfs image" (cmdline only), and if the eMMC driver is a module the kernel's late
  resume attempt can run before the device exists. Debian's `hooks/resume` may or may
  not honour `RESUME_OFFSET` for files here. Collect the evidence on the tablet:

  ```sh
  grep mmc /lib/modules/$(uname -r)/modules.builtin
  lsinitramfs /boot/initrd.img-* | grep resume
  grep -r RESUME_OFFSET /usr/share/initramfs-tools /etc/initramfs-tools
  ```

  Run `update-initramfs -u` after activation, and treat a real
  hibernate → power-cycle → resume round trip as the **only** proof that resume works
  (`systemctl hibernate` returning 0 only proves the image was written).

## Enablement (all three installer sites)

Both units are enabled at install:

1. `scripts/install_dkms.sh --install` — in the enable block (`systemctl enable
   d330-auto-hibernate.service` and `systemctl enable d330-swapfile.service`).
2. `packaging/debian/postinst` — after the existing enables, before `update-initramfs`.
3. `packaging/rpm/lenovo-d330-fix.spec` `%post`.

## Uninstall behavior

`scripts/install_dkms.sh --uninstall`:

- daemon: `systemctl disable --now d330-auto-hibernate.service`, unit file removed,
  `/usr/local/bin/d330-auto-hibernate` removed;
- swap: `systemctl disable --now d330-swapfile.service`, unit file removed,
  `swapoff /var/swapfile`, the `/var/swapfile none swap sw 0 0` fstab line removed,
  resume snippet `/etc/default/grub.d/53-lenovo-d330-resume.cfg` removed;
- **the `/var/swapfile` file itself is intentionally left on disk** (deleting a 4–8 GB
  file mid-uninstall buys nothing; recreate-on-demand logic would just restore it).

## Verification

Locally (no root, no hardware — fixture-driven):

```sh
bash scripts/test_hibernate_guards.sh          # hibernate guard suite (daemon + assets + docs anchors)
bash scripts/test_storage_cellular.sh --dry-run  # full harness; delegates both suites
```

On the device, in order:

```sh
d330-auto-hibernate --dry-run                  # swap table + readiness verdict from the real /proc/swaps
systemctl is-enabled d330-auto-hibernate.service   # expect: enabled
systemctl is-enabled d330-swapfile.service         # expect: enabled
grep resume_offset= /boot/grub/grub.cfg        # activation landed
swapon --show                                  # /var/swapfile listed
systemctl hibernate                            # then power-cycle and confirm the session restored
```
