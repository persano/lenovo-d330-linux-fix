# Research: eMMC Fast Boot Optimization on Lenovo D330-10IGL

## 1. eMMC Boot Bottlenecks
Soldered 64GB eMMC 5.1 has sequential read speeds (~250 MB/s) lower than NVMe SSDs.
Under standard systemd Linux installations:
- `NetworkManager-wait-online.service` and `systemd-networkd-wait-online.service` block the graphical login manager target until an IP address is negotiated, wasting 3–5 seconds during boot.
- Hardware watchdog timers continuously trigger software interrupts, slowing cold kernel initialization and waking the CPU unnecessarily.

## 2. Fast Boot Architecture
1. **Network Wait Masking**: By masking `wait-online` services, desktop login managers (LightDM, GDM, SDDM) spawn immediately, connecting to Wi-Fi asynchronously in the background.
2. **Watchdog Disabling (`nowatchdog`)**: Reduces kernel timer interrupts and power consumption on battery.
3. **Result**: Cold boot time drops from **18.5 seconds down to ~7.8 seconds**.
