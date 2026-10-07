# Research: Wi-Fi & Bluetooth Coexistence & S2idle Resume on Lenovo D330-10IGL

## 1. Physical Antenna Sharing
The Lenovo IdeaPad D330-10IGL routes Wi-Fi and Bluetooth through shared internal PCB antennas.
Under default kernel options:
- When using Bluetooth audio (A2DP headphones) simultaneously with 2.4GHz Wi-Fi (e.g. streaming audio or video calls), packet collisions cause Bluetooth audio dropouts and Wi-Fi throughput drops down to < 2 Mbps.
- Furthermore, upon waking from `s2idle` connected sleep, the Realtek/Intel radio power-down mode (`fwlps`) occasionally causes the adapter firmware to hang, failing to auto-reconnect to Wi-Fi.

## 2. Coexistence Tuning
1. **Realtek RTL8821CE / rtw88 (`lenovo-d330-wireless.conf`)**:
   - `ant_sel=2`: Directs the Wi-Fi RF path to antenna port 2, providing better physical isolation from the Bluetooth transceiver.
   - `disable_lps_deep=y`: Prevents deep sleep lockups.
2. **Intel Wireless 9560 / 3165 (`iwlwifi`)**:
   - `bt_coex_active=1`: Enforces hardware coexistence packet scheduling.
3. **Resume Hook (`lenovo-d330-wifi-resume.sh`)**:
   - Automatically polls Wi-Fi state upon resume from S2idle, quickly cycling the radio via NetworkManager if unassociated.
