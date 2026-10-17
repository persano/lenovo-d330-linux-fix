---
phase: 50
plan: 50-04
status: complete
started: "2026-10-17T01:00:00Z"
completed: "2026-10-16T23:30:00-03:00"
---

# Plan 50-04: Deploy + Session A boot arm — Summary

## What Was Built

The sha-verified echo-2 kernel (from 50-01, `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb`, sha256 `22AE3D58F9796197F452EBDF30814468FD2CCB0D5B826600736BA6FD0AACFA1A`) was deployed to the D330 behind a verified rollback, and Session A (boot arm, X=Y, no suspend) was run twice at the user's request — both runs identical.

## Tasks

| Task | Name | Status |
|------|------|--------|
| 1 | Deploy echo-2 kernel, rollback verified first | ✅ |
| 2 | Session A capture + I2C sweep + tracepoints (X=Y) | ✅ (ran twice — user-requested retry, byte-identical DCS result) |
| 3 | Kit-register the Session A artifacts | ✅ (both runs registered, `--verify` exit 0) |

## Deploy Record (Task 1)

- Installed deb sha `22ae3d58…aacfa1a` == 50-01 record (verified host + device).
- Rollback `/home/santiago/deploy_incoming_c2c2cd89ce91.deb` sha `c2c2cd89…1073` sha-verified BEFORE `dpkg -i` and retained.
- Device end-state: echo-2 kernel installed; dump node alive at `dri/0000:00:02.0/i915_dsi_regs`; zero i915 probe errors.
- Scripts staged: `/usr/local/bin/capture_dsi_dumps.sh`, `/usr/local/bin/tcon_i2c_sweep.sh`; incoming copies retained, nothing removed.

## Session A Record (Task 2 — two runs, one boot, no suspend)

| Run | Capture sha256 | Sweep sha256 | Trace sha256 |
|-----|----------------|--------------|--------------|
| 1 | `b77d5abb…bc7b` | `28b99307…f4d0` | `f013a648…f116` |
| 2 | `7826a5be…d076` | `884388e2…3477` | `bf0f1f2a…9582` |

- Panel verdict (user eyes-on, both runs): image visible — X=Y confirmed.
- All host sha256s byte-identical to device records.

### Headline result — DCS ID reads DEAD at X=Y

Both runs, all five reads: `ret=4 avail=0 data=00 00 00` (0x04, 0xDA, 0xDB, 0xDC, GEN00). GEN_READ_DATA_AVAIL never set. The panel never answers DCS reads over this host even with the image showing — stable two-run negative. The software DCS read path cannot identify the TCON; the E3 discriminator as designed is falsified.

### I2C sweep + trace (TCON-03 raw data)

- 11 buses; SMBus i2c-10 numeric ACKs at 0x08/0x44; Goodix touchscreen on i2c-1; LPSS buses no ACKs; `line 23: unnamed output consumer=reset` GPIO hit.
- No PMIC line found by name this boot (bus 6 = gmbus dpb).
- Trace: zero i2c-core transfers during the echo-2 instrument run — no TCON sideband writes; all 4 tracepoints disabled after (`:0` verified).

## Kit Registration (Task 3)

Six files registered in `docs/dumps/re_kit/MANIFEST.sha256` (both runs), `prepare_safety_kit.sh --verify` exit 0.

## Deviations

1. Task 2 ran twice — user-requested retry after "do not see any difference"; second run byte-identical on the DCS section (stable negative, strengthens the result).
2. Retry files kept alongside run 1 with `_run2` suffix (both registered; first run's kit names preserved).
3. Task 2's re-run was executed inline by the orchestrator (pwsh ssh, `sudo -S` password via stdin) rather than a subagent, at the user's request for speed.

## Gates

`dsi_mmio_diff.sh --selftest` 52/0, `test_dsi_mmio_evidence.sh` 7/0, `test_pitfalls_ledger.sh` 4/0 — green after the fetch.

## Requirements Touched

TCON-01 (instrument deployed by CI build, captured), TCON-02 (X=Y arm captured + kit-registered; identity NOT obtainable — read path dead at boot), TCON-03 (sweep + trace archived).
