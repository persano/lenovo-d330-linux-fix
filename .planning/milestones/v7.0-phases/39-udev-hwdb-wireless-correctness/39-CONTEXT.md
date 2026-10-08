# Phase 39: udev / hwdb / Wireless Match Correctness - Context

**Gathered:** 2026-10-08 | **Status:** Ready (auto-accepted; slim pipeline)

<domain>
Audit M8/M9/M10/M15/M16: every udev rule and hwdb entry must match real device strings on the target, and every modprobe option must land on a module that exists. Scope: `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf`, `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh`, `patches/dkms/etc/udev/hwdb.d/61-...sensor.hwdb`, `patches/touchscreen/etc/udev/hwdb.d/62-...touchscreen.hwdb`, `patches/sensors/etc/udev/rules.d/87-...rules`, `patches/hardware_controls/etc/udev/rules.d/88-...rules`, `patches/audio_dsp/etc/udev/rules.d/91-...rules`, `patches/touchscreen/etc/udev/rules.d/90-...rules`, `tools/d330-refresh-screen.sh`, `scripts/test_wireless_coex.sh`, `CHANGES_AUDIT.md` §7.6.
</domain>

<decisions>
- **Wireless modprobe**: emit BOTH `rtl8821ce` and `rtw88_8821ce` spellings so one matches whichever the kernel ships; drop `fwlps`/`ips` (not confirmed in-tree rtw88 params); REMOVE the `iwlwifi`/`iwlmvm` lines entirely (D330 has no Intel wireless) and correct CHANGES_AUDIT §7.6 so it no longer claims Intel coexistence config; document that Realtek BT coexistence is handled automatically by the driver (no manual param).
- **hwdb**: replace the space-stripped `pvrLenovoideapadD330-10IGL` / `...D330-10IGM` DMI patterns with the safe space-free `pn82H0:*` (and `pn81MD:*`/`pn81H3:*`) form in both hwdb files; keep valid `modalias:acpi:BOSC0200*` / `touchscreen:acpi:GDIX1001*` entries.
- **sensors 87 rules**: case-insensitive globs `*[Bb][Oo][Ss][Cc]0200*` / `*[Aa][Cc][Pp][Ii]0008*`.
- **hardware_controls 88 rules**: `MODE`/`GROUP` on a sysfs attribute is a no-op -> remove those lines and document that `d330-ctl` conservation/fn-lock require root or `pkexec` (drop the false "non-root plugdev access" claim).
- **wifi-resume hook**: replace the unconditional `nmcli radio wifi off/on` bounce with a carrier/link check (`/sys/class/net/<if>/carrier` or `nmcli -t -f STATE`); only bounce when actually wedged; remove the dead `dev=$(basename ...)`.
- **refresh-screen.sh**: read the current rotation before `--rotate right` (do not force a rotation that may double the current one); verify `/sys/class/drm/*/dpms` writes and replace with a DRM modeset (`xrandr`/`wlr-randr` preferred) or drop the no-op DPMS branch with an honest log.
- **audio 91 rule**: remove `ENV{SOUND_INITIALIZED}="1"` (consumed by nothing) or wire it; choose removal.
- **touchscreen 90 rule**: remove `ENV{WL_OUTPUT}="eDP-1"` (not a property).
- **test_wireless_coex.sh**: make it fail (non-zero) when the module name is wrong and validate the modprobe conf non-vacuously.
- **the agent's Discretion**: exact carrier-check command, sudoers-vs-document choice (document), DPMS replacement.
</decisions>

<code_context>
- `lenovo-d330-wireless.conf`: `options rtl8821ce ant_sel=2 fwlps=0 ips=0`, `options rtw88_core disable_lps_deep=y`, `options rtw88_pci disable_aspm=y`, plus `iwlwifi bt_coex_active=1 power_save=1 uapsd_disable=1` / `iwlmvm power_scheme=2`.
- `87-...sensors.rules`: `ATTR{name}=="*bosc0200*"` / `*acpi0008*` (lowercase; real HIDs `BOSC0200`/`ACPI0008`).
- `88-...hardware.rules`: `MODE="0664", GROUP="plugdev"` on platform sysfs attrs.
- `61/62 hwdb`: `pvrLenovoideapadD330-10IGL` etc.
- `90-...touchscreen.rules`: `ENV{WL_OUTPUT}="eDP-1"` (x2). `91-...headset-jack.rules`: `ENV{SOUND_INITIALIZED}="1"`.
- `wifi-resume.sh`: unconditional radio bounce; dead `dev=$(basename "$iface")`.
- `tools/d330-refresh-screen.sh`: `xrandr --output "$OUTPUT" --auto --rotate right`; `/sys/class/drm/*/dpms` writes.
- `scripts/test_wireless_coex.sh`: `--dry-run` echo-only exit 0; no module-name assertion.
- SC1 (`udevadm test` on hardware) and SC2 (`modprobe -s rtw88_8821ce`) are hardware/host-bound -> overrides; SC3 is machine-checkable.
</code_context>

<canonical_refs>
- `.planning/ROADMAP.md` `### Phase 39:` (goal, SC1-3, components with file:line, Audit M8/M9/M10/M15/M16)
- `.planning/phases/38-pipewire-dsp-activation/38-01-PLAN.md` (test-honesty pattern)
</canonical_refs>

<deferred>
- Shipping a sudoers/polkit drop-in for non-root `d330-ctl` (documented as root/pkexec-required instead).
- Real `udevadm test` / `modprobe -s` on hardware.
</deferred>
