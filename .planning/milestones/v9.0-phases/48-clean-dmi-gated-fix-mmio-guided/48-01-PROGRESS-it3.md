---
plan: 48-01
phase: 48-clean-dmi-gated-fix-mmio-guided
status: iteration-3-wired
iteration: 3 of ≤5
completed: 2026-10-15
---

# 48-01-PROGRESS-it3: Iteration-3 fix patch + dump-node regression fix + CI wiring

<!-- planner-discipline-allow: panel power cycle -->

## What Was Built

Two changes on branch instrument/d330-dsi-dump (both device-compiled,
committed on the branch, pushed):

### 1. Iteration-3 fix: patches/d330_dsi_mipio_reset.patch (commit 41325d1)

Strictly additive (25 insertions, 0 deletions), in
`intel_dsi_pre_enable()`, at the very TOP (before it2's block, before
`intel_dsi_wait_panel_power_cycle()`, before the PLL work), DMI-gated to
82H0 reusing it2's static-bool helper `d330_82h0_panel()` (the it2 patch
defines it once; it3 adds no second helper), gated to the same resume
window it2 established:

    display->power.domains.init_wakeref

(held from intel_power_domains_resume() until intel_power_domains_enable(),
which brackets the system-resume display re-commit; plain modesets run
after that window; the D330 cold boot runs no encoder hooks at all).

The pulse (register/bit symbols verified in the device tree
~/d330-kernel/linux-7.0.0):

- `BXT_P_CR_GT_PWRON` register symbol: `BXT_P_CR_GT_DISP_PWRON` =
  `_MMIO(0x138090)` (display/intel_display_regs.h:19)
