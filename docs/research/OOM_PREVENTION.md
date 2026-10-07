# Research: Out-Of-Memory Lockup Prevention on Lenovo D330-10IGL

## 1. Problem
With only 4GB of soldered physical RAM:
- Modern heavy web applications (Google Docs, Slack, Canva, or opening 15+ tabs) can exhaust available anonymous memory quickly.
- When RAM is full, the default Linux kernel `kswapd` paging daemon attempts heroic recovery, evicting vital executable file pages from pagecache and scanning compressed ZRAM endlessly.
- The system enters **thrashing lockup**: the cursor freezes, audio stutters, and the tablet becomes completely unresponsive for 45–90 seconds before the kernel OOM killer finally reacts.

## 2. Solution: Userspace Preemptive OOM (`earlyoom`)
`earlyoom` operates in userspace, monitoring `/proc/meminfo` every second:
- Triggers when free RAM drops below **4%** AND free swap drops below **10%**.
- Selects the culprit process based on badness score, specifically prioritizing browser rendering processes (`Web Content`, `chrome`, `firefox`).
- Terminating a single heavy background tab restores memory within **50 milliseconds**, keeping the desktop session completely responsive with zero hard reboots.
