# Stack Research — Reverse-Engineering & Fix Toolchain for the D330 Resume Black Screen

**Domain:** Linux kernel display-driver reverse engineering (i915 / Gemini Lake DSI resume) with native-binary RE, agent-driven, Windows host + Linux tablet target
**Milestone:** v8.0 (subsequent milestone: fix an open bug in a mature shell+Python+packaging+DKMS repo)
**Researched:** 2026-10-12
**Confidence:** HIGH for the REA/Ghidra toolchain (verified against upstream docs and local host), MEDIUM for the kernel bisect/rollback workflow (standard tooling, one automated-bisect subtlety flagged), LOW for the "is GLK DSI resume a fixed mainline regression" question (streams blocked; see Gaps).

---

## Scope of This Document

This is a **delta** stack. It lists only capabilities the project does **not** already have.

**Do NOT re-research or re-add (already validated in v1–v7):**

- Shell + Python project; `scripts/install_dkms.sh`; DKMS module `patches/dkms/lenovo-d330-fix`.
- `patches/d330_display_resume_fix.patch` (CCS + 90/270 rotation rejection in `skl_plane_check_fb`).
- `tools/analyze_igdkmd64.py`, `tools/ghidra_export_power_callbacks.py`, `tools/compare_pps_timings.py`.
- On-device `pr_err` marker tracing; `intel_reg`; `rtcwake -m mem`; `scripts/d330-display-reload.sh`.
- Test kernel Ubuntu `7.0.0-38-generic` (clean CI build tag `7.0.14-d330-fix`); 36-script test harness.

The **only new things** needed are: (1) REA + Ghidra wired into opencode for native-binary RE, (2) a reversible i915 module / test-kernel build-and-install workflow, (3) kernel-version bisect tooling, (4) cheaper on-device instrumentation than `pr_err` rebuilds.

---

## Recommended Stack

### Core Technologies (NEW)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **REA** (`rea-agents`) | **6.4.0** (npm, 2026-10-11) | MCP server that drives Ghidra/Hopper/IDA + firmware + process capture from the agent | Purpose-built agent↔RE-decoder bridge; the milestone names it; supports an **OpenCode** client and an **experimental Windows Ghidra P0** path that fits this Windows host. Analysis runs locally. |
| **Ghidra** *(NSA)* | **12.1.4** (`ghidra_12.1.4_PUBLIC_20260921.zip`) | Decompiler/disassembler backend | The engine REA requires; free; headless; verified pairing with REA for PE/ELF. REA accepts Ghidra **12.1.x** and is verified with 12.1.4. |
| **Microsoft OpenJDK** | **21.0.12.101-hotspot** (already installed) | Ghidra runtime + `javac` for REA `doctor` | Ghidra 12.1.x requires **JDK 21+** (no max). REA doctor checks for a 64-bit full JDK including `javac.exe`. Host already satisfies this. |
| **Node.js** | **26.5.1** (already installed) | REA engine | REA engines: `^22.19.0 || ^24.11.0 || >=26.0.0`. Node 26.5.1 is in range. No version work needed. |
| **WSL2 Ubuntu** (already installed) | Distro default | Linux-only REA lanes: firmware extraction, process capture, source import | REA's firmware (`binwalk`/`unblob`), process-capture and historical-source lanes are **Linux/macOS only**; Windows returns `unsupported_host`. Use WSL for those, Windows REA for PE. |
| **Binwalk / Unblob** | Binwalk **3.1.x**, Unblob **26.6.x** (verified 3.1.0 / 26.6.4) | Split `bios.bin` into regions and extract the GOP/VBT/DSI blobs | REA's firmware lane is verified on **Linux x64** with exactly these; caller-supplied (REA does not install them). Replaces/extends the ad-hoc `uefi_firmware` + carving used so far. |
| **Kernel build toolchain** (on tablet) | Ubuntu `build-essential`, `libelf-dev`, `libssl-dev`, `flex`, `bison`, `bc`, `dwarves` (pahole), `zstd`, `rsync`, `cpio` | Build i915 as a module and as a `bindeb-pkg` test kernel | The standard, revertible way to ship a patched i915 without overwriting the distro module by hand. |
| **git** (already installed) | 2.55.0 | Kernel version testing / `git bisect` | Standard regression tool; also fetches mainline + `drm-tip` + `drm-intel-next`. |

