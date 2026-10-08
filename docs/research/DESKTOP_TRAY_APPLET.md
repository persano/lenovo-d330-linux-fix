# Research: Desktop System Tray Hardware Applet on Lenovo D330-10IGL

## 1. Motivation
While command line control via `d330-ctl` allows scripted management, normal desktop users expect visual tray widgets:
- One-click toggle for Battery Conservation Mode (60% threshold) when plugging in AC power at a desk.
- One-click emergency screen refresh button to reset display modes without opening a terminal or remembering key combinations.
- Visual dock mode state indication.

## 2. Implementation
`tools/d330-tray.py` and `d330-tray.desktop` provide a dependency-free stdlib notification/status helper: a `--status` CLI that reports battery conservation (60%) state and a `notify-send` desktop notification at session start. No GTK, no AppIndicator, and no interactive tray menu.
