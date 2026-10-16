---
plan: 48-03
phase: 48-clean-dmi-gated-fix-mmio-guided
status: iteration-3-routed-falsification-fired
iteration: 3 of ≤5
completed: 2026-10-15
---

# 48-03-PROGRESS-it3: Iteration-3 evidence + FALSIFICATION

## Diff analysis (it3_boot vs it3_resume)

Identical broken signature to it1/it2 (10 differs rows: 0x6b010/0x6b044/
0x6b080/0x6b088/0x160018 + GT rows + excluded-volatile set). The MIPIO reset
pulse ran (self-inflicted expected row: 0x138090 bit2 now reads 1 at wake —
documented in the it3 progress notes) and did not move the operational rows
nor produce an image.

## THE DECISIVE CAPTURE (enabled by the it3 instrument fix)

The iteration-3 build also fixed the dump node to survive an unbind/bind
(buffer alloc stays once-guarded; debugfs file re-created on every probe).
Sequence: it3 session → verdict "Black but lit" → reload workaround run for
the user → **panel showing the image** → dump captured with the node still
alive: `docs/dumps/re_kit/reload_lit_dsi_regs.txt` (sha 593739ff…0e2c).

`dsi_regs_diff_lit_vs_wake.txt` (reload_lit vs it3_resume):

- **DSI block 0x6b000-0x6c000: 1024/1024 registers IDENTICAL**
  (all operational rows included: 0x6b010=0000b8ea, 0x6b044=0000001e,
  0x6b080/0x6b098=0a051003, 0x6b088=0014000c, 0x6b094=0, 0x160018=0x1).
- Whole-file delta: **5 rows, all GT**: 0x138070/0x138074 (monotonic
  counters, excluded-volatile), 0x138108 (GEN6_GT_GFX_RC6 residency),
  0x13819c (GT PM, time-dependent).
- Zero DSI / DSI-PHY / PLL/CDCLK / PPS / MIPIO rows differ.

**The MMIO state of the panel that SHOWS THE IMAGE equals the MMIO state of
the panel that is BLACK.** The X=Y vs X=Z contrast never discriminated
working from broken — X=Z is simply what the kernel-run path leaves, working
or not. Falsification (DSI_MMIO_DIFF §5.1) fires at maximum strength.

## Routing decision

FAILURE + FALSIFICATION arm: ledger row 32 (it3 failed) + falsification
recorded in DSI_MMIO_DIFF §5.1, RESUME_VS_RELOAD_DIFFERENTIAL (v9.0 section),
NO_CLEAN_FIX_PROOF §7 (honest closure) + §8 (state left behind). Iterations
STOP at 3 of ≤5: the disproof discipline forbids re-proposing any further
register/sequence lever — they are all now disproven BY the lit-vs-wake
identity. No honest-closure alternative existed (SC1's "mechanism proven
unreachable with documented reason and concrete next instrument" is met by
§5.1 + §7's next-instrument section).

## Guard chain (this iteration)

- ledger gate: passed=4 failed=0 (row 32, Lever rows: 32; markers added to
  NO_CLEAN_FIX_PROOF + RESUME_VS_RELOAD_DIFFERENTIAL)
- evidence suite: 7/7; fixtures: 8/8
- kit: 5 artifacts registered (it3 boot/resume, reload_lit, diff it3,
  diff lit_vs_wake), verify green

## Checkpoint record (verbatim per protocol)

- Question: "Iteration 3 (DSI-block reset pulse) just did its suspend/resume
  cycle (~45 s asleep). Looking at the tablet's screen NOW: what do you see?"
- Answer: **"Black but lit"** (user selected the option).
- Authorization: scripted rtcwake session (session-5 pattern, user-selected
  method at the it1 checkpoint).
- Panel restored post-session via the user's reload workaround (pwsh ssh).
- CI runs: it2 = 38743898749, it3 = 38789067483 (both SUCCESS, ~2 h each,
  polled inline by the orchestrator per the FIX-03 strategy).