### Supporting / On-Device Instrumentation (NEW)

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| **`CONFIG_DRM_USE_DYNAMIC_DEBUG=y` + `dyndbg`** | kernel Kconfig | Makes `drm_dbg_kms()`/`drm_dbg_*` actually emit | **Fixes the documented dead end** where `/sys/module/drm/parameters/debug` is accepted but no `[drm:...]` lines land and `vlv_dsi` has 0 dynamic-debug sites. Replaces many `pr_err` rebuilds. |
| **`CONFIG_DRM_I915_DEBUG=y`** (+`_DEBUG_GEM`, `_WERROR`) | kernel Kconfig | Verbose i915 checks, atomic-state sanity, WARN on invariant breaks | Build the **test kernel** with these; catch a state-machine break the plain module hides. |
| **`bpftrace` / `perf probe` (kprobes)** | bpftrace 0.20+; perf (linux-tools) | Trace i915 functions (e.g. `intel_dsi_pre_enable`, `bxt_dsi_*`) **without rebuilding the module** | Fast replacement for `pr_err` markers; needs `CONFIG_KPROBES`/`KPROBE_EVENTS` (Ubuntu generic enables these). |
| **ftrace i915 tracepoints** | kernel (`events/i915/*`) | `i915_reg_rw`, `intel_pipe_enable/disable`, frontbuffer events with pid+timestamp | Already partially used (`i915_reg_rw`); keep it — it shows the **thread** that writes each register, which `pr_err` cannot. |
| **`intel-gpu-tools` (i-g-t)** | distro package (1.27+) | `intel_reg` (already used) + `i915_pciid` | Raw MMIO; already the project's tool — keep version matched to the distro. |
| **`drm_info`** | distro package | Dump the atomic CRTC/encoder/connector/DSI state as text | One-command cold-vs-resume atomic-state diff at userspace level (complements `i915_display_info`). |
| **debugfs `i915_display_info`** | kernel | Full CRTC/plane/encoder/connector/DSI dump | Read it on a black resume **and** after a working reload; if identical, it confirms "host config identical" objectively. |
| **`CONFIG_DRM_I915_CAPTURE_ERROR`** → `/sys/class/drm/card0/error` | kernel | GPU/display error capture (devcoredump) | If the display engine actually hung, this is the only place the hang state is recorded. |
| **`CONFIG_PSTORE` + `ramoops`** | kernel | Persist dmesg/oops across a failed resume or hang | When the box hangs or reboots on resume, `/sys/fs/pstore/` survives where a normal dmesg does not. |
| **`/sys/power/pm_test`, `CONFIG_PM_TRACE`** | kernel | Bisect the *device* that breaks suspend/resume (`pm_trace` freezes and reports the last device) | Narrow whether the failure is really in the i915 device vs a different late device. |
| **`kexec-tools`** | distro package | Load a test kernel without a firmware/POST round trip | Speeds bisect/rebuild cycles — **caveat**: no UEFI GOP re-run, so display state differs from a cold boot; never use it as proof of a *cold-boot* fix. |
| **`mainline` CLI / Ubuntu mainline PPA** | distro `mainline` package | Install/remove official mainline kernels cleanly | Coarse good/bad boundary before a costly `git bisect`. |

### Integration / Dev Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **opencode MCP** (V1 `mcp` block, already present) | Host for REA; agent = GLM 5.3 Flash | `opencode.json` already has `mcp.serena`; REA adds `mcp.rea`. Model line already defined: `openrouter/z-ai/glm-5.3-flash`. |
| **`rea doctor` / `rea providers`** | Read-only readiness for Ghidra/adapter | `rea doctor --provider ghidra --json`, `rea doctor --client opencode --json`. |

---

## Integration 1 — REA + Ghidra on this Windows host, driven by opencode/GLM 5.3 Flash

### Why this shape

- REA already exists as an MCP server; the work is **configuration**, not code. `npx rea-agents setup` registers the server and installs the matching agent workflow. Do not hand-roll an MCP wrapper.
- The target (host) is **Windows x64**. REA's mature native path is Linux/macOS with Hopper/Ghidra/IDA; on Windows the supported path is the **experimental Ghidra P0 boundary**: x86/x86-64 **PE applications and DLLs** on a fixed local NTFS volume, with **25 read-only** Ghidra operations. That covers `igdkmd64.sys` (PE32+ kernel DLL). It is read-only — no rename/comment mutation on Windows.
- `IntelGopDriver` is an **EFI** image. REA P0 admits "explicit native, non-managed x86/x86-64 PE application or DLL"; an EFI-subsystem image may fail role admission. Plan the fallback (Linux WSL + Ghidra, or the existing capstone/`uefi_firmware` path) rather than assuming P0 accepts it.

