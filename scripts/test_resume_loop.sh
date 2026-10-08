#!/usr/bin/env bash
# ==============================================================================
# scripts/test_resume_loop.sh
#
# Automated Suspend/Resume Verification & Stress Loop
# Target: Lenovo IdeaPad D330-10IGL (Type 82H0)
#
# Executes repeated RTC-wake sleep cycles and verifies display engine health:
# - Tests S3 / S0ix sleep via rtcwake
# - Checks dmesg for i915 pipe freeze, FIFO underrun, or GPU hang
# - Checks lenovo_d330_fix suspend/resume breadcrumbs (banner only; the PPS
#   clamp is delivered by the Option 2 kernel patch, not this module)
# - Verifies DRM connector status post-resume
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/tmp/resume_test_$(date +%Y%m%d_%H%M%S).log"
LOG_FILE_SET=false

CYCLES=5
SLEEP_SECS=10
WAKE_SECS=10
SIMULATE=false

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") [OPTIONS]

Options:
  -c, --cycles NUM      Number of sleep/wake iterations (default: 5)
  -s, --sleep SECS      Seconds to stay in sleep mode (default: 10)
  -w, --wake SECS       Seconds to wait between cycles (default: 10)
  -l, --log FILE        Custom path for test execution log
      --simulate        CI mode: fabricate 5 clean cycles without rtcwake/dmesg
      --dry-run         Alias for --simulate
  -h, --help            Show this help message
EOF
}

die_arg() {
    echo "[!] $*" >&2
    usage
    exit 1
}

require_arg() {
    # $1 = option flag, $2 = the parsed value (may be empty/unset) -- IN-02:
    # a trailing flag with no value must not abort on unbound $2 under set -u.
    if [ -z "${2:-}" ] || [ "${2#--}" != "$2" ]; then
        die_arg "Option $1 requires an argument."
    fi
}

require_uint() {
    # $1 = option flag, $2 = value; must be a non-negative integer so a
    # non-numeric --cycles cannot silently run 0 cycles and exit 0.
    if ! echo "$2" | grep -qE '^[0-9]+$'; then
        die_arg "Option $1 requires a non-negative integer (got: '$2')."
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cycles) require_arg "$1" "${2:-}"; require_uint "$1" "$2"; CYCLES="$2"; shift 2 ;;
        -s|--sleep) require_arg "$1" "${2:-}"; require_uint "$1" "$2"; SLEEP_SECS="$2"; shift 2 ;;
        -w|--wake) require_arg "$1" "${2:-}"; require_uint "$1" "$2"; WAKE_SECS="$2"; shift 2 ;;
        -l|--log) require_arg "$1" "${2:-}"; LOG_FILE="$2"; LOG_FILE_SET=true; shift 2 ;;
        --simulate|--dry-run) SIMULATE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [ "$EUID" -ne 0 ] && [ "$SIMULATE" != true ]; then
    echo "[!] Root privileges required for rtcwake. Run with sudo." >&2
    exit 1
fi

# Simulate mode touches no hardware and must not litter the repo with logs.
if [ "$SIMULATE" = true ] && [ "$LOG_FILE_SET" = false ]; then
    LOG_FILE="$(mktemp -t d330_resume_sim.XXXXXX)"
fi

mkdir -p "$(dirname "$LOG_FILE")"
echo "================================================================================" | tee -a "$LOG_FILE"
echo " Lenovo D330-10IGL Suspend/Resume Stress Test Session" | tee -a "$LOG_FILE"
echo " Started: $(date)" | tee -a "$LOG_FILE"
echo " Planned Cycles: ${CYCLES} (Sleep: ${SLEEP_SECS}s, Wake: ${WAKE_SECS}s)" | tee -a "$LOG_FILE"
echo " Log Target: ${LOG_FILE}" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"

passed=0
failed=0

for ((i = 1; i <= CYCLES; i++)); do
    echo "" | tee -a "$LOG_FILE"
    echo "[*] === Cycle $i / $CYCLES ===" | tee -a "$LOG_FILE"
    echo "    Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"

    if [ "$SIMULATE" = true ]; then
        # CI path: no rtcwake, no dmesg, no hardware. Fabricate one clean cycle.
        echo "    [SIMULATE] Fabricated clean wake cycle (no rtcwake/dmesg)." | tee -a "$LOG_FILE"
        echo "    [PASS] Clean wake. Display pipeline responsive." | tee -a "$LOG_FILE"
        passed=$((passed + 1))
        continue
    fi

    # Pre-sleep DRM state check
    edp_status="unknown"
    if [ -f /sys/class/drm/card0-eDP-1/status ]; then
        edp_status=$(cat /sys/class/drm/card0-eDP-1/status)
    fi
    echo "    Pre-sleep eDP-1 status: ${edp_status}" | tee -a "$LOG_FILE"

    echo "    Entering suspend (rtcwake mem for ${SLEEP_SECS}s)..." | tee -a "$LOG_FILE"
    dmesg_pre=$(dmesg | wc -l)

    # Trigger rtcwake
    if ! rtcwake -m mem -s "$SLEEP_SECS" >> "$LOG_FILE" 2>&1; then
        echo "    [FAIL] rtcwake returned error exit code!" | tee -a "$LOG_FILE"
        failed=$((failed + 1))
        continue
    fi

    echo "    Woke up. Waiting ${WAKE_SECS}s to verify display stability..." | tee -a "$LOG_FILE"
    sleep "$WAKE_SECS"

    # Post-sleep DRM state check
    post_status="unknown"
    if [ -f /sys/class/drm/card0-eDP-1/status ]; then
        post_status=$(cat /sys/class/drm/card0-eDP-1/status)
    fi
    echo "    Post-sleep eDP-1 status: ${post_status}" | tee -a "$LOG_FILE"

    # Inspect kernel log since wake
    new_dmesg=$(dmesg | tail -n "+$((dmesg_pre + 1))")
    cycle_errors=$(echo "$new_dmesg" | grep -Ei "pipe .* underrun|gpu hang|drm:.*error|i915.*timed out" || true)
    timing_logs=$(echo "$new_dmesg" | grep -Ei "lenovo_d330_fix|Enforcing TCON" || true)

    if [ -n "$timing_logs" ]; then
        echo "    [+] Quirk Driver Action:" | tee -a "$LOG_FILE"
        echo "$timing_logs" | sed 's/^/        /' | tee -a "$LOG_FILE"
    fi

    if [ -n "$cycle_errors" ]; then
        echo "    [FAIL] Detected DRM/i915 driver errors in dmesg:" | tee -a "$LOG_FILE"
        echo "$cycle_errors" | sed 's/^/        /' | tee -a "$LOG_FILE"
        failed=$((failed + 1))
    else
        echo "    [PASS] Clean wake. Display pipeline responsive." | tee -a "$LOG_FILE"
        passed=$((passed + 1))
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"
echo " Test Summary: Passed: ${passed} / ${CYCLES}, Failed: ${failed} / ${CYCLES}" | tee -a "$LOG_FILE"
echo " Finished: $(date)" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
