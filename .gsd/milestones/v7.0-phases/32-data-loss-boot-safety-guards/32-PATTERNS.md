# Phase 32: Data-Loss & Boot Safety Guards - Pattern Map

**Mapped:** 2026-10-07
**Files analyzed:** 3 (1 production file, 1 test file to extend, 1 optional new test file)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tools/d330-microsd-setup.sh` (rewrite) | CLI tool / utility | file-I/O (block-device writes + `/etc/fstab` append), request-response | itself (129 lines) + `scripts/install_dkms.sh` (parser/preflight) | exact (base) + role-match |
| `scripts/test_storage_cellular.sh` (extend) | test | request-response (invoke tool, capture stdout, assert) | itself + `scripts/test_distro_packaging.sh` (assert helper) | exact |
| `scripts/test_microsd_guards.sh` (optional new, Risks #2) | test | request-response + batch assertions | `scripts/test_resume_loop.sh` (pass/fail counter, exit gate) | role-match |

Scope note: production changes are confined to `tools/d330-microsd-setup.sh`; the only other touched file is the test surface.

## Pattern Assignments

### `tools/d330-microsd-setup.sh` (CLI tool, file-I/O + request-response)

**Base analog:** the file itself (keep lines 1-35, 53, 68-84 intact in structure).

**Imports/strict mode + log helpers** (lines 8-19, keep as-is):
```bash
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
```
Discretion: stderr variant exists at `scripts/install_dkms.sh:29` (`log_err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }`), better for new guard errors.

**Help text** (lines 21-35, keep `show_help() { cat <<EOF ... EOF }`; add `--device` row and mark `--mount-home` unsupported).

#### Edit region 1: parser conversion (`--device /dev/...` value)

**Analog:** `scripts/install_dkms.sh:453-464` (majority house pattern, while/shift):
```bash
ACTION="install"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) ACTION="install"; shift ;;
        --uninstall) ACTION="uninstall"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done
```

**Value-consuming option** (`--device X` needs `shift 2`): `scripts/test_resume_loop.sh:38-47` is the only in-repo precedent for a flag with a value:
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cycles) CYCLES="$2"; shift 2 ;;
        -s|--sleep) SLEEP_SECS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done
```
Combine: replace the current `for arg in "$@"` loop (lines 41-51) with while/shift, add `--device) TARGET_DEV="$2"; shift 2 ;;`. Missing-value guard (`$# -lt 2`) and `/dev/...` + `[ -b ]` validation wording at discretion (RESEARCH Security Domain V5). Test both orders (`--format --device X` and `--device X --format`, Pitfall 7).

#### Edit region 2: preflight prerequisite check (new)

**Analog:** `scripts/install_dkms.sh:43-70` (`check_prerequisites`) — root gate first, then `command -v` loop, then actionable `log_err` + `exit 1`:
```bash
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        log_err "Installation requires root privileges. Please run with sudo."
        exit 1
    fi

    local missing=()
    for bin in dkms make gcc; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing+=("$bin")
        fi
    done
    ...
    if [ ${#missing[@]} -gt 0 ]; then
        log_err "Missing required build tools: ${missing[*]}"
        log_err "On Debian/Ubuntu/Mint: sudo apt install dkms build-essential linux-headers-\$(uname -r)"
        exit 1
    fi
```
Copy for `parted partprobe udevadm findmnt lsblk` (RESEARCH open question 4). Keep the existing root gate in `tools/d330-microsd-setup.sh:81-84` semantics: dry-run stays permitted unprivileged, tests depend on it.

#### Edit region 3: pre-write guards before first write

**Fail-fast guard pattern** (existing precedent, `tools/d330-microsd-setup.sh:81-84`):
```bash
if [ "$EUID" -ne 0 ] && [ $DRY_RUN -eq 0 ]; then
    log_err "Root privileges required for disk operations. Run with sudo."
    exit 1
fi
```
Guards (a) `lsblk -nr -o MOUNTPOINT "$TARGET_DEV"` emptiness, (b) bidirectional root prefix, (c) typed `yes` all use this shape: `log_err "..."; exit 1`. Guard (b) bidirectional `case` snippet lives in RESEARCH Linux/Distro Notes §2, quote it verbatim in the plan (Pitfall 1). All guards execute before line 94 (`parted`, the first write), never merely before `mkfs` (Pitfall 3).

**No analog for:** the typed `read` confirmation (no `read -r` confirmation exists anywhere in repo), the `[ -b "$TARGET_DEV" ]` existence precondition before guards (Pitfall 4). Follow RESEARCH verbatim.

#### Edit region 4: dry-run reporting

