#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Sensor & ALS Verification Script
# Tests BOSC0200 accelerometer, ACPI0008 ambient light sensor, and iio-sensor-proxy

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_sensor_als.sh [OPTIONS]

Options:
  --probe          Inspect active IIO sensors and iio-sensor-proxy D-Bus status (default)
  --monitor        Stream raw and filtered sensor values
  --dry-run        Validate sensor filtering logic without invoking hardware
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --monitor)
            MODE="monitor"
            shift
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL Sensor Debounce & ALS Test Tool        "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Exercising the sensor filter against a fake IIO tree (no hardware touched)..."
    echo "  - Accelerometer: BOSC0200 (15 deg deadband, 500ms debounce)"
    echo "  - Light Sensor: in_illuminance_input fallback (Exponential Moving Average alpha=0.15)"
    iio_tmp="$(mktemp -d "${TMPDIR:-/tmp}/d330-als.XXXXXX")"
    trap 'rm -rf "$iio_tmp"' EXIT
    dev="${iio_tmp}/iio:device0"
    mkdir -p "$dev"
    printf 'bosc0200\n' > "$dev/name"
    printf '100\n' > "$dev/in_accel_x_raw"
    printf '0\n' > "$dev/in_accel_y_raw"
    printf '0\n' > "$dev/in_accel_z_raw"
    # Only in_illuminance_input (no _raw) so the ALS fallback path is exercised.
    printf '200\n' > "$dev/in_illuminance_input"
    D330_IIO_BASE="$iio_tmp" python3 tools/d330-sensor-filter.py --cycles 3
    echo "[DRY-RUN] Sensor filter ran 3 cycles against the fake IIO tree and exited 0."
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. IIO Sensor Devices ---"
        if [[ -d /sys/bus/iio/devices ]]; then
            for dev in /sys/bus/iio/devices/iio:device*; do
                if [[ -d "$dev" ]]; then
                    name="$(cat "$dev/name" 2>/dev/null || echo "unknown")"
                    echo "  - $dev: $name"
                fi
            done
        else
            echo "[INFO] /sys/bus/iio/devices not available."
        fi

        echo ""
        echo "--- 2. iio-sensor-proxy State ---"
        if command -v monitor-sensor >/dev/null 2>&1; then
            echo "[OK] monitor-sensor command found."
        else
            echo "[INFO] monitor-sensor not installed. Install iio-sensor-proxy."
        fi
        ;;
    monitor)
        python3 tools/d330-sensor-filter.py --monitor
        ;;
esac

echo "=========================================================="
echo " Sensor test finished.                                    "
echo "=========================================================="
