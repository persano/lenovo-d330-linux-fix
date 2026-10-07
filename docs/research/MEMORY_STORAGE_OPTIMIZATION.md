# Research: 4GB RAM & 64GB eMMC Storage Optimization on Lenovo D330-10IGL

## 1. System Constraints
The Lenovo IdeaPad D330-10IGL typically ships with:
- **RAM**: 4GB soldered dual-channel LPDDR4-2400 (or single-channel LPDDR4-2133). No SODIMM upgrade slots.
- **Storage**: 64GB or 128GB soldered eMMC 5.1 flash storage (`/dev/mmcblk0`).

Under standard modern Linux desktop environments (GNOME, KDE Plasma, or Cinnamon with modern web browsers), 4GB of physical RAM is quickly exhausted, leading to heavy paging onto eMMC flash storage. Because eMMC 5.1 has limited random write performance and wears out under aggressive swap cycles, this causes UI stutter, long freezes, and premature flash degradation.

## 2. ZRAM Memory Compression Architecture
Using `systemd-zram-generator` with the `zstd` compression algorithm:
- Creates a virtual block device `/dev/zram0` configured with a 3GB capacity ceiling.
- `zstd` provides a typical compression ratio of 2.8:1 to 3.2:1 with fast decompression times (< 15 microseconds per 4KB page).
- Effectively provides **6GB to 7GB** of usable working memory space entirely within RAM.
- Sets swap priority to `100` so memory is always paged to zram instead of physical disk swap.

## 3. Virtual Memory & Dirty Page Buffer Tuning
Configured in `etc/sysctl.d/99-lenovo-d330-zram.conf`:
- `vm.swappiness = 180`: Forces aggressive eviction of inactive, compressible application anonymous pages into zram, reserving precious physical RAM for file system cache.
- `vm.dirty_bytes = 67108864` (64 MB) & `vm.dirty_background_bytes = 33554432` (32 MB): By default, Linux allows up to 20% of system memory to remain dirty before forcing synchronous writeback. On an eMMC drive, writing 800MB synchronously freezes the desktop for 5-10 seconds. Clamping dirty buffers to 64MB ensures writebacks are smooth, short bursts.
- `vm.vfs_cache_pressure = 50`: Prioritizes directory metadata in RAM to minimize random disk lookups.

## 4. Flash I/O Scheduler (Elevator)
Configured in `etc/udev/rules.d/60-lenovo-d330-emmc.rules`:
- Changes scheduler from `none` / `kyber` to `mq-deadline`, preventing read starvation during heavy background writes.
- Adjusts `read_ahead_kb` to 128 KB for optimal sequential burst reading.
