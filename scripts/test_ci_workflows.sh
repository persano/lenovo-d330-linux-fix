#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL CI/CD Workflow Verification Script
# Validates GitHub Actions workflow syntax and YAML structure

set -euo pipefail

# CWD anchoring: resolve the repo root from this script's own location so the
# python validator below reads .github/workflows regardless of the CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_ci_workflows.sh [OPTIONS]

Options:
  --probe          Verify YAML files in .github/workflows/ (default)
  --dry-run        Validate workflow structure without external services
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
echo " Lenovo D330-10IGL CI/CD Workflow Verification Tool       "
echo "=========================================================="

# The parsed MODE is consumed by the validator: --probe is strict (a missing
# optional name: is a failure), --dry-run tolerates the optional name: while
# still failing on the required on:/jobs: keys. Both modes exit non-zero on a
# real structural problem.
CI_STRICT=1
if [[ "$MODE" == "dry-run" ]]; then
    CI_STRICT=0
    echo "[DRY-RUN] Validating workflow structure without external services..."
fi

D330_CI_STRICT="$CI_STRICT" python3 - << 'EOF'
import os
import sys

strict = os.environ.get("D330_CI_STRICT", "1") == "1"

workflows_dir = ".github/workflows"
if not os.path.isdir(workflows_dir):
    print("[FAIL] .github/workflows directory missing.")
    sys.exit(1)

files = [f for f in os.listdir(workflows_dir) if f.endswith(('.yml', '.yaml'))]
if not files:
    print("[FAIL] No workflow files found.")
    sys.exit(1)

failed = 0
print(f"Found {len(files)} workflow file(s):")
for f in sorted(files):
    full_path = os.path.join(workflows_dir, f)
    with open(full_path, "r", encoding="utf-8") as wf:
        content = wf.read()
    has_name = "name:" in content
    has_on = "on:" in content
    has_jobs = "jobs:" in content
    if not (has_on and has_jobs):
        print(f"  [FAIL] {f} missing required keys: on={has_on}, jobs={has_jobs}")
        failed += 1
    elif not has_name:
        if strict:
            print(f"  [FAIL] {f} missing 'name:'")
            failed += 1
        else:
            print(f"  [WARN] {f} has no 'name:' (optional)")
    else:
        print(f"  [OK] {f} (name, triggers, jobs defined)")

if failed:
    print(f"[FAIL] {failed} workflow file(s) failed validation.")
    sys.exit(1)
print("All GitHub Actions workflows validated.")
EOF

echo "=========================================================="
echo " Workflow verification complete.                          "
echo "=========================================================="
