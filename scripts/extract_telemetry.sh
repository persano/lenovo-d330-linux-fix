#!/usr/bin/env bash
# ==============================================================================
# scripts/extract_telemetry.sh
#
# Automated Hardware Telemetry, ACPI Table & Intel VBT Extraction Tool
# Designed for Lenovo IdeaPad D330-10IGL (Type 82H0 / GLK-R UHD Graphics 600)
#
# Supports:
# 1. Local execution on target Linux tablet:
#    sudo ./scripts/extract_telemetry.sh --local
# 2. Remote SSH execution from development host:
#    ./scripts/extract_telemetry.sh --host user@tablet-ip [--port 22] [--key ~/.ssh/id_rsa]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DUMPS_DIR="${REPO_ROOT}/docs/dumps"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${DUMPS_DIR}/telemetry_${TIMESTAMP}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [MODE] [OPTIONS]

Modes:
  --local                 Execute extraction locally on the current system (requires sudo/root)
  --host <user@ip>        Execute extraction remotely over SSH and pull results

Remote Options:
  -p, --port <port>       SSH port (default: 22)
  -i, --key <identity>    SSH private key identity file
  -o, --output <dir>      Destination directory (default: docs/dumps/telemetry_<timestamp>)
  -h, --help              Show this help message

Examples:
  sudo ./scripts/extract_telemetry.sh --local
  ./scripts/extract_telemetry.sh --host mint@192.168.1.50
  ./scripts/extract_telemetry.sh --host root@192.168.1.50 -p 2222 -i ~/.ssh/d330_key
EOF
}

