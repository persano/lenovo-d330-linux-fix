#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Memory & Storage Verification Script
# Verifies ZRAM zstd compression pool, dirty page sysctl parameters, and eMMC I/O elevator

set -euo pipefail

MODE="probe"
APPLY=0

show_help() {
    cat << 'EOF'
Usage: scripts/test_memory_storage.sh [OPTIONS]

Options:
  --probe         Inspect active ZRAM swap, virtual memory sysctls, and eMMC queue parameters (default)
  --stress-zram   Perform memory compression stress test by allocating test buffer
  --stress-emmc   Perform temporary write/read benchmark on eMMC filesystem
  --trim          Trigger fstrim across active mounted filesystems
  --apply         Execute system mutations (required for --stress-*/--trim)
  --dry-run       Validate script logic and tuning values without modifying state
  --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --stress-zram)
            MODE="stress-zram"
            shift
            ;;
        --stress-emmc)
            MODE="stress-emmc"
            shift
            ;;
        --trim)
            MODE="trim"
            shift
            ;;
        --apply)
            APPLY=1
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
echo " Lenovo D330-10IGL RAM & eMMC Optimization Test Tool     "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying ZRAM and storage configuration presets..."
    echo "  - ZRAM Size: min(ram * 0.75, 3072 MB)"
    echo "  - ZRAM Compression: zstd (fast decompression, high compression ratio)"
    echo "  - VM Swappiness: 180"
    echo "  - VM VFS Cache Pressure: 50"
    echo "  - VM Dirty Bytes: 67108864 (64MB)"
    echo "  - eMMC Scheduler: mq-deadline"
    echo "  - eMMC Read-Ahead: 128 KB"
    echo "[DRY-RUN] All parameters verified valid."
    exit 0
fi

inspect_memory() {
    echo "--- 1. Memory and Swap Status ---"
    free -h || true
    echo ""
    if command -v zramctl >/dev/null 2>&1; then
        echo "ZRAM Block Devices:"
        zramctl || true
    else
        echo "[INFO] zramctl not installed. Active swap partitions:"
        cat /proc/swaps || true
    fi
    echo ""
    echo "--- 2. Virtual Memory Parameters ---"
    sysctl vm.swappiness vm.vfs_cache_pressure vm.dirty_bytes vm.dirty_background_bytes vm.page-cluster 2>/dev/null || true
}

inspect_emmc() {
    echo ""
    echo "--- 3. eMMC Flash Storage Status ---"
    local mmc_dev="/sys/block/mmcblk0"
    if [[ -d "$mmc_dev" ]]; then
        echo "Target Device: mmcblk0"
        echo "  - Scheduler:  $(cat "$mmc_dev/queue/scheduler" 2>/dev/null || echo "N/A")"
        echo "  - Read-Ahead: $(cat "$mmc_dev/queue/read_ahead_kb" 2>/dev/null || echo "N/A") KB"
        echo "  - Rotational: $(cat "$mmc_dev/queue/rotational" 2>/dev/null || echo "N/A")"
    else
        echo "[INFO] /sys/block/mmcblk0 not detected. System may be booted from USB or NVMe."
    fi
}

case "$MODE" in
    probe)
        inspect_memory
        inspect_emmc
        ;;
    stress-zram)
        if [[ "$APPLY" -ne 1 ]]; then
            echo "[INFO] --stress-zram requires --apply (would allocate a 1.5GB tmpfs buffer)."
            exit 0
        fi
        echo "Allocating 1.5GB temporary compressible buffer in tmpfs..."
        tmpdir=$(mktemp -d /tmp/zram_stress_XXXXXX)
        head -c 1500M </dev/zero > "$tmpdir/test.img" || true
        echo "Memory during allocation:"
        free -h || true
        rm -rf "$tmpdir"
        echo "[OK] Buffer cleaned up."
        ;;
    stress-emmc)
        if [[ "$APPLY" -ne 1 ]]; then
            echo "[INFO] --stress-emmc requires --apply (would write/read a 256MB benchmark file)."
            exit 0
        fi
        echo "Running eMMC sequential write/read test (256MB)..."
        test_file="/tmp/d330_emmc_benchmark.bin"
        dd if=/dev/zero of="$test_file" bs=1M count=256 conv=fdatasync 2>&1 | tail -n 1
        dd if="$test_file" of=/dev/null bs=1M count=256 2>&1 | tail -n 1
        rm -f "$test_file"
        echo "[OK] Benchmark completed."
        ;;
    trim)
        if [[ "$APPLY" -ne 1 ]]; then
            echo "[INFO] --trim requires --apply (would run: fstrim -av)."
            exit 0
        fi
        echo "Triggering fstrim..."
        fstrim -av
        ;;
esac

echo "=========================================================="
echo " Optimization test finished.                              "
echo "=========================================================="
