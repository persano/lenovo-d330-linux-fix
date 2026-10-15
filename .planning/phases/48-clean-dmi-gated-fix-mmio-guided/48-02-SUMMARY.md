---
plan: 48-02
phase: 48-clean-dmi-gated-fix-mmio-guided
status: complete
completed: 2026-10-15
duration_min: ~125 (CI wait included, orchestrator-polled)
iteration: 1 of ≤5
---

# 48-02-SUMMARY: Deploy + iteration-1 session (human checkpoint)

## What Was Done

| # | Task | Status | Proof |
|---|------|--------|-------|
| 1 | Deploy script with rollback guard | DONE | `scripts/deploy_d330_kernel.sh` (238→248 lines); DRY_RUN fail/pass paths re-tested after the clobber fix (see Deviations 2); executor's 14-case local suite green |
| 2 | CI dispatch + deploy | DONE | run 38665460355 SUCCESS (~1h51m, grep anchors incl. new DMI gate green); artifact sha256 `43B2E7C2AE8646FC10FAF15E4379C0C375BB91DAC35C36A06A9443D36CD89332` (image deb) + `E95FE630ACB151F260B1714D5276DA8BFC606A13B0194AA9F3116104D573516E` (headers); deploy script exit 0; `uname -r` = `7.0.14-d330-fix`; dump node present at `/sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs` (root-listed) |
| 3 | Iteration-1 suspend/resume session (CHECKPOINT) | DONE | boot arm captured pre-suspend (panel lit): `it1_boot_dsi_regs.txt` sha256 `f104496e186fb9fe8eda083cd6cdfe2db99aed6c303247169c08e3ba7e42fcf0` (7296 records, 0 skipped sections); scripted rtcwake 45 s (session-2 pattern, user-authorized); resume arm captured at wake+~1 s: `it1_resume_dsi_regs.txt` sha256 `52bd720c5ef708e44db65ba63428938ff10fffce7087e7b102e9722483980e62` (7296 records, 0 skipped); trigger_time 2026-10-15 09:39:35 -0300 |

## User verdict (verbatim)

"Still black" (user, eyes-on, in response to "Looking at its screen NOW: what do
you see?" after the ~45 s suspend/resume cycle). Panel restored after the
session by running the user's own reload workaround via ssh
(`d330-display-reload.sh`, unbind/bind i915) — the proven recovery, used so the
device stays usable between iterations.

## Iteration-1 fix kernel

CI applied both patches (dump node baseline + iter-1 fix patch `1418a8b`);
grep anchors proved `dmi_match(DMI_PRODUCT_NAME, "82H0")` in the built tree.
The fix's fresh-branch behavior ran (at-wake 0x6b000 DEVICE_READY identical to
boot — the fresh-probe re-arm took effect; ULPS dance skipped by construction).
Outcome routed in 48-03-PROGRESS-it1.md: FAILED (ledger row 30).

## Deviations

1. **[Environment] Deploy script needed WSL-interop overrides.** The script's
   ssh calls initially failed under WSL bash: the `santiago-D330` mDNS alias
   only resolves from the Windows side, and the device authorizes the Windows
   `id_ed25519` key (not the WSL keychain). Fixed by adding env overrides
   (`D330_DEVICE`, `D330_SSH_OPTS`) instead of editing constants; the wrapper
   `scripts/deploy_48_via_wsl.sh` pins the endpoint `santiago@192.168.2.195`
   with a copied ed25519 key. Documented in the script header.
2. **[Rule 3 - Blocking] Rollback asset CLOBBERED by the first deploy (name
   collision), detected and fixed the same day.** The script uploaded the new
   deb to `/home/santiago/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` —
   the same basename as the rollback asset — overwriting the verified
   20dc04db…9e91 recovery deb AFTER the pre-deploy rollback check had passed.
   Post-deploy sha re-check caught it. The asset was re-established as the
   d47 dump kernel (`/home/santiago/d47_dump_kernel.deb`, sha256
   `ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be`,
   verified on device and against the 47 CI record). Script fixed: uploads now
   go to a sha-keyed `deploy_incoming_<sha12>.deb` name (never collides, and
   the uploaded copy is KEPT as the next deploy's rollback target), and
   `D330_ROLLBACK_DEB`/`D330_ROLLBACK_SHA` are overridable. FIX-02 discipline
   restored: every future deploy re-verifies the rollback asset beforehand.
   The lost 20dc04db deb existed only on the device (no host copy); the d47
   dump kernel is a proven-bootable older build of the same package, so the
   recovery chain remains: current → d47 dump kernel → Phase-43 live USB/golden
   i915.ko for deeper failures.
3. **[Environment] `systemd-inhibit` denied over ssh** (polkit): session 3
   initially failed with "requires interactive authentication". Session 2's
   log shows it ran as root; re-ran under scripted sudo — identical pattern,
   session succeeded (suspend + wake + capture all clean).
4. **[Plan wording] The plan's task 2 dump-node acceptance cited the dri glob;
   the node is a snapshot that needs `echo 1` trigger + capture helper** (as
   47 established). Used the staged `/usr/local/bin/capture_dsi_dumps.sh`
   helper for both arms; raw node cat is empty by design.

## Risks / Notes for 48-03 and beyond

- The device currently runs the iter-1 fix kernel (black on resume; panel
  restored via reload workaround). Next iteration deploys on top; rollback
  target per deploy = the previous iteration's `deploy_incoming_*.deb` (the
  iter-1 deb is preserved on device as
  `/home/santiago/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb`, sha
  43b2e7c2…8932).
- The operational signature at wake (diff it1) matches session 2 exactly:
  the fix changed nothing observable — evidence for 48-03's routing.

## Self-Check

- CI grep anchors green (run 38665460355 success).
- Both arms captured with floor-checks (7296 records, 0 skipped each).
- Kit registration + verify green (3 new artifacts: it1 boot, it1 resume,
  dsi_regs_diff_it1).
- Ledger gate final run: passed=4 failed=0.
- `## Self-Check: PASSED`
