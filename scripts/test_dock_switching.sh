#!/usr/bin/env bash
# ==============================================================================
# test_dock_switching.sh
# Diagnostic and automated testing for Lenovo D330 Dock & Tablet Mode Daemon
# ==============================================================================

set -euo pipefail

# CWD anchoring: resolve the repo root from this script's own location so the
# tools/ references below work from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

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

Harness for testing Lenovo IdeaPad D330 dock connection and tablet mode events.

Options:
    --status        Display current hardware dock status and daemon state
    --test-laptop   Simulate dock connection (laptop mode)
    --test-tablet   Simulate dock detachment (tablet mode)
    --cycle-test N  Execute N automated dock/undock state switch cycles
    --help          Show this message
EOF
}

STATUS=0
TEST_LAPTOP=0
TEST_TABLET=0
CYCLE_N=0
FAILED=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status) STATUS=1; shift ;;
        --test-laptop) TEST_LAPTOP=1; shift ;;
        --test-tablet) TEST_TABLET=1; shift ;;
        --cycle-test)
            if [[ -z "${2:-}" || "${2#--}" != "$2" ]]; then
                log_err "--cycle-test requires a cycle count."
                show_help
                exit 1
            fi
            if ! echo "$2" | grep -qE '^[0-9]+$'; then
                log_err "--cycle-test requires a non-negative integer (got: '$2')."
                show_help
                exit 1
            fi
            CYCLE_N="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown argument: $1"; show_help; exit 1 ;;
    esac
done

DAEMON_SCRIPT="$SCRIPT_DIR/tools/d330-tablet-daemon.py"
if [ ! -f "$DAEMON_SCRIPT" ]; then
    DAEMON_SCRIPT="/usr/local/bin/d330-tablet-daemon"
fi

log_info "=== Lenovo D330 Detachable Dock Test Harness ==="

# 1. Hardware probe
log_info "Checking kernel modules for Intel HID and dock drivers..."
for mod in intel_hid intel_vbtn elan_i2c; do
    if lsmod 2>/dev/null | grep -q "^$mod"; then
        log_ok "Module loaded: $mod"
    else
        log_warn "Module not active: $mod"
    fi
done

# 2. Check daemon status
if [ -f "$DAEMON_SCRIPT" ]; then
    log_info "Querying daemon hardware status..."
    if ! python3 "$DAEMON_SCRIPT" --status; then
        log_err "Daemon status query failed at $DAEMON_SCRIPT."
        FAILED=$((FAILED + 1))
    fi
else
    log_err "Daemon script not found at $DAEMON_SCRIPT"
    FAILED=$((FAILED + 1))
fi

# 3. Actions
if [ $TEST_LAPTOP -eq 1 ]; then
    log_info "Simulating LAPTOP MODE (dock connected)..."
    python3 "$DAEMON_SCRIPT" --dry-run --simulate-dock
    log_ok "Laptop mode simulated successfully."
fi

if [ $TEST_TABLET -eq 1 ]; then
    log_info "Simulating TABLET MODE (dock detached)..."
    python3 "$DAEMON_SCRIPT" --dry-run --simulate-undock
    log_ok "Tablet mode simulated successfully."
fi

if [ $CYCLE_N -gt 0 ]; then
    log_info "Running $CYCLE_N dock/undock toggle cycles..."
    for i in $(seq 1 "$CYCLE_N"); do
        echo -e "\n--- Cycle $i of $CYCLE_N ---"
        python3 "$DAEMON_SCRIPT" --dry-run --simulate-undock
        sleep 0.5
        python3 "$DAEMON_SCRIPT" --dry-run --simulate-dock
        sleep 0.5
    done
    log_ok "Completed $CYCLE_N cycle test successfully."
fi

if [ "$FAILED" -gt 0 ]; then
    log_err "${FAILED} dock verification check(s) failed."
    exit 1
fi

log_ok "Dock verification check finished."
