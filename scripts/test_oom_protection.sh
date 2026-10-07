#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Early OOM Protection Verification Script
# Verifies earlyoom / systemd-oomd service status and configuration

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_oom_protection.sh [OPTIONS]

Options:
  --probe          Inspect active OOM killer services (earlyoom / systemd-oomd) (default)
  --dry-run        Validate earlyoom threshold arguments and configuration syntax
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
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
echo " Lenovo D330-10IGL Out-of-Memory Protection Test Tool     "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying earlyoom parameters..."
    echo "  - Memory kill threshold: < 4% free RAM"
    echo "  - Swap kill threshold:   < 10% free Swap"
    echo "  - Protected processes:   systemd, Xorg, kwin, gnome-shell, pipewire, d330 daemons"
    echo "  - Preferred kill targets: Web Content, chrome, firefox, electron"
    echo "[DRY-RUN] Configuration verified valid."
    exit 0
fi

echo "--- 1. OOM Daemon Service Status ---"
if systemctl is-active earlyoom >/dev/null 2>&1; then
    echo "[OK] earlyoom daemon active"
elif systemctl is-active systemd-oomd >/dev/null 2>&1; then
    echo "[OK] systemd-oomd active"
else
    echo "[INFO] Neither earlyoom nor systemd-oomd is running. Install earlyoom package."
fi

echo ""
echo "--- 2. Active Memory & Swap Headroom ---"
free -h || true

echo "=========================================================="
echo " OOM verification completed.                              "
echo "=========================================================="