### Steps (PowerShell, Windows)

```powershell
# 1. Ghidra 12.1.4 (once). Verify sha256 = ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db
#    https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip
Expand-Archive .\ghidra_12.1.4_PUBLIC_20260921.zip -DestinationPath C:\tools
# JDK 21 is already installed (Microsoft OpenJDK 21.0.12); point REA at it.

# 2. REA 6.4.0
npm install --global rea-agents            # or: npx rea-agents@latest setup

# 3. Provider environment (per shell that runs REA / the MCP server)
$env:GHIDRA_INSTALL_DIR = "C:\tools\ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME         = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot"
$env:REA_ANALYSIS_PROVIDER = "ghidra"
$env:REA_GHIDRA_STARTUP_TIMEOUT_MS = "600000"   # cold import of a big driver; default 330000 ms
$env:GHIDRA_HEADLESS_MAXMEM = "4G"              # 2G default may be tight; accepted values like 512M/4G

# 4. Verify, then register the agent
rea doctor --json
rea providers --json
rea setup --client opencode --dry-run --json    # review the plan
rea setup --client opencode --yes  --json       # approve
```

### opencode registration (what the plan writes / what to keep)

REA writes an OpenCode **V1 `mcp.rea`** entry (loaded by OpenCode V1 and V2). It resolves the user config from `OPENCODE_CONFIG_DIR`/`OPENCODE_CONFIG`. **REA configures user scope only** — this repo's `opencode.json` is project scope, so the entry lands in the user config, not the repo file. The effective shape (project or user) is:

```jsonc
"mcp": {
  "rea": {
    "type": "local",
    "command": ["npx", "-y", "rea-agents@6.4.0", "mcp"],
    "enabled": true,
    "environment": {
      "REA_ANALYSIS_PROVIDER": "ghidra",
      "GHIDRA_INSTALL_DIR": "C:\\tools\\ghidra_12.1.4_PUBLIC",
      "JAVA_HOME": "C:\\Program Files\\Microsoft\\jdk-21.0.12.101-hotspot",
      "REA_GHIDRA_STARTUP_TIMEOUT_MS": "600000",
      "GHIDRA_HEADLESS_MAXMEM": "4G"
    }
  }
}
```

### Driving it with GLM 5.3 Flash (opencode)

- `opencode.json` already defines `openrouter/z-ai/glm-5.3-flash` (256k ctx / 16k out). Set `"model": "openrouter/z-ai/glm-5.3-flash"` to drive REA with it; this is a config line, no new tooling.
- **Response-size trap:** `opencode.json` sets `tool_output.max_bytes: 65536`. REA native results (pseudocode/xrefs/dossiers) routinely exceed this. Prefer the **save-then-project** pattern rather than raising the cap blindly:
  ```bash
  rea analyze  <target> --provider ghidra --json > evidence.json
  jq -c '{source:{kind:"inline",evidence:.},view:{kind:"summary"}}' evidence.json > view.json
  rea inspect-analysis-view view.json
  ```
  Or pass `provider_id: "ghidra"` on `open_binary` in MCP and rely on `REA_MCP_MAX_RESPONSE_BYTES` / snapshots (`--snapshot`) to cache exact results.
- **Staging path rule:** REA rejects UNC, `subst`, reparse points and non-NTFS targets. Put `igdkmd64.sys` and extracted firmware under a **plain local path** (e.g. `D:\re\igdkmd64.sys` or `%LOCALAPPDATA%\Temp\opencode\...`). **Do not** stage targets under `.planning/` — it is a **junction to `.gsd`** on this repo.

### Useful REA operations for this bug

`rea analyze` (overview), `rea search <target> "<string>"`, `rea function <target> <name|addr>`, `rea decompile`, `rea instructions`, `rea xrefs`, `rea trace` — all `--provider ghidra --json`. For `igdkmd64.sys`, seed the WDDM DDIs already known from `tools/analyze_igdkmd64.py` (`DxgkDdiSetPowerState`, `DxgkDdiStartDevice`, `DxgkCbCompletePowerTransition`, …) via `REA_GHIDRA_SEED_FILE` when auto-analysis cannot reach computed callbacks.