**Existing dry-run print** (`tools/d330-microsd-setup.sh:90-93`, keep the `[DRY-RUN] <cmd>` shape, drop `-F` from the mkfs line):
```bash
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[DRY-RUN] parted -s $TARGET_DEV mklabel gpt mkpart primary ext4 1MiB 100%"
        log_info "[DRY-RUN] mkfs.ext4 -F -O mmp,dir_index,sparse_super -m 1 -L D330_STORAGE $PART_DEV"
    else
```
**Banner precedent:** `scripts/install_dkms.sh:466-468`:
```bash
if [ "$DRY_RUN" = true ]; then
    log_warn "Operating in DRY-RUN mode. No files will be modified."
fi
```
Phase 32 extends: dry-run runs every read-only guard and prints `PASS`/`FAIL` per guard before the planned commands (locked; wording at discretion).

#### Edit region 5: `parted`/`partprobe` sequencing + partition node derivation

Replace `sleep 1` (line 95) with `partprobe "$TARGET_DEV"; udevadm settle` (RESEARCH §3, lsblk(8) endorsement). Replace `PART_DEV="${TARGET_DEV}p1"` (line 86, Pitfall 8) with post-settle derivation per RESEARCH "Don't Hand-Roll" row 6:
```bash
lsblk -lnpo NAME,TYPE "$TARGET_DEV" | awk '$2=="part"{print $1; exit}'
```
Optional-tool tolerance pattern for the preflight caveat (`tools/d330-fastboot-tune.sh:13-21`):
```bash
    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze || true
    else
        echo "[INFO] systemd-analyze command not available in current environment."
    fi
```

#### Edit region 6: fstab append, rollback trap, success gate

**Rollback trap — partial analog only:** `tools/d330-acpi-override.sh:24-25` is the only `trap` in the repo (cleanup, not rollback):
```bash
WORK_DIR="$(mktemp -d /tmp/d330_acpi_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
```
Use the same trap syntax for the fstab-line rollback (locked decision), but the remove-last-line body, `findmnt --verify --tab-file` pre-append proof, and removal of `mount "$MOUNT_POINT" || true` (line 113, Pitfall 9) follow RESEARCH §6 and Pitfall 9, no in-repo pattern.

**Success gate:** `log_ok "Storage expansion task complete."` (line 129) prints only on genuine success paths; UUID-empty branch (line 118-120) gets an explicit `exit 1`.

#### Edit region 7: `--mount-home` stub

Exit non-zero with "not implemented" message; `--help` row marked unsupported; no completion line. No analog (first intentionally-failing action in repo). Order of checks (missing `--device` vs not implemented): RESEARCH open question 9 recommends not-implemented first, confirm in plan.

---

### `scripts/test_storage_cellular.sh` (test, request-response)

**Analog:** the file itself (structure to preserve).

**Mode parser** (lines 21-45, keep): while/shift with one-token options, `--help|-h) show_help; exit 0`, `*) echo "Unknown option: $1"; show_help; exit 1`.

**Tool invocation, existing** (line 63, keep for the regression criterion):
```bash
        echo "--- 1. MicroSD Storage State ---"
        bash tools/d330-microsd-setup.sh --probe
```
New lines should anchor via `SCRIPT_DIR` instead of cwd: `scripts/test_resume_loop.sh:17-18`:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```
No refactor of existing cwd-relative lines (Phase 41 owns that, RESEARCH Repo Conventions 8).

**Assertion helper — analog:** `scripts/test_distro_packaging.sh:50-64` (`[OK]`/`[FAIL]` + `return 1`, which aborts the run under `set -e`):
```bash
check_file() {
    local file="$1"
    local desc="$2"
    if [[ -f "$file" ]]; then
        echo "  [OK] Found $desc ($file)"
    else
        echo "  [FAIL] Missing $desc at $file"
        return 1
    fi
}
```
Adapt into `check_output`/`expect_rc` style helpers for SC1/SC3/SC4 (`grep -q` assertion style also at `scripts/test_distro_packaging.sh:69-81`).

**Temp file creation — analog:** `scripts/test_memory_storage.sh:111`:
```bash
tmpdir=$(mktemp -d /tmp/zram_stress_XXXXXX)
```
Use for the candidate tab file and generated `data.mount` unit (SC2); never touch the real `/etc/fstab` in tests (RESEARCH Test Strategy 4).

**Optional tool gate — analog:** `scripts/test_storage_cellular.sh:70` (`if command -v mmcli >/dev/null 2>&1; then`), same shape for `systemd-analyze` presence in SC2.

---

### `scripts/test_microsd_guards.sh` (test, batch assertions) — optional new file

Only needed if the planner picks a new file over extending the existing harness (RESEARCH Risks #2).

**Analog:** `scripts/test_resume_loop.sh` — full script is the template: usage/while-shift header (lines 25-47), banner (55-60), pass/fail counters (62-63), per-case `[FAIL]` + `((failed++))` + `continue` (81-85), summary and non-zero exit gate (117-126):
```bash
passed=0
failed=0
...
    if ! rtcwake -m mem -s "$WAKE_SECS" >> "$LOG_FILE" 2>&1; then
        echo "    [FAIL] rtcwake returned error exit code!" | tee -a "$LOG_FILE"
        ((failed++))
        continue
    fi
