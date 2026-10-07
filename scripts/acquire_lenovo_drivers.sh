#!/usr/bin/env bash
# ==============================================================================
# scripts/acquire_lenovo_drivers.sh
# 
# Autonomous Driver Acquisition and Unpacking Tool for Lenovo IdeaPad D330-10IGL
# Target Type: 82H0 (Intel Gemini Lake Refresh / Intel UHD Graphics 600)
#
# Downloads official Lenovo OEM Windows 10 x64 drivers and extracts:
# - Intel UHD Graphics (igdkmd64.sys, INF configs, panel timings)
# - Intel HID Event Filter / Mode Transition (DS545445)
# - Intel Serial-IO / GPIO Driver (DS545448 pin mappings)
# - Bosch Accelerometer G-Sensor Driver (DS545444)
# - Lenovo UEFI BIOS Firmware Update (DS545459 / G0CN14WW raw BIOS payload)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/drivers_base"
WORK_DIR="${TARGET_DIR}/.work"

# Color support
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Official Lenovo CDN Download Endpoints (D330-10IGL / 82H0 Baseline)
declare -A DRIVERS=(
    ["bios"]="https://download.lenovo.com/consumer/mobiles/g0cn14ww.exe|g0cn14ww.exe|bios_update"
    ["vga"]="https://download.lenovo.com/consumer/mobiles/3gid020fh6y37sb0.exe|3gid020fh6y37sb0.exe|vga_intel"
    ["hid"]="https://download.lenovo.com/consumer/mobiles/3gid010fu8cg1sb0.exe|3gid010fu8cg1sb0.exe|hid_mode_transition"
    ["sio"]="https://download.lenovo.com/consumer/mobiles/3gid010f3ffk4sb0.exe|3gid010f3ffk4sb0.exe|serial_io_gpio"
    ["sensor"]="https://download.lenovo.com/consumer/mobiles/3gid020fy96b0sb0.exe|3gid020fy96b0sb0.exe|sensor_bosch"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [COMPONENT...]

Components:
  vga       Intel VGA Driver (igdkmd64.sys, INF configurations)
  hid       Intel HID Event Filter / Mode Transition Driver (DS545445)
  sio       Intel Serial-IO / GPIO Controller Driver (DS545448)
  sensor    Bosch G-Sensor Accelerometer Driver (DS545444)
  bios      UEFI BIOS Update Utility & Firmware Image (DS545459)
  all       Download and extract all baseline components (Default)

Options:
  --download-only   Fetch installer executables without extraction
  --extract-only    Extract already downloaded installers in drivers_base/
  --clean           Remove intermediate temporary files after extraction
  -h, --help        Show this help message
EOF
}

check_dependencies() {
    log_info "Verifying host extraction toolchains..."
    local missing=()

    # Downloader check
    if command -v curl >/dev/null 2>&1; then
        FETCH_CMD="curl -fL -C - -o"
    elif command -v wget >/dev/null 2>&1; then
        FETCH_CMD="wget -c -O"
    else
        log_err "Neither curl nor wget is available. Install one to continue."
        exit 1
    fi

    # Extraction tools
    HAVE_7Z=false
    HAVE_INNOEXTRACT=false
    HAVE_CABEXTRACT=false

    if command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1; then
        HAVE_7Z=true
        SEVENZ_BIN="$(command -v 7z || command -v 7za)"
    fi

    if command -v innoextract >/dev/null 2>&1; then
        HAVE_INNOEXTRACT=true
    fi

    if command -v cabextract >/dev/null 2>&1; then
        HAVE_CABEXTRACT=true
    fi

    if [ "$HAVE_7Z" = false ] && [ "$HAVE_INNOEXTRACT" = false ]; then
        log_warn "Neither 7z nor innoextract found. For best results, install: p7zip-full, innoextract, cabextract."
    fi
}

download_file() {
    local url="$1"
    local dest="$2"

    log_info "Downloading: $(basename "$dest")"
    log_info "Source URL: ${url}"

    if [ -f "$dest" ] && [ -s "$dest" ]; then
        log_ok "File already exists: $(basename "$dest") (skipping download)"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    if ! $FETCH_CMD "$dest" "$url"; then
        log_err "Download failed for: $url"
        rm -f "$dest"
        return 1
    fi

    log_ok "Successfully downloaded: $(basename "$dest")"
}

