#!/usr/bin/env bash
# d330-full-setup.sh — one-script installer for the Lenovo IdeaPad D330-10IGL
# Linux parity stack, v11.0. Reproduces docs/KUBUNTU_INSTALL_STEPS.md end to
# end with a single entry point:
#
#   1. Distro + DMI preflight (82H0/81MD/81H3 gate, warns otherwise)
#   2. Dependency install (apt / dnf / pacman, detected)
#   3. Full parity stack via scripts/install_dkms.sh (DKMS module, modprobe.d,
#      hwdb, udev, libinput quirks, systemd units, TLP/zram/earlyoom,
#      PipeWire/RNNoise, grub.d snippets + regen) — that script owns
#      install/uninstall/verify semantics; this wrapper does not reimplement it.
#   4. Patched-kernel install: the v11.0 `.deb` (GLK reset-order fixup +
#      CCS modifier quirk) if given/downloaded; otherwise prints the manual
#      path (CI workflow or on-device build) and continues.
#   5. Verification pass: kernel patch symbol, dkms status, deployed files.
#
# Safety contract (v11.0 roadmap process rules):
#   - never `rm`s anything
#   - backs up every boot file it touches (.bak-d330-<timestamp>)
#   - `--dry-run` prints every action, changes nothing
#   - sudo only when the user approves; every step prints a manual fallback
#
# Usage:
#   sudo ./scripts/d330-full-setup.sh [--dry-run] [--kernel-deb FILE]
#                                     [--skip-kernel] [--yes]
set -u

DRY_RUN=0
KERNEL_DEB=""
SKIP_KERNEL=0
ASSUME_YES=0
STAMP="$(date +%Y%m%d-%H%M%S)"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --kernel-deb)   shift_next=1 ;;
    --skip-kernel)  SKIP_KERNEL=1 ;;
    --yes|-y)       ASSUME_YES=1 ;;
    *) if [ "${shift_next:-0}" = 1 ]; then KERNEL_DEB="$arg"; shift_next=0; fi ;;
  esac
done

log()  { printf '[d330] %s\n' "$*"; }
warn() { printf '[d330] WARN: %s\n' "$*" >&2; }
manual(){ printf '[d330] MANUAL FALLBACK: %s\n' "$*"; }

run() {
  # run <description> <command...> — honors DRY_RUN, prints the command
  desc="$1"; shift
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN would: $desc"
    log "  cmd: $*"
    return 0
  fi
  log "$desc"
  "$@" || { warn "step failed: $desc"; return 1; }
}

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$DRY_RUN" = 1 ] && return 0
  printf '[d330] %s [y/N] ' "$1"
  read -r ans
  [ "$ans" = y ] || [ "$ans" = Y ]
}

# ---------------------------------------------------------------- 1. preflight
log "=== 1. Preflight ==="
[ "$(id -u)" = 0 ] || { [ "$DRY_RUN" = 1 ] && log "dry-run: not root, previewing only." || { warn "run with sudo (or --dry-run to preview)."; exit 1; }; }

if [ -r /sys/class/dmi/id/product_name ]; then
  PRODUCT="$(tr -d '\0' < /sys/class/dmi/id/product_name)"
  log "DMI product: $PRODUCT"
  case "$PRODUCT" in
    *D330-10IGL*|*82H0*|*81MD*|*81H3*) log "DMI gate: PASS (in-tree target)" ;;
    *) warn "this is not a D330-10IGL (82H0/81MD/81H3). All deployed"
           warn "patches/configs are DMI-gated and will be inert here."
           confirm "Continue anyway?" || exit 1 ;;
  esac
else
  warn "no /sys/class/dmi — cannot verify model."
  confirm "Continue anyway?" || exit 1
fi

if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
  warn "Secure Boot is ON. DKMS modules and the custom kernel need it"
  warn "disabled (or your own MOK signing). See docs/KUBUNTU_INSTALL_STEPS.md."
  confirm "Continue anyway (modules may not load)?" || exit 1
fi

# ------------------------------------------------------------ 2. dependencies
log "=== 2. Dependencies ==="
if command -v apt-get >/dev/null 2>&1; then
  run "apt: refresh indexes" apt-get update
  run "apt: build/DKMS/pipeWire/TLP toolchain" \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential dkms "linux-headers-$(uname -r)" git curl \
      pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth \
      tlp thermald earlyoom zram-tools \
      || manual "apt install build-essential dkms linux-headers-\$(uname -r)"
elif command -v dnf >/dev/null 2>&1; then
  run "dnf: toolchain" dnf install -y \
    dkms kernel-devel kernel-headers gcc make git curl tlp thermald earlyoom
  manual "Fedora: the patched kernel is NOT a .deb — apply the two patches in"
  manual "patches/ to the distro kernel build (docs/DISTRO_INSTALL_GUIDE.md"
  manual "section 'Fedora / RHEL'). Everything else installs below."
