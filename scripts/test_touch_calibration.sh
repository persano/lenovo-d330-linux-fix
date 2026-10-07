#!/usr/bin/env bash
# ==============================================================================
# test_touch_calibration.sh
# Diagnostic and verification tool for Lenovo IdeaPad D330 Touchscreen & Pen
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}  $*"; }

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Diagnostic and test harness for Lenovo D330 touchscreen and active pen calibration.

Options:
    --dry-run       Audit installed configurations without modifying hardware state
    --test-unbind   Test unbind/bind cycle of Goodix I2C touch controller
    --monitor       Monitor touch and pen input events via libinput or evtest
    --help          Show this message
EOF
}

DRY_RUN=0
TEST_UNBIND=0
MONITOR=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --test-unbind) TEST_UNBIND=1 ;;
        --monitor) MONITOR=1 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown argument: $arg"; show_help; exit 1 ;;
    esac
done

log_info "=== Lenovo D330 Touchscreen & Active Pen Diagnostic ==="

# 1. Check DMI Identification
if [ -f /sys/class/dmi/id/product_version ]; then
    PROD=$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)
    log_info "Detected DMI Product: $PROD"
else
    log_warn "DMI product info not accessible (simulated or non-Linux host)"
fi

# 2. Check Touchscreen Device in Sysfs / I2C
log_info "Probing I2C Goodix device nodes..."
FOUND_DEV=0
for dev in /sys/bus/i2c/devices/*GDIX1001*; do
    if [ -d "$dev" ]; then
        log_ok "Found Goodix ACPI device: $dev"
        FOUND_DEV=1
    fi
done

if [ $FOUND_DEV -eq 0 ]; then
    log_warn "No physical GDIX1001 node detected in /sys/bus/i2c/devices/ (running on VM or host)"
fi

# 3. Check Input Subsystem
log_info "Checking input subsystem event devices..."
if [ -f /proc/bus/input/devices ]; then
    if grep -i "Goodix" /proc/bus/input/devices >/dev/null 2>&1; then
        log_ok "Goodix input device detected in /proc/bus/input/devices"
        grep -E "Name=|Handlers=" /proc/bus/input/devices | grep -B1 -i "Goodix" || true
    else
        log_warn "No Goodix input handlers in /proc/bus/input/devices"
    fi
else
    log_warn "/proc/bus/input/devices missing"
fi

# 4. Check libinput / udev Calibration
log_info "Checking udev calibration matrix rules..."
RULES_FILE="/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules"
HWDB_FILE="/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb"

if [ -f "$RULES_FILE" ]; then
    log_ok "Installed udev rule: $RULES_FILE"
else
    log_warn "Udev rule not installed at $RULES_FILE"
fi

if [ -f "$HWDB_FILE" ]; then
    log_ok "Installed hwdb rule: $HWDB_FILE"
else
    log_warn "Hwdb rule not installed at $HWDB_FILE"
fi

# 5. Check sleep hook
SLEEP_HOOK="/usr/lib/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh"
if [ -f "$SLEEP_HOOK" ]; then
    log_ok "Installed systemd sleep hook: $SLEEP_HOOK"
else
    log_warn "System-sleep hook not installed at $SLEEP_HOOK"
fi

# 6. Unbind/bind test if requested
if [ $TEST_UNBIND -eq 1 ]; then
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[DRY-RUN] Would cycle /sys/bus/i2c/drivers/goodix/unbind -> bind"
    else
        if [ "$EUID" -ne 0 ]; then
            log_err "Root privileges required to trigger I2C rebind"
            exit 1
        fi
        log_info "Testing Goodix controller unbind/rebind cycle..."
        if [ -f "$SLEEP_HOOK" ]; then
            bash "$SLEEP_HOOK" post suspend
            log_ok "Touch controller reset executed via sleep hook"
        else
            log_err "Sleep hook not found, cannot test unbind"
        fi
    fi
fi

# 7. Monitor if requested
if [ $MONITOR -eq 1 ]; then
    log_info "Starting input monitor (Press Ctrl+C to stop)..."
    if command -v libinput >/dev/null 2>&1; then
        libinput debug-events --device /dev/input/event* || true
    elif command -v evtest >/dev/null 2>&1; then
        evtest || true
    else
        log_err "Neither libinput nor evtest found in PATH"
    fi
fi

log_ok "Touchscreen and pen diagnostic check completed."