extract_package() {
    local installer="$1"
    local out_dir="$2"
    local comp="$3"

    mkdir -p "$out_dir"
    log_info "Extracting $(basename "$installer") -> $(basename "$out_dir")..."

    local extracted=false

    # Strategy 1: innoextract (for InnoSetup installers)
    if [ "$HAVE_INNOEXTRACT" = true ]; then
        if innoextract -q -e -d "$out_dir" "$installer" >/dev/null 2>&1; then
            log_ok "Extracted with innoextract"
            extracted=true
        fi
    fi

    # Strategy 2: 7z extraction (covers SFX, zip, cab, PE resources)
    if [ "$extracted" = false ] && [ "$HAVE_7Z" = true ]; then
        if "$SEVENZ_BIN" x -y -o"$out_dir" "$installer" >/dev/null 2>&1; then
            log_ok "Extracted with 7z"
            extracted=true
        fi
    fi

    # Strategy 3: Nested extraction for sub-archives (.cab, .zip, .exe inside)
    if [ "$extracted" = true ] && [ "$HAVE_7Z" = true ]; then
        find "$out_dir" -type f \( -name "*.cab" -o -name "*.zip" \) | while read -r subarchive; do
            sub_target="${subarchive%.*}"
            mkdir -p "$sub_target"
            "$SEVENZ_BIN" x -y -o"$sub_target" "$subarchive" >/dev/null 2>&1 || true
        done
    fi

    if [ "$extracted" = false ]; then
        log_warn "Standard automatic extraction was not successful for $(basename "$installer")."
        log_warn "Installer preserved at: $installer"
        log_warn "Please extract using 7-Zip, innoextract, or run installer in Wine / Windows sandbox."
    else
        summarize_extracted_content "$out_dir" "$comp"
    fi
}

summarize_extracted_content() {
    local dir="$1"
    local comp="$2"

    log_info "Inspecting key artifacts for component [${comp}]:"
    case "$comp" in
        vga)
            find "$dir" -type f \( -iname "*igdkmd64*.sys" -o -iname "*.inf" -o -iname "*vbt*.bin" \) 2>/dev/null | head -n 10 | while read -r f; do
                echo "   -> $f"
            done
            ;;
        bios)
            find "$dir" -type f \( -iname "*.bin" -o -iname "*.fd" -o -iname "*.rom" -o -iname "*.fl1" -o -iname "*.fl2" \) 2>/dev/null | while read -r f; do
                echo "   -> Firmware binary: $f"
            done
            ;;
        sio|hid|sensor)
            find "$dir" -type f \( -iname "*.sys" -o -iname "*.inf" \) 2>/dev/null | head -n 10 | while read -r f; do
                echo "   -> $f"
            done
            ;;
    esac
}

main() {
    local download_only=false
    local extract_only=false
    local clean_temp=false
    local targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --download-only) download_only=true; shift ;;
            --extract-only) extract_only=true; shift ;;
            --clean) clean_temp=true; shift ;;
            -h|--help) usage; exit 0 ;;
            all|vga|hid|sio|sensor|bios) targets+=("$1"); shift ;;
            *) log_err "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done

    if [ ${#targets[@]} -eq 0 ] || [[ " ${targets[*]} " =~ " all " ]]; then
        targets=("bios" "vga" "hid" "sio" "sensor")
    fi

    check_dependencies
    mkdir -p "$TARGET_DIR" "$WORK_DIR"

    for key in "${targets[@]}"; do
        if [ -z "${DRIVERS[$key]+_}" ]; then
            continue
        fi

        IFS="|" read -r url filename out_subdir <<< "${DRIVERS[$key]}"
        local installer_path="${TARGET_DIR}/${filename}"
        local extract_path="${TARGET_DIR}/${out_subdir}"

        echo "------------------------------------------------------------"
        log_info "Processing component: ${key^^} [${filename}]"

        if [ "$extract_only" = false ]; then
            download_file "$url" "$installer_path"
        fi

        if [ "$download_only" = false ]; then
            if [ -f "$installer_path" ]; then
                extract_package "$installer_path" "$extract_path" "$key"
            else
                log_warn "Installer not found at ${installer_path}; skip extraction."
            fi
        fi
    done

    if [ "$clean_temp" = true ]; then
        log_info "Cleaning work scratchpad..."
        rm -rf "$WORK_DIR"
    fi

    echo "============================================================"
    log_ok "Driver acquisition routine finished."
    log_info "Base drivers directory: ${TARGET_DIR}"
}

main "$@"
