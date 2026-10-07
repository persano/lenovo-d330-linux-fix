# Research: Sensor Hysteresis & Ambient Light Sensor (ALS) on Lenovo D330-10IGL

## 1. Hardware Sensors
The Lenovo IdeaPad D330-10IGL includes:
1. **Bosch BOSC0200 3-Axis Accelerometer**: Wired via I2C (`/sys/bus/iio/devices/iio:device0`), delivering gravity vector readings for display orientation.
2. **ACPI0008 Ambient Light Sensor (ALS)**: Delivers illuminance readings in lux.

## 2. Issues Under Default Linux Desktop
- **Orientation Jitter**: Small vibrations (such as typing on the detachable keyboard on a lap or table tilt) trigger sudden screen orientation switches between landscape and portrait.
- **Backlight Stepping**: Sudden rapid changes in indoor lighting cause the backlight to jump erratically in discrete, distracting steps.

## 3. Stabilization Architecture
1. **Accelerometer Hysteresis & Debounce (`tools/d330-sensor-filter.py`)**:
   - Enforces a 15-degree orientation deadband window.
   - Enforces a 500 ms debounce duration before committing a physical screen rotation.
2. **Exponential Moving Average (EMA) for ALS**:
   - Applies an EMA filter with smoothing factor $\alpha = 0.15$:
     $$S_t = \alpha \cdot Y_t + (1 - \alpha) \cdot S_{t-1}$$
   - Eliminates rapid backlight steps, delivering seamless brightness adaptation across room lighting transitions.
