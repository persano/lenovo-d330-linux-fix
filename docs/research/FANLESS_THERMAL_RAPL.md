# Research: Fanless Thermal Management & RAPL Power Caps on Lenovo D330-10IGL

## 1. Thermal Characteristics
The Lenovo IdeaPad D330-10IGL operates without an internal cooling fan (0 dB fanless operation), dissipating heat through copper heat spreaders into the magnesium/polycarbonate back chassis.
- CPU: Intel Celeron N4020 (Dual Core) or N4120 (Quad Core).
- Base TDP: 6.0 Watts.
- Maximum Junction Temperature ($T_j$ max): 105°C.

## 2. The Thermal Throttling Cliff Problem
Default Linux power profiles allow unconstrained turbo bursts up to 10W+. In a sealed tablet chassis, this causes temperature to spike past 75°C in under 60 seconds.
When default Linux thermal governors trip, they abruptly collapse CPU frequency down to **800 MHz (minimum P-state)**. The user experiences severe stutter, dropped mouse frames, and keyboard input delays until the chassis cools down.

## 3. Smooth RAPL Clamping
By programming Intel Running Average Power Limit (RAPL) sysfs parameters:
- **PL1 (Long Term)**: Clamped to 5.0 W.
- **PL2 (Short Term)**: Clamped to 8.0 W for 10 seconds.
- **`thermald` Trip Point**: 72°C passive throttling with smooth RAPL duty cycle step-down.
Prevents the CPU from ever hitting the harsh 800 MHz thermal cliff, keeping performance smooth and the tablet comfortable to hold.
