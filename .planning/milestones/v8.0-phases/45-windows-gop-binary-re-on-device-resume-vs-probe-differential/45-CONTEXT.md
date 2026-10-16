---
phase: 45
slug: windows-gop-binary-re-on-device-resume-vs-probe-differential
created: 2026-10-12
status: discussed
audit_acknowledged:
  milestone: v8.0
  at: 2026-10-16
  questions_digest: 19430a5ce591ae1718325b46f54c8ab166191f84933d3dddf7c420c171de513f
---

# Phase 45 Context — Windows/GOP Binary RE + On-Device Resume-vs-Probe Differential

## Phase goal (from roadmap)

Answer "what does probe do that resume does not?" with both independent inputs — static RE of the vendor Windows/GOP path and the dynamic on-device resume-vs-reload differential — then land a DMI-gated fix, or prove no clean fix is achievable. Requirements: WRE-01, WRE-02, WRE-03, ROOT-01, ROOT-02, ROOT-03, ROOT-04.

## User decisions (grey areas resolved in discussion)

1. **RE binary sources: Lenovo package downloads + device SPI dump cross-check.**
   The repo has no `igdkmd64.sys`, GOP image, or VBT binary; the prior
   `docs/windows_analysis/RESUME_SEQUENCE.md` is marked SUPERSEDED/PARTLY
   INVALID (its eDP/PPS-timing premises were wrong). Acquisition plan:
   download the Lenovo D330-10IGL display driver package (the docs already
   name `3gid020fh6y37sb0.exe`) and the Lenovo BIOS update capsule (GOP +
   VBT live in the firmware volume) on the Windows host, extract the
   binaries, AND dump the D330's SPI flash on-device (flashrom/chipsec over
   SSH) as a cross-check for VBT/GOP authenticity.

2. **Ghidra: install headless on the Windows host.** JDK + ~500 MB download
   approved. WRE-01 is "REA+Ghidra wired to GLM 5.3 Flash" — the LLM drives
   headless decompilation passes and produces cited file+address+bytes
   evidence.

3. **Fix build path: CI.** `build-kernel.yml` already built 7.0.14-d330-fix;
   fix candidates are pushed as a branch and deployed via SSH exactly like
   the existing fix kernel.

4. **Fix budget: up to 5 kernel build/deploy/test iterations.** After 5
   evidence-backed iterations without a clean resume fix, ROOT-04 becomes
   the honest outcome (prove it, close the milestone on the packaged
   recovery).

## Anchors from prior phases (load-bearing)

- The ONLY working recovery on-device is the full i915 unbind/bind reload
  (`echo 0000:00:02.0 > /sys/bus/pci/drivers/i915/unbind` then bind). Bare
  reset / remove+rescan fail; `modprobe -r` fails (in use). (RESUME_FIX_LEDGER.md)

- The known GLK DSI commit `615c8ec48621` (DSI-C clock divider fastset
  cleanup) is present in every bootable kernel and is NOT a resume fix —
  ruled out as the differentiator (Phase 44).

- Kernel logs are CLEAN on resume-black (both bootable kernels, Phase 44
  sweep) — the failure is invisible in logs; the differential needs
  instrumentation (ftrace over display register ranges, per
  RESUME_CAPTURE_PROTOCOL.md), not log greps.

- Kernel-side panel verdicts are unreliable without instrumentation (Phase
  44: user not watching, verdicts retracted) — Phase 45's differential MUST
  measure panel/backlight state from registers/sysfs (backlight level,
  DSI link state, PPS registers), not from user eyes.

- The automatic reload hook ships with a stand-down contract:
  `D330_REAL_FIX=1` in `/etc/default/lenovo-d330-display-resume` makes the
  hook stand down — Phase 45 writes that marker when the real fix lands.

- Device facts: DMI `82H0`, eMMC index flips across boots (address by
  UUID), Kubuntu GRUB env dual-store mechanics, hook NOT installed on the
  device (stock recovery absent during experiments — by design).

- Cmdline already carries `i915.enable_psr=0` and `i915.enable_fbc=0`
  (PSR/FBC ruled out as the mechanism).

## Constraints

- Never write device credentials into repo files or docs.
- Do not modify the device's boot config beyond what a fix-kernel deploy
  requires (the one-time grub change in phase 44 was user-approved and
  reverted; avoid repeating it — deploys default to the fix kernel).

- The device is the user's daily machine; sweeps suspend it (~35 s) and
  panel verdicts CANNOT come from the user (established in phase 44) —
  instrumentation is the only observation channel.

- BIOS/SPI dump on-device is read-only (never flash anything on the device).
- The upstream bug report (Phase 44) stays pending; ROOT-02/ROOT-03 evidence
  may strengthen it (Phase 46 decides submission).

## Open questions for planning

1. Differential arm design: exactly which register ranges to trace, and
   what the "probe-side" reference is (cold boot panel-init sequence
   captured the same way?) — RESUME_CAPTURE_PROTOCOL.md defines the two
   arms; Phase 45 planning refines the third input: the GOP panel-init
   order from RE as the ground truth both arms are compared against.

2. Which kernel tree/branch the fix is cut from (the device's
   `~/d330-kernel/linux-7.0.0` base + CI's existing fix patch set), and
   where the DMI gate lives (`intel_quirks.c` vs local quirk table).

3. VBT decode tooling: igt's `intel_vbt_decode` vs a purpose-built parser
   fed by the SPI-dump VBT; WRE-03 needs the DSI link config (single/dual
   link, ports, MIPI sequence version) as output.

4. Backlight brightness restoration (ROOT-03): whether the fix must restore
   the user's brightness level itself or only the panel power (and the
   backlight level survives resume) — the success criterion says the panel
   returns "at the user's brightness with no manual write".
