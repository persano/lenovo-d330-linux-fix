# Research: MicroSD Storage Expansion & Cellular LTE on Lenovo D330-10IGL

## 1. MicroSD Storage Expansion (`/dev/mmcblk1`)
For the entry 64GB eMMC storage configuration, the built-in UHS-I MicroSD slot provides an inexpensive, permanent expansion medium for `/home` or secondary `/data`.
`tools/d330-microsd-setup.sh` formats the media with flash-optimized ext4 (features `mmp`, `dir_index`, `sparse_super`) and generates persistent `/etc/fstab` entries with `noatime,commit=60,errors=remount-ro`.

## 2. Cellular LTE (Intel XMM 7360 / Fibocom L850-GL)
Selected D330 SKUs include a cellular modem connected via PCI Express Root Port 4 (PCI `8086:7360`).
Under Linux:
- Modem is supported by modern upstream `iosm` or `xmm7360-pci` drivers.
- **FCC Lock**: The modem boots into an RF-inhibited state requiring an FCC challenge/response unlock sequence.
- We deploy `/etc/ModemManager/fcc-unlock.d/8086:7360` with udev tags so ModemManager unlocks the modem upon network registration.
