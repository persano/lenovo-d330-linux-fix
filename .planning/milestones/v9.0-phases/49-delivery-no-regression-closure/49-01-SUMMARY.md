---
plan: 49-01
phase: 49-delivery-no-regression-closure
status: complete
completed: 2026-10-16
duration_min: ~150 (3 cycles + premise correction + recovery-ladder tests)
---

# 49-01-SUMMARY: The 3-cycle close-out protocol + the corrected closure

## What Ran

Three user-triggered suspend/resume cycles on the it3 kernel (sha
C2C2CD89…1073), each with full machine evidence and eyes-on verdicts:

| cycle | protocol | verdict (verbatim) | key evidence |
|---|---|---|---|
| 1 | boot → wake (rtcwake 45 s) → reload → "lit" arm | "Black but lit" | close1 boot 47f51c9a…03a2d4 / resume b7d1c494…562188 |
| 2 | boot → wake → late-black (30 s) → reboot | "Black but lit" | close2 boot 45e3fbc4…96a69 / resume 59f0959a…6be2a0 / late 5990bc3a…ee0436 |
| 3 | boot → wake → late-black (30 s) → reboot | "Black but lit" | close3 boot 26ac264e…275ac8 / resume 3265c575…baadb3 / late 2dc00ecf…b65f0e |

All arms 7296 records, 0 skipped, ≤18 s at-wake windows, kit-registered
(12 new artifacts), kit verify green, ledger gate 4/4 throughout.

## The Premise Correction (the session's most important finding)

The user revealed the reload workaround had **never** restored an image for
them — they never ran it themselves ("has not tried it, only you did it. Do
not know the actual command keys. Tell me and I will do it or execute it
yourself and I will confirm" — verbatim). Eyes-on ladder this session:
reload → **lit-black**; sddm restart → **lit-black**; reboot → **image**.
The "user's daily workaround restores the panel" premise (inherited from
v8.0 prose) was never eyes-on-verified in v9.0 — and it is FALSE: the
unbind/bind leaves a backlit black panel (kwin dies on unbind; the pipe is
never re-driven; row 29's v8.0 myth-bust re-confirmed on the v9.0 kernel).

Consequence: phase 48's §5.1 "falsification" compared two BLACK states
(reload_lit was never an image state). Corrected in §5.2 (DSI_MMIO_DIFF),
§7.1 (NO_CLEAN_FIX_PROOF), and RESUME_VS_RELOAD_DIFFERENTIAL.

## The Corrected Closure (machine-evidenced, 2 independent cycles)

<!-- planner-discipline-allow: 0x160018 -->
<!-- planner-discipline-allow: rebind -->

1. **X=Y (boot, image showing) vs X=Z (broken) discriminates.** Late-black
   (30 s, verified black both cycles) HOLDS X=Z: 0x6b010=0000b8ea,
   0x6b044=0000001e, 0x6b080/0x6b098=0a051003, 0x6b088=0014000c,
   0x6b004 timeout-marked 40280000; 0x160018 flickers (0x1/0x115).
2. **The kernel re-probe ALSO lands at X=Z** (close1_lit ≈ close1_resume;
   reload_lit == it3_resume) — which is why the rebind is lit-black: the
   full PCI re-probe fails to re-reach the GOP state exactly like the
   resume path does.
3. **X=Y values alone are insufficient** (v8.0 row 18: forced X=Y at end of
   pre_enable → still black).
4. **Only the GOP's firmware boot init produces the image** — it alone
   reaches X=Y AND does the direct TCON programming the kernel cannot see
   or replay (GOP_DSI_RE_FINDINGS; the DPHY 0x162000+ area reads all-ones).
5. **Recovery = reboot** (re-runs the GOP). No non-reboot recovery exists:
   not reload (lit-black), not sddm/kwin restart (lit-black), not any
   tested kernel path.

Ledger note appended (row 29 re-confirmed with v9.0 eyes-on; no new row —
same lever). DONE-01 closes as "unreachable, machine-proven" per the
accepted decision — the 3 cycles + the corrected contrast ARE the proof,
and any future reopen path is documented (§7.1 next steps).

## Gate Status

- ledger gate: 4/4 (rows unchanged; note appended)
- kit: 12 new artifacts (close1/2/3 arms + diffs), verify green
- evidence suites: unchanged tooling (7/7, 8/8 exercised at phase close in 49-03)
- device end-state: it3 kernel deployed, panel restored by final reboot,
  rollback chain intact

## Self-Check

- `## Self-Check: PASSED`