---

## Integration 2 — Incremental i915 build + install + rollback (on the tablet)

Two lanes. **Never overwrite the distro's `i915.ko.zst` without a kept backup and a bootable fallback.**

### Lane A — fast iteration (patched i915 module, current test kernel)

```bash
cd ~/d330-kernel/linux-7.0.0                 # must match `uname -r` build tree
# one-time backup of the stock module for the running kernel
sudo cp /lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst \
        /root/i915.ko.zst.stock-7.0.0-38

make -j4 M=drivers/gpu/drm/i915 modules
modinfo drivers/gpu/drm/i915/i915.ko | grep vermagic   # MUST show 7.0.0-38-generic + matching SMP/preempt
strip --strip-debug drivers/gpu/drm/i915/i915.ko
zstd -19 -f drivers/gpu/drm/i915/i915.ko \
     -o /lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst
sudo depmod -a 7.0.0-38-generic
sudo update-initramfs -u -k 7.0.0-38-generic
sudo reboot
```

Restore: `sudo cp /root/i915.ko.zst.stock-7.0.0-38 /lib/modules/.../i915.ko.zst && sudo depmod -a && sudo update-initramfs -u -k 7.0.0-38-generic`.

### Lane B — safe, revertible test kernel via `bindeb-pkg` (recommended default)

```bash
cp /boot/config-$(uname -r) .config
scripts/config --enable DRM_USE_DYNAMIC_DEBUG --enable DRM_I915_DEBUG \
               --enable DRM_I915_DEBUG_GEM --enable DRM_I915_WERROR \
               --enable PSTORE --enable PSTORE_RAM
make olddefconfig
make -j$(nproc) bindeb-pkg LOCALVERSION=-d330-fix
sudo dpkg -i ../linux-image-*-d330-fix_*.deb ../linux-headers-*-d330-fix_*.deb
# new GRUB entry appears; make it one-shot (does NOT change the default):
sudo grub-reboot "$(grep -m1 -o 'Ubuntu, with Linux .*d330-fix' /boot/grub/grub.cfg)"
```

- Rollback = just boot the untouched distro entry (the stock kernel is never modified), or `sudo apt purge 'linux-image-*-d330-fix'`.
- This is safer than Lane A because the stock kernel stays bootable and the patched kernel is a first-class package with its own initramfs and GRUB entry.
- **Do not** move the i915 patch into yet another DKMS. DKMS is already used for the out-of-tree `lenovo-d330-fix` module; patching a **core** module through DKMS is fragile and duplicates the build lane. Keep the i915 work as a dev/test-kernel lane.

---

## Integration 3 — Kernel version testing & bisect (is GLK DSI resume a fixed regression?)

Order of attack (cheap → expensive):

1. **Coarse boundary first:** install a few official kernels via the `mainline` CLI / Ubuntu mainline PPA (`kernel.ubuntu.com/mainline/`), test `rtcwake -m mem` resume on each. This finds a good/bad pair without any build.
2. **Coarse branch check:** test `drm-tip` (`git://anongit.freedesktop.org/drm/drm-tip`) and `drm-intel-next` — newest i915 first, to see if it is already fixed.
3. **`git bisect`** over the narrowed window:
   ```bash
   git clone --filter=blob:none https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
   cd linux && git bisect start <bad> <good>
   # per step: build i915 (M=drivers/gpu/drm/i915) or the test kernel, install, reboot, test resume
   ```
   Speed helpers: `make localmodconfig` (or `olddefconfig` from the distro config), `git worktree` for parallel builds, `ccache`.

### Bisect automation caveat (MEDIUM confidence — design around it)

`git bisect run <script>` **cannot survive a reboot**, and this test *requires* a reboot + suspend/resume per step. Options, in order of preference:

