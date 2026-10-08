---
phase: 39-udev-hwdb-wireless-correctness
reviewed: 2026-10-08
reviewer: gsd-code-reviewer (diff d5b8010..HEAD + all patches/*/etc/modprobe.d)
status: all findings fixed (see 39-REVIEW-FIX.md)
---

# Phase 39 Code Review

| # | Sev | Location | Finding | Status |
|---|-----|----------|---------|--------|
| 1 | CRITICAL | `tools/d330-refresh-screen.sh:35` | awk matched the wrong rotation token (`(normal` parenthesised), so a "refresh" rotated 90 deg; plus reported success while changing nothing. | FIXED e5dcb71 |
| 2 | HIGH | `patches/power/etc/modprobe.d/lenovo-d330-power.conf:4,7` | `options iwlwifi ...` on a machine with no Intel Wi-Fi; `pcie_aspm policy=` targets a non-module boot param; `i915 enable_rc6` removed in modern kernels. | FIXED 8ba71c1 |
| 3 | HIGH | `scripts/test_udev_hwdb_match.sh` | Guard only grepped the wireless conf (missed power conf); only asserted `pn82H0`. | FIXED 3b6860b (scans all 22 options; asserts all 3 product codes) |
| 4 | MEDIUM | `patches/touchscreen/etc/udev/hwdb.d/62-...hwdb:10,16,22,28` | `touchscreen:`/`libinput:` hwdb lookup keys are never composed (libinput >=1.12 dropped hwdb model config) -> inert. | FIXED 0ee0b58 (converted to `evdev:` keys; authoritative path = 90 udev rule) |
| 5 | MEDIUM | `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf:13` | `ant_sel` is out-of-tree-only; `rtw88_8821ce ant_sel=2` is ignored. | FIXED a3dc764 (kept only on `rtl8821ce`; §7.6 + test message corrected) |
| 6 | LOW | `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` | `carrier` is 0 for both a wedge and a user-disabled radio; could re-enable a radio the user turned off. | FIXED 7bcd624 (gates bounce on radio enabled) |

Clean categories (verified): sensor hwdb DMI syntax + `pn82H0` valid (not invented); case-insensitive globs valid fnmatch; `test_wireless_coex.sh` non-vacuous on module names (SC3 mutation-proven); MODE/GROUP, SOUND_INITIALIZED, WL_OUTPUT removals correct; no shell injection/quoting hazards.
