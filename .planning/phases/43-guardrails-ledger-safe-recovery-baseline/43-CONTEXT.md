# Phase 43: Guardrails, Ledger & Safe Recovery Baseline - Context

**Gathered:** 2026-10-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Everything is safe and shippable before any risky kernel experiment: consolidate the 22 on-device-disproven levers plus community/upstream dead ends into one machine-checkable ledger (`docs/research/RESUME_FIX_LEDGER.md` + `scripts/test_pitfalls_ledger.sh` gate), stage the off-device safety kit and document the black-resume-vs-working-reload capture protocol, and harden + package the proven seamless recovery (DMI-gated, timeout-bounded i915 unbind/bind + display-manager restart) through the installer, all three packagers and the CI `.deb`, manifest-symmetric, idempotent, disable-able and non-conflicting with the real fix.

</domain>

<decisions>
## Implementation Decisions

### Ledger + Machine Gate
- Consolidate the 22 disproven levers from `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `DSI_RESUME_TRACE_ANALYSIS.md` and `COMMUNITY_FINDINGS.md` into one `RESUME_FIX_LEDGER.md` with per-lever evidence links.
- `test_pitfalls_ledger.sh` scans `.planning/phases/*/*.md` (plans, summaries) plus `docs/research/*.md` for banned-lever mentions in fix-proposal context.
- The ledger carries a canonical lever name + alias regex table per lever; the test parses the table and matches text — keywords live in the ledger, not the test.
- Wire the new test into the existing 36-script harness (`test_storage_cellular.sh` + `bash -n` loop) per house pattern.

### Safety Kit + Capture Protocol
- Repo-side automation now (prep/checksum scripts + protocol doc + runbook); golden `i915.ko.zst`, live USB and VBT/GOP dump are on-device runbook steps executed at deployment (repo has no hardware access).
- Protocol doc at `docs/research/RESUME_CAPTURE_PROTOCOL.md`: black-resume vs working-reload, no cold-boot control, `systemd-inhibit`, full ≥18 s window, journald + captures.
- Live USB reuses the `scripts/build_live_iso.sh` harness; runbook step = build + dd + verify against manifest checksums.
- Kit integrity: SHA-256 per artifact + one `MANIFEST.sha256`, verified by a new test script; scripts idempotent (safe re-run).

### Recovery Hardening
- Harden the existing `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` hook (already DMI-gated, timeout-bounded, state-file disable) — no new service unit.
- One bounded attempt (existing `timeout 30`), explicit failure logging, no retry loop (a retry can wedge the GPU mid-resume).
- Keep the display-manager restart; the live Wayland session cannot survive the GPU teardown, so logging back in is the accepted bar.
- DMI gate stays exact `product_name == "82H0"` (10IGL test device only); 10IGM (81H3/81MD) is out of scope.

### Packaging, Manifest, Disable & Coexistence
- Keep `/etc/default/lenovo-d330-display-resume` (`D330_DISPLAY_RESUME=0`) as the state file and add it to `deploy_manifest()` so `--verify` and uninstall treat it as a state-class entry.
- The recovery ships through `install_dkms.sh` + all three packagers (`packaging/debian/rules`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec`) + the CI `.deb`; packagers mirror the installer's manifest set.
- Non-fighting contract: the hook stands down when the real fix (Phase 45) writes a marker (e.g. `D330_REAL_FIX=1`) into the same state file; the contract is documented now, Phase 45 sets it.
- Extend `test_installer_symmetry.sh` fixtures + packager-parity tests to assert hook + state file install/uninstall/verify symmetry.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `deploy_manifest()` single-source-of-truth in `scripts/install_dkms.sh` with `--verify` / `--dump-manifest` / `--removed` modes (installer symmetry machinery).
- Proven recovery hook: `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` — DMI gate, timeout-bounded reload, DM restart, disable file already implemented.
- 36-script test harness pattern (failure counters, `--apply` gating, meta-guard) wired in `scripts/test_storage_cellular.sh`.
- Packagers: `packaging/debian/{control,rules,postinst}`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec`; CI `.deb` in `.github/workflows/build-packages.yml`.
- Ledger source material: `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` (18 KB), `DSI_RESUME_TRACE_ANALYSIS.md` (12 KB), `COMMUNITY_FINDINGS.md` (9 KB).

### Established Patterns
- system-sleep hooks under `patches/<area>/etc/systemd/system-sleep/` installed by the installer (touchscreen/wifi/display precedents).
- `scripts/test_*.sh` guards with case functions, fail-loud, no env-var success claims.
- Manifest kinds distinguish always-present vs conditional/state artifacts; verify reports SKIP for absent conditionals.

### Integration Points
- `deploy_manifest()` line list — new hook + state-file entries land here and are consumed by install/uninstall/verify.
- `scripts/test_storage_cellular.sh` — new ledger + kit tests wire into the harness runner.
- `packaging/*/` rules/spec — hook + state file additions mirror installer set.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Anchors from the roadmap: the recovery is the *proven* mechanism (only a full i915 unbind/bind reload recovers the panel), so Phase 43 hardens and ships it as-is rather than redesigning it; the clean resume fix is Phase 45's job and the hook must not fight it.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