- **Manual bisect** with a per-step checklist (simplest, slow).
- **Self-resuming harness:** a boot `systemd` oneshot that (a) reads a "pending bisect step" file, (b) runs the resume test, (c) writes pass/fail, then the outer controller (SSH from the Windows PC over the tablet's network) drives `git bisect good/bad` and the next build. The tablet is the only machine that reboots.
- **`kexec`** to skip firmware POST between steps (faster) — see caveat above; never treat a kexec result as a cold-boot result.

### Objective pass/fail signal (replaces "watch the panel")

There is no host register that distinguishes a lit panel from a black one, so the test must observe the panel *externally*:

- **Compositor screenshot luminance** after resume (once the compositor is up): `grim /tmp/resume.png; magick /tmp/resume.png -colorspace Gray -format "%[fx:mean]" info:` — mean ≈ 0 ⇒ black. This is the cheapest automatable signal and needs no extra hardware.
- **USB webcam aimed at the panel** (`fswebcam`) — independent of the GPU, robust to a dead compositor. Use if the screenshot path is unreliable.

---

## Integration 4 — On-device instrumentation beyond `pr_err` markers

Ranked by payoff for this specific "host config identical but panel dark" bug:

1. **Turn drm debug back on properly.** The repo's finding that `dynamic_debug/control` has 0 `vlv_dsi` sites and `drm.debug` lands nothing is a **build-config** artifact, not a dead end: build the test kernel with **`CONFIG_DRM_USE_DYNAMIC_DEBUG=y`**, then `dyndbg="module i915 +p"` on the cmdline (or `echo -n 'module i915 +p' > /sys/kernel/debug/dynamic_debug/control`). This should make `drm_dbg_kms()` visible everywhere, including `vlv_dsi.c`, without bespoke `pr_err`s.
2. **kprobes (`bpftrace`/`perf probe`)** — trace `intel_dsi_pre_enable`, `intel_dsi_vbt_exec_sequence`, `bxt_gpio_set_value`, `glk_dsi_enable_io` **live, no rebuild**, with arguments and timestamps. This is the biggest time saver over the current `pr_err` rebuild loop.
3. **ftrace `events/i915/*`** — extend the existing `i915_reg_rw` filter; add `intel_pipe_enable`/`intel_pipe_disable` and frontbuffer events. Keeps the **issuing thread/pid**, which is central to the "resume vs compositor-commit" split already observed.
4. **debugfs `i915_display_info`** on black-resume vs working-reload, plus **`drm_info`** at userspace — objective "identical host state" evidence.
5. **devcoredump `/sys/class/drm/card0/error`** — only if a display-engine hang is ever suspected.
6. **`ramoops`/pstore** — when resume hangs/reboots; capture the last dmesg across the failure.
7. **`pm_test` / `pm_trace`** — rule out a non-GPU device breaking the resume.
8. **`netconsole`/`kgdboc`** — last resort for a fully hung box (netconsole first; it does not need a debugger).
9. **DSI bus capture** — a real MIPI-DSI protocol analyzer (not a cheap 4-ch logic analyzer; DSI HS is hundreds of Mbps/lane). **Not recommended** at this stage: cost/effort is high and the project's evidence already shows the host sends the same sequence on both paths.

---

## Installation

```powershell
# --- Windows host (this machine) ---
npm install --global rea-agents                # 6.4.0
# Extract Ghidra 12.1.4 to C:\tools (see sha256 above)
$env:GHIDRA_INSTALL_DIR = "C:\tools\ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot"
rea doctor --json ; rea providers --json
rea setup --client opencode --yes --json
```

```bash
# --- WSL2 Ubuntu: Linux-only REA lanes (firmware / process capture) ---
sudo apt-get install -y binwalk unblob prlimit util-linux
npm install --global rea-agents
export REA_BINWALK_COMMAND=$(command -v binwalk)
export REA_UNBLOB_COMMAND=$(command -v unblob)
# (firmware lane verified on Linux x64 only)
```

```bash
# --- Tablet (Ubuntu 7.0.0-38-generic): build + instrument lanes ---
sudo apt-get install -y build-essential libelf-dev libssl-dev flex bison bc \
     dwarves zstd rsync cpio linux-tools-$(uname -r) intel-gpu-tools \
     trace-cmd bpftrace drm_info kexec-tools mainline
# firmware/extraction deps are on WSL, not required on the tablet
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not / When It Wins |
|-------------|-------------|------------------------|
| **REA + Ghidra** (agent-driven, has Windows P0) | Hand-rolled `analyzeHeadless` scripts (the repo already has `ghidra_export_power_callbacks.py`) | Keep the script as a **complement** for fixed batch extraction; REA wins for interactive, agent-driven follow-ups. Not either/or. |
| **Ghidra 12.1.4** | **Hopper** | Hopper is macOS/Linux only and commercial; REA cannot install it on Windows. Only if the workflow moves to a Mac. |
| **Ghidra 12.1.4** | **IDA** (REA provider) | Requires an IDA license; no advantage here. |
| **Ghidra 12.1.4** | **Binary Ninja / rizin / radare2** | Another RE engine = scope creep; Ghidra is already required and sufficient. |
| **`bindeb-pkg` test kernel** | Overwrite distro `i915.ko.zst` in place (Lane A) | Lane A is faster but leaves the stock module modified; keep it only for quick iteration, always with a backup + bootable fallback. |
| **Real-hardware bisect** | QEMU GLK/DSI emulation | QEMU has no Gemini Lake DSI/panel model; the failure is panel/power-state specific. Reject. |
| **External screenshot/webcam signal** | Parse a register as "panel lit" | No such register exists (proven). External observation is the only objective signal. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Re-adding the existing validated toolchain (DKMS `lenovo-d330-fix`, `d330_display_resume_fix.patch`, `analyze_igdkmd64.py`, `intel_reg` tracing) | Already shipped and validated in v1–v7 | Extend it; do not duplicate. |
| A **second DKMS** to patch i915 | Patches a core module; fragile, duplicates the build lane | The `bindeb-pkg` test-kernel lane (Lane B). |
| REA **Windows** process capture / historical-source import | Returns `unsupported_host`; Windows PTY capture is not supported | Run those lanes in **WSL2 Ubuntu**. |
| Staging RE targets under `.planning/`, on UNC/network, `subst`, or reparse paths | REA rejects non-fixed-NTFS / reparse / UNC / SUBST coordinates | Stage under a plain local path (`.planning` is a **junction to `.gsd`** here). |
| `modprobe -r i915` to swap the module at runtime | Refcounted (~28 refs); blocked (already disproven) | Reboot (or `bindeb-pkg` + reboot); use the unbind/bind **reload** only as the recovery workaround. |
| Bare PCI `reset` / device hot-remove of `0000:00:02.0` | Disproven; makes the panel worse / hangs the box | The existing `scripts/d330-display-reload.sh` unbind/bind reload. |
| Relying on `drm.debug` / `dyndbg` **without** `CONFIG_DRM_USE_DYNAMIC_DEBUG` | Reproduced dead end: accepted but no `[drm:...]` lines, 0 `vlv_dsi` sites | Build with `CONFIG_DRM_USE_DYNAMIC_DEBUG=y` + `dyndbg`; or use kprobes. |
| Injecting JVM flags through `_JAVA_OPTIONS` / `JAVA_TOOL_OPTIONS` | REA clears these; custom flags are unsupported config | Use `GHIDRA_HEADLESS_MAXMEM` / `GHIDRA_MAXMEM`. |
| Expecting `git bisect run` to span a reboot | The step reboots; the runner process dies | Manual bisect or a boot-time self-resuming harness (see Integration 3). |
| Treating a **kexec** boot as proof of a cold-boot fix | No UEFI GOP re-run; display state differs | Use kexec only to iterate faster; verify cold-boot claims with a real power cycle. |
| A cheap 4-channel logic analyzer for DSI capture | DSI HS rates far exceed it; result is unusable | Skip, or a real DSI protocol analyzer (not justified yet). |

---

## Stack Patterns by Variant

**If the target is `igdkmd64.sys` (Windows PE32+):**
- Windows REA + Ghidra P0 (read-only), 25 ops, staged on plain local NTFS.

**If the target is `IntelGopDriver` / raw firmware / the VBT blob:**
- Extract on **WSL2** with REA's firmware lane (binwalk 3.1.x / unblob 26.6.x), then select an extracted **ELF/PE** and open it in Ghidra. If REA P0 rejects the EFI image role, fall back to Linux Ghidra or the existing `uefi_firmware` + capstone path.

**If the target is the i915 driver itself:**
- No binary RE needed — it is **source**. Use the source build lane (Integration 2) + instrumentation (Integration 4).

**If the goal is live behavior, not static structure:**
- On-device instrumentation (Integration 4), not RE.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `rea-agents@6.4.0` | Node `^22.19.0 \|\| ^24.11.0 \|\| >=26.0.0` | Host has Node 26.5.1 ✓ |
| `rea-agents@6.4.0` | Ghidra **12.1.x** (verified 12.1.4) | Older/newer Ghidra majors are not accepted by the adapter. |
| Ghidra 12.1.4 | **JDK 21+** (no max), 64-bit full JDK with `javac` | Host has Microsoft OpenJDK 21.0.12 with `javac` ✓ |
| Ghidra 12.1.4 | **Windows 10+ x64** | Experimental **read-only PE (x86/x64) P0** only; no GUI/annotations, no other architectures. |
| REA firmware lane | Binwalk **3.1.x**, Unblob **26.6.x**, **Linux x64 only** | Run in WSL2. Needs `prlimit` (util-linux). |
| `CONFIG_DRM_USE_DYNAMIC_DEBUG` | Linux ≥ ~6.1 | Enables `drm_dbg_*` via dynamic debug; pairs with `dyndbg`. |

---

## Roadmap Implications (for phase ordering)

1. **REA+Ghidra bootstrap is a hard prerequisite** for the Windows-behavior and deep-RE analysis phases; it is config-only and unblocks `igdkmd64.sys` / firmware work. Do it early.
2. **The reversible test-kernel lane (Lane B) should exist before any bisect phase** — bisect without a rollback-safe install is a bricking risk on a device with no serial console.
3. **Instrumentation upgrade (dynamic debug + kprobes) belongs next to the deep-RE phase**, not the bisect phase; it replaces the slow `pr_err` loop for the resume-path work.
4. **Bisect is a parallel investigation** (independent of RE) and can start as soon as the test-kernel lane lands; scope it with the mainline-kernel sweep first.
5. **Firmware/GOP work needs WSL**, so it has a different host dependency than the PE RE — keep it a separate plan to avoid a Windows-only blocker.

---

## Sources

- REA docs (repository `morluto/rea`, main): `docs/installation.md` (Node 22.19/24.11/26, OpenCode client, Ghidra 12.1.x + JDK 21+, `rea doctor`, Windows P0, env vars, MCP registry `io.github.morluto/rea`), `docs/windows-ghidra-p0.md` (Windows x64 P0 boundary, read-only, NTFS/reparse admission), `docs/firmware-analysis.md` (Binwalk 3.1.x / Unblob 26.6.x, Linux x64), `docs/process-capture.md` (Linux/macOS-only capture), `docs/cli.md` (providers, snapshots, `inspect-analysis-view`). — **HIGH**
- npm registry `rea-agents` latest = **6.4.0**, `engines.node` range, gitHead `a56f7bb6`. — **HIGH**
- GitHub Releases API: **Ghidra 12.1.4** `ghidra_12.1.4_PUBLIC_20260921.zip`, sha256 `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`, ~569 MB. — **HIGH**
- Local host verification: Node 26.5.1, npm 11.17.0, git 2.55.0, Microsoft OpenJDK 21.0.12 with `javac`, WSL2 Ubuntu 2, D:/C: fixed NTFS, `.planning` is a junction to `.gsd`. — **HIGH**
- In-repo research (`docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `DSI_RESUME_TRACE_ANALYSIS.md`) for the disproven-theory ledger, the dynamic-debug dead end, and the reload workaround. — **HIGH**
- Kernel tooling (`bindeb-pkg`, `git bisect`, mainline/`drm-tip`) is standard practice; the "bisect cannot survive a reboot" constraint is inferred from the test's reboot requirement. — **MEDIUM**

### Gaps to Address

- **Is GLK DSI resume a fixed mainline regression?** Web search (DuckDuckGo lite/html) returned bot challenges and lore.kernel.org / gitlab.freedesktop.org returned the Anubis anti-bot wall, so this could not be confirmed from upstream here. Resolve in the milestone's dedicated **bug-tracker research** task (i915 GitLab tracker, lore.kernel.org, ChromeOS/Distro forums) before committing to a long `git bisect`.
- **Does REA Windows P0 accept an EFI-subsystem `IntelGopDriver` image?** P0 admits "explicit native, non-managed x86/x86-64 PE application or DLL"; EFI images are untested. Verify with `rea providers`/a one-off open, and keep the Linux-WSL Ghidra / capstone fallback.
- **`CONFIG_KPROBES`/`KPROBE_EVENTS` presence in the Ubuntu generic build tree** — assumed enabled; confirm with `zgrep KPROBE /boot/config-$(uname -r)` before relying on bpftrace/perf-probe.
