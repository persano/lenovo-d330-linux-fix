# Research: Critical Low-Battery Auto-Hibernate on Lenovo D330-10IGL

## 1. Battery Drain & Suspended State Risk
The Lenovo IdeaPad D330-10IGL features a 39 Wh 2-cell lithium-ion battery.
When left suspended in S2idle (connected standby) for extended periods (e.g. overnight in a backpack), battery capacity eventually depletes to 0%, resulting in abrupt power cutoff, filesystem corruption, or lost open work.

## 2. Auto-Hibernate Architecture
1. **Critical Threshold**: Monitored at $\le 5\%$ remaining charge while discharging.
2. **Action Sequence**:
   - `sync` all dirty filesystem blocks to prevent data loss.
   - Dispatch `systemctl hibernate` (or hybrid-sleep) via systemd.
3. **Restoration**: On plugging in the USB-C / DC charger and powering on, the kernel resumes state from the swap storage.
