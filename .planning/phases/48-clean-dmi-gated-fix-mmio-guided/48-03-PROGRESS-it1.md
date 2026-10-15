---
plan: 48-03
phase: 48-clean-dmi-gated-fix-mmio-guided
status: iteration-1-routed
iteration: 1 of ≤5
completed: 2026-10-15
---

# 48-03-PROGRESS-it1: Iteration-1 evidence + routing

## Diff analysis (plan task 1 acceptance answers)

- (a) **Do the operational rows match boot at wake?** NO — the broken
  signature is identical to the unpatched session-2 pair:
  0x6b010 `003fffff→0000b8ea`, 0x6b044 `0000001d→0000001e`,
  0x6b080/0x6b098 `09051003→0a051003`, 0x6b088 `0022000f→0014000c`,
  0x160018 `00000115→00000001`, GT rows 0x138108/0x13816c/0x13819c differ,
  0x6b094 `1→0` (excluded-volatile per ledger rows 3/18),
  0x6b004 W1C `00080000→40200000`. 9 differs + 4 excluded-volatile rows;
  1017 registers identical (incl. all static PLL/PHY/PPS config).
- (b) **0x6b000 state at wake?** IDENTICAL to boot (DEVICE_READY set) — the
  iter-1 fresh branch re-armed the device exactly as designed; the fix's
  mechanism demonstrably ran. (0x160084, which differed in the 47 dump, reads
  identical to boot here — another flickering at-wake transient, consistent
  with the §5 "at-wake state is a flickering proxy" finding.)
- (c) **Timeout-marked bits on 0x6b004?** YES — `40200000` (write-1-to-clear
  status with a timeout-class bit set), same signature class as session 2's
  `40280000`.

## Routing decision (plan task 2)

Verdict verbatim: **"Still black"** (user, eyes-on). FAILURE arm taken:
ledger row 30 appended (variant: DMI-gated clear of retained
ULPS_STATE_MASK + DEVICE_READY before the cold-boot probe; result: reload-
identical branch ran, panel stayed black, signature unchanged).

**Mechanism consequence:** the retained-DEVICE_READY/ULPS-dance divergence is
falsified as the sole cause. The enable path can now match the reload path
step-for-step at the DSI device level and the panel still stays black. The
remaining resume-vs-reload difference at the panel/power level: reload
(power cycle via unbind/bind) takes the panel through a FULL power-domain
teardown/rebuild, while resume's VBT POWER_OFF/POWER_ON is constrained by
the live driver state.

**Next-iteration decision (ladder §48-RESEARCH §3):** iteration 2 = full
panel power cycle inside pre_enable (ASSERT_RESET + POWER_OFF + t-delay +
POWER_ON + DEASSERT_RESET + INIT_OTP + DISPLAY_ON, DMI-gated 82H0), the
exact cycle the working reload produces for the panel. Budget: 2 of 5 used
after it2. No honest-closure write yet (budget not exhausted; falsification
branch not yet fired — the at-wake signature still differs from boot, so
"X=Y held + black" is not established).

## Guard chain (this iteration)

- ledger gate: passed=4 failed=0 (row 30 added, Lever rows: 30)
- evidence suite: 7/7; fixtures: 8/8
- kit: 3 artifacts registered (it1 boot, it1 resume, diff it1), verify green
- selftest: 35/35 (47 baseline, unchanged tooling)

## Checkpoint record (verbatim per protocol)

- Question: "The tablet just did one suspend/resume cycle (about 45 seconds
  asleep). Looking at its screen NOW: what do you see?"
- Answer: **"Still black"** (user selected the "Still black" option).
- Authorization: user selected "Scripted rtcwake (Recommended)" for the
  session trigger method (per-session scripted-execution authorization
  granted by that choice).
- Panel restored post-session via the user's reload workaround (run for the
  user over ssh; script output: unbind → rebind → done).
