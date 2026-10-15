---
plan: 48-03
phase: 48-clean-dmi-gated-fix-mmio-guided
status: iteration-2-routed
iteration: 2 of ≤5
completed: 2026-10-15
---

# 48-03-PROGRESS-it2: Iteration-2 evidence + routing

## Diff analysis (it2_boot vs it2_resume)

Same broken operational signature as it1 and session 2 (10 differs rows):
0x6b010 `003fffff→0000b8ea`, 0x6b044 `0000001d→0000001e`, 0x6b080
`09051003→0a051003`, 0x6b088 `0022000f→0014000c`, 0x160018
`00000115→00000001`, GT rows 0x138108/0x13816c/0x13819c, 0x6b094 `1→0`
(excluded-volatile), 0x6b004 W1C `00080000→40280000`. All static config
(PLL/CDCLK, PHY, PPS) identical. The full panel power cycle (assert reset,
power off, 1.5 s hold, full re-init) did NOT move the operational rows and did
not produce an image.

## NEW observation (failure mode changed)

Verdict verbatim: **"black but lit"** (user, eyes-on). The panel now comes up
backlit-but-blank by itself. Before it2, the wake state was dark (ledger row
27 had to force the backlight to observe the lit-but-blank state). Reading:
the panel-side power cycle ran for real — the power rails and backlight rail
now behave like the reload path — but the DSI link/video path still delivers
no image. Panel power sequencing is no longer the discriminator.

## Instrument regression found this iteration

After the post-session reload workaround (unbind/bind), the 47 dump node is
GONE: `d330_dsi_dump_register()` allocates the snapshot buffer once and
returns early on re-probe, skipping the `debugfs_create_file` call — so an
unbind/bind kills the node until the next full boot. Consequence: reload-state
captures (the lit-state third arm) are impossible until the instrument is
fixed. Fix rides along with iteration 3's CI build (one run, both changes).

Also observed: the rebind produced a kwin_wayland crash trace in dmesg
(compositor restarts; the user's desktop survived the workaround as before).

## Routing decision (plan task 2)

FAILURE arm taken: ledger row 31 appended (variant: DMI-gated full panel
power cycle at the top of pre_enable on the resume window; result: power
side restored, image still absent, signature unchanged).

**Mechanism consequence:** panel power sequencing eliminated as the
discriminator. The remaining resume-vs-reload differences at the
hardware/state level: (a) the DSI-block hardware reset pulse — reload's
power-well cycle resets the MIPIO/DSI block (MIPIO_RST_CTRL family,
0x138090), the broxton-only code block is skipped on GLK and no resume path
ever pulses it; (b) the full display-core re-init the probe performs (power
domains, DMC reload, PLL from reset state). Iteration 3 (next rung): pulse
the DSI-block reset before the sequence.

**Falsification check (§5 DSI_MMIO_DIFF):** not yet fired — the at-wake
signature STILL differs from boot (X=Z at wake), so "X=Y held + black" is
not established; there remains a host-visible component that changes at
wake no matter what the enable path does.

## Guard chain (this iteration)

- ledger gate: passed=4 failed=0 (row 31 added, Lever rows: 31,
  marker added to GOP_DSI_RE_FINDINGS.md sequence table)
- evidence suite: 7/7; fixtures: 8/8 (unchanged tooling)
- kit: 3 artifacts registered (it2 boot, it2 resume, diff it2), verify green

## Checkpoint record (verbatim per protocol)

- Question: "Iteration 2 (panel power cycle) just did its suspend/resume
  cycle (~45 s asleep). Looking at the tablet's screen NOW: what do you see?"
- Answer: **"black but lit"** (user typed via the "Other" option).
- Authorization: scripted rtcwake session (same session-3/4 pattern).
- Panel restored post-session via the user's reload workaround (pwsh ssh).
- Session environment note: WSL networking broke mid-iteration
  (networkingMode Mirrored error, reverted to None) — the deploy completed
  via git-bash + pwsh-native ssh; device-side operations unaffected.