- bit symbol: `MIPIO_RST_CTRL` = `(1 << 2)` (intel_display_regs.h:20)
- tree users: vlv_dsi.c:755 pre_enable sets the bit ("Add MIPI IO reset
  programming for modeset", broxton-only block); vlv_dsi.c:913 post_disable
  clears it
- polarity proof from the tree: `bxt_dpio_phy_is_enabled()` returns false
  when the PWRON bits are read clear, and `_bxt_dpio_phy_init()` SETS the
  bits and then waits for the PHY to become accessible ("PHY registers
  start out inaccessible... Eventually become accessible as they power
  up") - so SET = released/functional, CLEAR = held in reset

Pulse sequence (mimics the reload's power-well cycle, research §3 iter-3
"drop+re-assert MIPIO_RST_CTRL"):

1. `intel_de_rmw(display, BXT_P_CR_GT_DISP_PWRON, MIPIO_RST_CTRL, 0);` (drop: block held in reset)
2. `msleep(10);`
3. `intel_de_rmw(display, BXT_P_CR_GT_DISP_PWRON, 0, MIPIO_RST_CTRL);` (re-assert: released)
4. `msleep(10);`

Bit left RELEASED at the end - the state the enable path leaves it in on
broxton machines. Machine-evidence caveat recorded in the patch message:
0x138090 reads 0 on every arm captured so far (boot, working resume, it2
boot/resume) because the broxton block is skipped on this Gemini Lake
machine, so the pulse leaves bit2=1, a value not yet observed on this
machine; 48-RESEARCH §3 already flagged the lever "may be a no-op; it is
the last pre-TCON host lever".

**Deviation [Rule 1 - task-spec polarity fix]:** the rung description said
"assert the MIPIO_RST_CTRL reset bit (block in reset), de-assert
(release)" - the tree's bxt_dpio_phy code proves the opposite polarity, so
the patch implements drop-then-reassert (the research's own wording). A
literal set-then-clear under the proven polarity would end with the DSI
block held in reset through the whole sequence.

Requires the it2 patch applied first (hunk context is the post-it2 file;
reuses its helper). CI order: dump patch, it2 patch, it3 patch.

### 2. Dump-node re-probe fix: patches/d330_dsi_dump.patch amended (commit 18c12f7)

48-03-PROGRESS-it2 instrument regression: `d330_dsi_dump_register()`
returned early when the snapshot buffer was already allocated, skipping
`debugfs_create_file`, so the post-session unbind/bind left NO dump node
until the next full boot. Fix (minimal, inside the patch's own
file-creation hunk): only the snapshot BUFFER allocation stays guarded by
the once-guard; `debugfs_create_file` moved outside/below it so EVERY probe
re-creates the file, reusing the existing buffer. File 276 -> 280 lines.
Grep-proof: `debugfs_create_file` now executes unconditionally on every
probe path.

## Device compile proof (santiago-D330, ~/d330-kernel/linux-7.0.0)

- staged patch sha256s (identical local vs device, sha256sum verified):
  - d330_dsi_mipio_reset.patch `2bc1a670949aea0e2ba6e453bff344efc23aa2c8a672ba5fc54789158015795a`
  - d330_dsi_dump.patch `5d7672885c28f743fa680d791fe3aaf52ab1df314b368b65bf9670b140063b9c`
  - d330_dsi_panel_power_cycle.patch `a6deb9445bd951daac6418ad4532684549a8a522bb9d0bcb761bad7dcb77719d`
    (byte-identical to it2's recorded sha)
- applied in CI order on the device tree (NOT a git repo; plain `git apply`
  like it2): dump, it2, it3 - all `git apply --check` clean, all applied
- composed vlv_dsi.c verified: it3 pulse block at ~755, it2 block at ~800,
  both gated on `d330_82h0_panel() && display->power.domains.init_wakeref`,
  before `intel_dsi_wait_panel_power_cycle()` and the PLL work
- `make M=drivers/gpu/drm/i915 modules`: **exit 0**
  (CC i915_debugfs.o, CC display/intel_dsi_dump_debugfs.o, CC
  display/vlv_dsi.o, LD i915.o, MODPOST, CC i915.mod.o, LD i915.ko; a
  second incremental run returned MAKE2_EXIT=0)
- known pre-existing warning (present in 47 too): d330_dsi_dump_register
  -Wmissing-prototypes (its prototype lives in i915_debugfs.c)
- reverted: `git apply -R` it3, it2, dump - all clean
- md5 round-trip (before == after):
  - vlv_dsi.c `b9338cdf49a092489b8fa932086b0844`
  - i915_debugfs.c `a423c129c9595cf4dca05330501703b2`
  - Makefile `ce8f29f37ed036e2c61a31b37ed9f534`
  - intel_dsi_dump_debugfs.c deleted (was absent before)
- no new .rej/.orig from this session; staged patches removed from
  /home/santiago/ (only the pre-existing dsi_pc.patch remains, untouched)
- device tree phase-45 leftovers (intel_display_driver.c + *.orig) NOT
  touched, per instructions

## CI wiring (commit 550cb55)

build-kernel.yml "Apply the display fixes and prove they landed" step: it3
apply line + 1 grep anchor ADDED AFTER the it2 apply + grep (kept); the it3
anchor greps the unique inserted string `'resume: MIPIO reset pulse'` in
vlv_dsi.c. KEPT all pre-existing anchors: the 2 skl_universal_plane greps,
the dump-node greps (i915_dsi_regs, bxt_dsi_pll_is_enabled), and the it2
DMI-gate grep anchor (`dmi_match(DMI_PRODUCT_NAME, "82H0")` in vlv_dsi.c -
still passes: it2's helper carries the only dmi_match call; it3 reuses it).
Pushed: origin `65c0b01..550cb55`.

## Patch self-greps

- it3 patch: banned strings (0x6b000/0x6b010/0x6b044/0x6b080/0x6b088/
  0x6b094/0x160018/0x160084/DEVICE_READY/ULPS/panel power cycle/panel
  power-cycle/rebind/DSI regulator/0x160054/msleep(300)): **0 hits**
- it3 patch: 25 insertions, 0 deletions; adds no dmi_match call (reuses
  the it2 helper); `d330_82h0_panel` appears twice (comment + code)
- dump patch: banned strings appear ONLY in the pre-existing 47-01 overlay
  decode region (patch lines 106-192, read-only register-name decode
  layer); the amended block (patch lines 205-225) is clean; 0 deletions

## Key Hashes

- Branch instrument/d330-dsi-dump: `18c12f7` (dump fix), `41325d1` (it3
  patch), `550cb55` (CI wiring); pushed origin `65c0b01..550cb55`.
- /gsd-ship must now merge 11 commits (fdafc43, fb86c6a, 30f077c, b753d39,
  1418a8b, 122a75c, f1914da, 65c0b01, 18c12f7, 41325d1, 550cb55).

## Risks / Notes for 48-02

- 0x138090 end state after the pulse is bit2=1 (released) - a value never
  observed on this machine so far (all captured arms read 0). If the bit is
  live on GLK, the at-wake dump will show `0x138090=00000001` vs boot `0`:
  an expected self-inflicted row, not a regression signal. The next
  unbind/bind reload cycles the power well and self-heals the register to 0.
- The falsification branch (DSI_MMIO_DIFF §5) stays live: if the panel
  stays black with the at-wake signature unchanged, iters 4-5 pivot per the
  ladder.
- CI was NOT dispatched (48-02 owns dispatch). No artifact exists yet.
- The dump-node fix rides this CI build (one run, both changes) per
  48-03-PROGRESS-it2's routing decision.
- Panel is currently lit (user's reload workaround); NO device
  display-state actions were taken this iteration (instrument/CI work
  only; no reload/unbind performed).

## Ledger Gate

`bash scripts/test_pitfalls_ledger.sh` (git-bash; WSL bash networking
dead): passed=4 failed=0, exit 0; files=45 hits=0 (run after all writes).

## Self-Check

- it3 patch committed `41325d1` sha256 `2bc1a670…5795a` == device-tested
  sha - match.
- dump patch committed `18c12f7` sha256 `5d767288…63b9c` == device-tested
  sha - match.
- CI commit `550cb55` pushed: origin `65c0b01..550cb55` - verified in push
  output.
- Device tree md5s restored post-revert; staged patches removed.
- Ledger gate 4/4 green after all writes.
- `## Self-Check: PASSED`
