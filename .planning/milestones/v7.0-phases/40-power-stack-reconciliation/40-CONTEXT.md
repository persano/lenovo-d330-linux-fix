# Phase 40: Power Stack Reconciliation - Context

**Gathered:** 2026-10-08 | **Status:** Ready (auto-accepted; slim pipeline)

<domain>
Audit M13/M14: one writer per knob — TLP, udev, `lenovo-d330-power-tune.sh`, thermald and RAPL must not fight. Scope: `tools/lenovo-d330-power-tune.sh`, `patches/power/etc/udev/rules.d/95-...rules`, `patches/power/etc/tlp.d/50-lenovo-d330.conf`, `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg`, `tools/d330-fastboot-tune.sh`, `patches/thermal/etc/thermald/thermal-conf.xml`, `tools/d330-thermal-tune.sh`, `packaging/debian/control`, `CHANGES_AUDIT.md`.
</domain>

<decisions>
- **CPU perf cap** (`power-tune.sh:43-45`): make it AC-aware — set `max_perf_pct=100` on AC and the capped value only on battery — and re-run it on power-source change via a `SUBSYSTEM=="power_supply"` udev rule (or a TLP hook) so plugging AC lifts the cap without reboot. Do not leave a boot-only cap.
- **Runtime PM** (`95-...rules` vs TLP `RUNTIME_PM_ON_AC=on`): TLP is the single owner for PCI/USB/I2C/sound; reduce the udev rule to only devices TLP does not manage (eMMC host, dock). No two writers on the same knob.
- **TLP GPU freq** (`50-...conf:24-25`): remove `INTEL_GPU_MIN_FREQ_ON_AC=100` (below the GLK min ~300 MHz, rejected every AC event) or set it to the real minimum; keep/validate `MAX_FREQ_ON_AC=650`/`BOOST=700` against `/sys/class/drm/card0/gt_max_freq_mhz` and clamp/document if the hardware max differs.
- **nowatchdog** (`52-...fastboot.cfg:4`): remove `nowatchdog` (disables NMI/softlockup detection on the device whose premise is pipe lockups) and replace with `softlockup_panic=1` so a hang self-recovers.
- **fastboot claim** (`d330-fastboot-tune.sh:31-32`): keep masking `NetworkManager-wait-online`; correct the "12 seconds from watchdog" claim in `CHANGES_AUDIT.md` §7.7 to the real measured win (wait-online) and drop the watchdog attribution.
- **thermald zone type** (`thermal-conf.xml:11`): `<Type>cpu</Type>` must match the sysfs zone `type` (expected `x86_pkg_temp`); make the profile robust (use the correct type if known, else guard) so thermald does not silently ignore it.
- **thermal precedence** (`d330-thermal-tune.sh`): define thermald as the runtime owner and the script as the fallback when `thermald` is absent; add `thermald` to `packaging/debian/control` Recommends.
- **thermal numeric guard** (`d330-thermal-tune.sh:21-22`): guard `pl1`/`pl2` with a numeric regex before `$((pl1 / 1000000))` so `N/A` does not become `0`.
- **the agent's Discretion:** exact udev rule scope for eMMC/dock, TLP hook vs udev for the AC re-run, max freq clamp value.
</decisions>

<code_context>
- `power-tune.sh:43-45` boot-only `intel_pstate/max_perf_pct=75` on battery.
- `95-...rules:3-15` forces `power/control=auto` broadly; `50-lenovo-d330.conf:16` `RUNTIME_PM_ON_AC=on`.
- `50-lenovo-d330.conf:24-25` `INTEL_GPU_MIN_FREQ_ON_AC=100`, `MAX_FREQ_ON_AC=650`/`BOOST=700`.
- `52-...fastboot.cfg:4` `nowatchdog`. `d330-fastboot-tune.sh:31-32` masks `NetworkManager-wait-online`.
- `thermal-conf.xml:11` `<Type>cpu</Type>`. `d330-thermal-tune.sh:21-22` `$((pl1 / 1000000))`.
- `packaging/debian/control` lacks thermald. SC1/SC2/SC3 are hardware/boot-bound -> overrides; static config + numeric guard are machine-checkable.
</code_context>

<canonical_refs>
- `.planning/ROADMAP.md` `### Phase 40:` (goal, SC1-3, components, Audit M13/M14)
- `.planning/phases/39-udev-hwdb-wireless-correctness/39-01-PLAN.md` (guard-suite pattern)
</canonical_refs>

<deferred>
- Real `tlp-stat -s` vs `/sys/class/powercap` agreement and a full boot bench on hardware.
</deferred>
