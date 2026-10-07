# Memory & Storage Optimization Patches for Lenovo IdeaPad D330-10IGL

Provides system configurations for ZRAM compressed memory swap, sysctl dirty page flushing controls, and eMMC 5.1 storage scheduler tuning.

## File Hierarchy
- `etc/systemd/zram-generator.conf`: Defines 3GB zram swap pool using `zstd` compression.
- `etc/sysctl.d/99-lenovo-d330-zram.conf`: Configures VM swappiness (180), cache pressure (50), and dirty writeback thresholds.
- `etc/udev/rules.d/60-lenovo-d330-emmc.rules`: Configures `mq-deadline` I/O elevator and read-ahead for `/dev/mmcblk0`.