...
if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
```
This is the only failure-counting test in the repo (everything else is always-green, Phase 41 item) and matches the phase's need to actually assert SC1-SC3.

---

## Shared Patterns

### Strict mode
**Source:** every `tools/*.sh` and `scripts/*.sh` line 1-ish — `tools/d330-microsd-setup.sh:8`, `scripts/install_dkms.sh:9`, `scripts/test_storage_cellular.sh:5`.
**Apply to:** all touched files.
```bash
set -euo pipefail
```

### Colour log helpers + fail fast
**Source:** `tools/d330-microsd-setup.sh:16-19` (keep), stderr variant `scripts/install_dkms.sh:29`.
**Apply to:** every new guard in the tool, every assertion message in tests.
```bash
log_err()  { echo -e "${RED}[ERR]${NC}  $*"; }
# guard:
log_err "refusing: ..."; exit 1
```

### Option parsing (`while`/`shift`)
**Source:** `scripts/install_dkms.sh:456-464` (no value), `scripts/test_resume_loop.sh:38-47` (with value, `shift 2`).
**Apply to:** tool parser conversion; any new test mode flags.

### Dry-run
**Source:** `tools/d330-microsd-setup.sh:90-93` (`[DRY-RUN] <cmd>`), banner `scripts/install_dkms.sh:466-468`.
**Apply to:** format and mount-data branches; extended with per-guard PASS/FAIL output.

### Optional-tool tolerance
**Source:** `tools/d330-fastboot-tune.sh:13-21`, `scripts/install_dkms.sh:52`.
**Apply to:** preflight for `partprobe`/`udevadm`, test-side `systemd-analyze` gate.
```bash
if command -v systemd-analyze >/dev/null 2>&1; then ...
else echo "[INFO] ... not available in current environment."; fi
```

### Test assertions
**Source:** `scripts/test_distro_packaging.sh:50-64` (helper, fail-fast), `scripts/test_resume_loop.sh:62-63,123-125` (counter + exit gate).
**Apply to:** all new SC1-SC4 assertions in the test surface.

### Cleanup trap
**Source:** `tools/d330-acpi-override.sh:24-25`.
**Apply to:** fstab rollback trap (syntax only; rollback body from RESEARCH Pitfall 9).
```bash
WORK_DIR="$(mktemp -d /tmp/d330_acpi_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
```

### Help text
**Source:** `tools/d330-microsd-setup.sh:21-35`, `scripts/test_storage_cellular.sh:9-19`.
**Apply to:** tool `--help` update (add `--device`, mark `--mount-home` unsupported).

## No Analog Found

Files/patterns with no close match (planner should follow RESEARCH.md verbatim):

| File / Pattern | Role | Data Flow | Reason |
|------|------|-----------|--------|
| PATH-shim fixture (fake `lsblk`/`findmnt`/`parted`/`mkfs.ext4`/`blkid`/`mount` in temp dir) | test fixture | request-response mocking | First shim-based test in this repo (A6, Test Strategy 2) |
| Typed `yes` confirmation guard (c) | guard | request-response | No `read -r` confirmation anywhere in repo |
| `findmnt --verify --tab-file` / `systemd-analyze verify ./data.mount` | test assertion | file-I/O validation | No usage in repo; semantics from RESEARCH §5-6 (Pitfall 5: exit code alone is false-green) |
| fstab rollback trap body | tool | file-I/O undo | Only trap in repo is cleanup at `d330-acpi-override.sh:25` |
| `--mount-home` always-failing stub | CLI tool | request-response | First intentional non-zero action in repo |
| Loop-device integration fixture (root-only) | test fixture | file-I/O | No `losetup` precedent; optional/manual tier |

## Metadata

**Analog search scope:** `tools/*.sh`, `scripts/*.sh` (repo-wide grep for `trap`, `read -r`, `findmnt --verify`, `systemd-analyze verify`, `mktemp`, `while [[ $# -gt 0 ]]`, `command -v`, `[FAIL]`)
**Files scanned:** 40 shell scripts (9 in `tools/`, 31 in `scripts/`; greps limited to `*.sh`)
**Pattern extraction date:** 2026-10-07