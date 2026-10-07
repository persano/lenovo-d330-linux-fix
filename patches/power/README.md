# Battery Life & Power Governors

This directory packages power management configurations, TLP presets, and udev runtime power management rules for the Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`).

## Contents

- `etc/tlp.d/50-lenovo-d330.conf`: TLP power profile tailored for fanless 6W Celeron Gemini Lake.
- `etc/udev/rules.d/95-lenovo-d330-power.rules`: Runtime PM rules for PCIe ASPM, eMMC storage, USB autosuspend, and audio DSP.
- `etc/modprobe.d/lenovo-d330-power.conf`: Kernel power optimization options (`iwlwifi`, `pcie_aspm`, `i915 enable_rc6`).
- `etc/systemd/system/lenovo-d330-power.service`: Systemd service executing `lenovo-d330-power-tune`.

Power tuning script: `tools/lenovo-d330-power-tune.sh`
Diagnostic and telemetry script: `scripts/test_battery_power.sh`
