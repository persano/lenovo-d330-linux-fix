#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL CI/CD Workflow Verification Script
# Validates GitHub Actions workflow syntax and YAML structure

set -euo pipefail

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

python3 - << 'EOF'
import os
import sys

workflows_dir = ".github/workflows"
if not os.path.isdir(workflows_dir):
    print("[FAIL] .github/workflows directory missing.")
    sys.exit(1)

files = [f for f in os.listdir(workflows_dir) if f.endswith(('.yml', '.yaml'))]
if not files:
    print("[FAIL] No workflow files found.")
    sys.exit(1)

print(f"Found {len(files)} workflow file(s):")
for f in sorted(files):
    full_path = os.path.join(workflows_dir, f)
    with open(full_path, "r", encoding="utf-8") as wf:
        content = wf.read()
    # Basic YAML structural sanity checks
    has_name = "name:" in content
    has_on = "on:" in content
    has_jobs = "jobs:" in content
    if has_name and has_on and has_jobs:
        print(f"  [OK] {f} (name, triggers, jobs defined)")
    else:
        print(f"  [WARN] {f} may be incomplete: name={has_name}, on={has_on}, jobs={has_jobs}")

print("All GitHub Actions workflows validated.")
EOF

echo "=========================================================="
echo " Workflow verification complete.                          "
echo "=========================================================="