# Payload script executed on target device (local or remote)
generate_collector_script() {
    cat <<'COLLECTOR_EOF'
#!/usr/bin/env bash
set -uo pipefail

TARGET_OUT="$1"
mkdir -p "${TARGET_OUT}"/{acpi,drm,vbt,sensors,dmi,logs,power}

echo "[*] Collecting DMI and System Identification..."
if command -v dmidecode >/dev/null 2>&1; then
    dmidecode > "${TARGET_OUT}/dmi/dmidecode_full.txt" 2>&1 || true
    dmidecode -t system > "${TARGET_OUT}/dmi/dmidecode_system.txt" 2>&1 || true
    dmidecode -t baseboard > "${TARGET_OUT}/dmi/dmidecode_baseboard.txt" 2>&1 || true
    dmidecode -t bios > "${TARGET_OUT}/dmi/dmidecode_bios.txt" 2>&1 || true
fi

if [ -d /sys/class/dmi/id ]; then
    for f in /sys/class/dmi/id/*; do
        if [ -f "$f" ] && [ -r "$f" ]; then
            val=$(cat "$f" 2>/dev/null || true)
            echo "$(basename "$f"): $val" >> "${TARGET_OUT}/dmi/sys_dmi_summary.txt"
        fi
    done
fi

echo "[*] Extracting ACPI Tables..."
if [ -d /sys/firmware/acpi/tables ]; then
    mkdir -p "${TARGET_OUT}/acpi/raw"
    cp -r /sys/firmware/acpi/tables/* "${TARGET_OUT}/acpi/raw/" 2>/dev/null || true
fi

if command -v acpidump >/dev/null 2>&1; then
    acpidump -b -o "${TARGET_OUT}/acpi/acpidump.bin" 2>/dev/null || true
    acpidump > "${TARGET_OUT}/acpi/acpidump.txt" 2>/dev/null || true
fi

# Disassemble ACPI tables if iasl is available
if command -v iasl >/dev/null 2>&1 && [ -d "${TARGET_OUT}/acpi/raw" ]; then
    echo "[*] Disassembling ACPI tables via iasl..."
    mkdir -p "${TARGET_OUT}/acpi/dsl"
    cd "${TARGET_OUT}/acpi/raw"
    for aml in DSDT* SSDT*; do
        if [ -f "$aml" ]; then
            iasl -d "$aml" >/dev/null 2>&1 || true
        fi
    done
    mv *.dsl "${TARGET_OUT}/acpi/dsl/" 2>/dev/null || true
    cd - >/dev/null
fi

echo "[*] Extracting Intel GPU VBT & DebugFS Telemetry..."
# Mount debugfs if not already mounted
if ! mountpoint -q /sys/kernel/debug; then
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi

# Locate i915 debugfs directory
I915_DEBUG_DIR=""
for d in /sys/kernel/debug/dri/*; do
    if [ -f "${d}/i915_vbt" ] || [ -f "${d}/i915_display_info" ]; then
        I915_DEBUG_DIR="$d"
        break
    fi
done

if [ -n "$I915_DEBUG_DIR" ]; then
    echo "Found i915 debugfs at ${I915_DEBUG_DIR}"
    [ -f "${I915_DEBUG_DIR}/i915_vbt" ] && cp "${I915_DEBUG_DIR}/i915_vbt" "${TARGET_OUT}/vbt/i915_vbt.bin"
    [ -f "${I915_DEBUG_DIR}/i915_display_info" ] && cp "${I915_DEBUG_DIR}/i915_display_info" "${TARGET_OUT}/drm/i915_display_info.txt"
    [ -f "${I915_DEBUG_DIR}/i915_panel_pwr_state" ] && cp "${I915_DEBUG_DIR}/i915_panel_pwr_state" "${TARGET_OUT}/drm/i915_panel_pwr_state.txt"
    [ -f "${I915_DEBUG_DIR}/i915_power_well_info" ] && cp "${I915_DEBUG_DIR}/i915_power_well_info" "${TARGET_OUT}/drm/i915_power_well_info.txt"
    [ -f "${I915_DEBUG_DIR}/i915_opregion" ] && cp "${I915_DEBUG_DIR}/i915_opregion" "${TARGET_OUT}/drm/i915_opregion.bin"
fi

# Decode VBT if intel_vbt_decode is installed
if command -v intel_vbt_decode >/dev/null 2>&1 && [ -f "${TARGET_OUT}/vbt/i915_vbt.bin" ]; then
    echo "[*] Decoding Intel VBT..."
    intel_vbt_decode "${TARGET_OUT}/vbt/i915_vbt.bin" > "${TARGET_OUT}/vbt/vbt_decoded.txt" 2>&1 || true
fi

echo "[*] Extracting DRM Connector and Display Mode State..."
if [ -d /sys/class/drm ]; then
    for conn in /sys/class/drm/card*-*; do
        [ -d "$conn" ] || continue
        cname=$(basename "$conn")
        mkdir -p "${TARGET_OUT}/drm/${cname}"
        for attr in status enabled dpms modes mode edid; do
            if [ -f "${conn}/${attr}" ] && [ -r "${conn}/${attr}" ]; then
                cp "${conn}/${attr}" "${TARGET_OUT}/drm/${cname}/${attr}" 2>/dev/null || true
            fi
        done
        # Decode EDID if present
        if command -v edid-decode >/dev/null 2>&1 && [ -f "${TARGET_OUT}/drm/${cname}/edid" ] && [ -s "${TARGET_OUT}/drm/${cname}/edid" ]; then
            edid-decode "${TARGET_OUT}/drm/${cname}/edid" > "${TARGET_OUT}/drm/${cname}/edid_decoded.txt" 2>&1 || true
        fi
    done
fi

echo "[*] Extracting GPIO & Sensor States..."
if [ -f /sys/kernel/debug/gpio ]; then
    cat /sys/kernel/debug/gpio > "${TARGET_OUT}/sensors/gpio_debugfs.txt" 2>/dev/null || true
fi

if [ -d /sys/bus/iio/devices ]; then
    for dev in /sys/bus/iio/devices/*; do
        [ -d "$dev" ] || continue
        dname=$(basename "$dev")
        echo "=== Device: $dname ===" >> "${TARGET_OUT}/sensors/iio_devices.txt"
        for attr in name in_accel_* in_illuminance_* mount_matrix; do
            for f in "${dev}"/${attr}; do
                [ -f "$f" ] && echo "$(basename "$f"): $(cat "$f" 2>/dev/null || true)" >> "${TARGET_OUT}/sensors/iio_devices.txt"
            done
        done
    done
fi

echo "[*] Extracting Power Management & Sleep State Config..."
[ -f /sys/power/state ] && cat /sys/power/state > "${TARGET_OUT}/power/sys_power_state.txt" 2>/dev/null || true
[ -f /sys/power/mem_sleep ] && cat /sys/power/mem_sleep > "${TARGET_OUT}/power/sys_mem_sleep.txt" 2>/dev/null || true
[ -f /sys/power/wakeup_count ] && cat /sys/power/wakeup_count > "${TARGET_OUT}/power/wakeup_count.txt" 2>/dev/null || true

echo "[*] Capturing System and Kernel Logs..."
dmesg -T > "${TARGET_OUT}/logs/dmesg_boot.txt" 2>&1 || true
uname -a > "${TARGET_OUT}/logs/uname.txt" 2>&1 || true
cat /proc/cmdline > "${TARGET_OUT}/logs/cmdline.txt" 2>&1 || true
lsmod > "${TARGET_OUT}/logs/lsmod.txt" 2>&1 || true
lspci -vvvnn > "${TARGET_OUT}/logs/lspci.txt" 2>&1 || true
lsusb -v > "${TARGET_OUT}/logs/lsusb.txt" 2>&1 || true

echo "[*] Extraction complete at ${TARGET_OUT}"
COLLECTOR_EOF
}

run_local() {
    log_info "Running local hardware telemetry extraction..."
    if [ "$EUID" -ne 0 ]; then
        log_err "Local extraction requires root privileges to read debugfs and ACPI tables."
        log_err "Please run with: sudo $0 --local"
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR"
    local temp_script
    temp_script="$(mktemp /tmp/d330_collect_XXXXXX.sh)"
    generate_collector_script > "$temp_script"
    chmod +x "$temp_script"

    log_step "Executing collector routine..."
    "$temp_script" "$OUTPUT_DIR"
    rm -f "$temp_script"

    # Create archive
    local tarball="${DUMPS_DIR}/telemetry_${TIMESTAMP}.tar.gz"
    tar -czf "$tarball" -C "$DUMPS_DIR" "telemetry_${TIMESTAMP}"
    log_ok "Telemetry collection completed!"
    log_ok "Raw Directory: ${OUTPUT_DIR}"
    log_ok "Archive:       ${tarball}"
}

run_remote() {
    local host="$1"
    local port="$2"
    local key="$3"

    log_info "Connecting to remote tablet at ${host} (port ${port})..."

    local ssh_opts=(-p "$port" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
    if [ -n "$key" ]; then
        ssh_opts+=(-i "$key")
    fi

    # Verify connectivity
    if ! ssh "${ssh_opts[@]}" "$host" "echo '[*] SSH Handshake Successful'" 2>/dev/null; then
        log_err "Failed to establish SSH connection to ${host}."
        exit 1
    fi

    local remote_temp="/tmp/d330_telemetry_${TIMESTAMP}"
    local remote_script="/tmp/d330_collector_${TIMESTAMP}.sh"

    log_step "Transferring collector payload to target..."
    generate_collector_script | ssh "${ssh_opts[@]}" "$host" "cat > ${remote_script} && chmod +x ${remote_script}"

    log_step "Executing telemetry extraction on remote target (requires sudo)..."
    ssh "${ssh_opts[@]}" -t "$host" "sudo ${remote_script} ${remote_temp} && sudo tar -czf ${remote_temp}.tar.gz -C /tmp $(basename "$remote_temp") && sudo rm -f ${remote_script}"

    log_step "Pulling telemetry bundle from remote target..."
    mkdir -p "$DUMPS_DIR"
    local local_tar="${DUMPS_DIR}/telemetry_${TIMESTAMP}.tar.gz"

    local scp_opts=(-P "$port")
    if [ -n "$key" ]; then
        scp_opts+=(-i "$key")
    fi

    scp "${scp_opts[@]}" "${host}:${remote_temp}.tar.gz" "$local_tar"
    ssh "${ssh_opts[@]}" "$host" "sudo rm -rf ${remote_temp} ${remote_temp}.tar.gz"

    log_step "Unpacking collected archive into repository..."
    mkdir -p "$OUTPUT_DIR"
    tar -xzf "$local_tar" -C "$DUMPS_DIR"

    log_ok "Remote telemetry extraction complete!"
    log_ok "Extracted directory: ${OUTPUT_DIR}"
    log_ok "Saved archive:       ${local_tar}"
}

main() {
    local mode=""
    local host=""
    local port="22"
    local key=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                mode="local"
                shift
                ;;
            --host)
                mode="remote"
                host="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -i|--key)
                key="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_err "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ -z "$mode" ]; then
        log_err "Must specify either --local or --host <target>."
        usage
        exit 1
    fi

    if [ "$mode" = "local" ]; then
        run_local
    elif [ "$mode" = "remote" ]; then
        [ -z "$host" ] && { log_err "Remote host unspecified"; exit 1; }
        run_remote "$host" "$port" "$key"
    fi
}

main "$@"