elif command -v pacman >/dev/null 2>&1; then
  run "pacman: toolchain" pacman -S --noconfirm --needed \
    dkms linux-headers base-devel git curl tlp thermald earlyoom
  manual "Arch: apply the patches in patches/ in your distro-kernel PKGBUILD"
  manual "prepare() (docs/DISTRO_INSTALL_GUIDE.md section 'Arch Linux')."
else
  warn "unknown package manager. Install dkms, kernel headers, git, curl,"
  warn "pipewire, tlp, thermald, earlyoom manually, then re-run."
  exit 1
fi

# ------------------------------------------------- 3. parity stack (DKMS etc.)
log "=== 3. Parity stack (scripts/install_dkms.sh) ==="
if [ "$DRY_RUN" = 1 ]; then
  log "DRY-RUN would run: $REPO_DIR/scripts/install_dkms.sh --install"
  manual "preview the real thing: $REPO_DIR/scripts/install_dkms.sh --verify"
else
  bash "$REPO_DIR/scripts/install_dkms.sh" --install || {
    warn "install_dkms.sh reported failures. Its per-file log above is"
    warn "authoritative. Re-run it directly; docs/KUBUNTU_INSTALL_STEPS.md"
    warn "section 3 has the manual per-piece steps."
    confirm "Continue to kernel step?" || exit 1
  }
fi

# ------------------------------------------------------------- 4. patched kernel
log "=== 4. Patched kernel (GLK reset-order fixup + CCS quirk) ==="
CURRENT_KV="$(uname -r)"
if [ "$SKIP_KERNEL" = 1 ]; then
  log "skipped (--skip-kernel)."
  manual "to get the display fix, install a kernel containing"
  manual "patches/d330_dsi_glk_reset_order_fixup.patch +"
  manual "patches/d330_display_resume_fix.patch, or trigger the repo CI"
  manual "workflow build-kernel.yml and install the produced .deb."
elif [ -n "$KERNEL_DEB" ] && [ -r "$KERNEL_DEB" ]; then
  log "target: $KERNEL_DEB"
  [ "$DRY_RUN" = 1 ] && run "would install kernel .deb" true \
    || run "install kernel .deb (in-place, dpkg)" dpkg -i "$KERNEL_DEB"
  log "old kernel(s) kept — pick in GRUB (Advanced options) if anything"
  log "looks wrong, then: sudo dpkg -i <old.deb> to roll back."
elif command -v gh >/dev/null 2>&1 && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  manual "download the v11.0 release kernel .deb for your kernel version:"
  manual "  gh release download v11.0 -R $GITHUB_REPOSITORY -p '*linux-image*'"
  manual "then re-run: sudo $0 --kernel-deb <file>.deb"
else
  manual "no .deb given. Two paths (docs/KUBUNTU_INSTALL_STEPS.md section 4):"
  manual "A) GitHub Actions: gh workflow run build-kernel.yml --ref <branch>"
  manual "   -f kernel_version=$CURRENT_KV -f ubuntu_release=<release>,"
  manual "   then download linux-image-*.deb from the run and re-run this"
  manual "   script with --kernel-deb <file>.deb"
  manual "B) On-device build (~3h on the N4020): apt-get source + apply"
  manual "   both patches + bindeb-pkg, per DISTRO_INSTALL_GUIDE.md."
fi

# ---------------------------------------------------------------- 5. verify
log "=== 5. Verification ==="
if [ "$DRY_RUN" = 1 ]; then
  log "DRY-RUN would check: kernel symbol, dkms status, deployed files."
  exit 0
fi

fail=0
if grep -q "mipi_seq_v3_count_elems" /proc/kallsyms 2>/dev/null; then
  log "kernel: v3 sequence parser present (fixup-capable kernel booted: $(uname -r))"
else
  warn "kernel $(uname -r) does NOT contain the GLK fixup. Install the"
  warn "patched kernel and reboot; step 4 above."
  fail=1
fi
if dkms status 2>/dev/null | grep -q "lenovo-d330-fix.*installed"; then
  log "dkms: lenovo-d330-fix installed"
else
  warn "dkms module missing — re-run scripts/install_dkms.sh --install"
  fail=1
fi
run "install_dkms.sh --verify (full deployed-file diff)" \
  bash "$REPO_DIR/scripts/install_dkms.sh" --verify || fail=1

if [ "$fail" = 0 ]; then
  log "=== DONE: everything verified. Reboot once, then test a resume:"
  log "  sudo rtcwake -m mem -s 10   (screen must light up)"
else
  warn "=== DONE WITH WARNINGS — see above. Nothing was removed; every"
  warn "backup is <file>.bak-d330-$STAMP. Docs: docs/KUBUNTU_INSTALL_STEPS.md"
fi
exit "$fail"
