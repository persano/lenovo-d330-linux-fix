---
phase: "50"
slug: "tcon-identification-dcs-id-read-instrument-software-only"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-10-17"
---

# Phase 50 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| root shell → debugfs write handler | untrusted bytes written to the `i915_dsi_regs` node by any root-capable process; the new echo-2 value parse must not widen what the node accepts | user-controlled write buffer → kernel parse |
| debugfs node → userspace readers | raw MMIO + DCS bytes exposed via `cat` (info-leak surface if perms wrong) | kernel snapshot buffer → root userspace |
| repo patches → CI kernel build | a widened patch silently changes the measured system | committed `.patch` → built `linux-image` deb |
| capture script → debugfs node | root shell writes the trigger; a wedged kernel read must not hang the session | `echo 2` via timeout-wrapped ssh/stdin |
| device dumps → diff tooling | untrusted-format output files feed a parser; format drift must fail loudly | dump text → awk parser classification |
| sweep probes → live I2C buses | `i2cdetect -y` probes addresses on live adapters (incl. PMIC/gmbus buses) | quick-write probes → live bus |
| deploy upload → device dpkg | a clobbered/mismatched rollback asset destroys the recovery path | scp'd deb + sha256 → device `/home/santiago` |
| device sessions → sudo credential | scripted sudo over ssh; password must never persist in repo files | password on stdin only |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-50-01 | Tampering (input) | `d330_dsi_dump_write` value parse | medium | mitigate | `kstrtouint_from_user` bounded parse (`d330_dsi_dump.patch:423`); `trigger > 2 → -EINVAL` (:427-428); `mutex_trylock` → `-EBUSY` re-entry discipline retained (:433-434); node stays `debugfs_create_file(..., 0600, ...)` (:389) | closed |
| T-50-02 | Denial of Service | DCS reads with DSI PLL off | medium | mitigate | `d330_dsi_dump_id_reads(display, dsi_ok)` gated on the walk's existing `bxt_dsi_pll_is_enabled` check; `!dsi_ok` → `DCS SKIP pll-off` + return before any FIFO access (`d330_dsi_dump.patch:241-249`) | closed |
| T-50-03 | Denial of Service | hanging DSI read wedging a trigger | medium | mitigate | kernel RX path reuses bounded `GEN_READ_DATA_AVAIL` waits (existing `intel_dsi_host_transfer`); userspace: `timeout -k 5 15 sh -c "echo 2 > '$NODE'"` (`capture_dsi_dumps.sh:205`), failure exits non-zero with captured stderr | closed |
| T-50-SC | Tampering | npm/pip/cargo installs | high | mitigate | no registry installs this phase: grep over all 30 phase-changed files finds no npm/pip/cargo/apt install execution; `tcon_i2c_sweep.sh` degrades honestly to sysfs-only when i2cdetect/libgpiod absent (:94, :135 — informational hint only, not executed); device tools are Ubuntu archive packages | closed |
| T-50-04 | Denial of Service | echo-2 trigger on a wedged link | medium | mitigate | `timeout -k 5 15` wrap on the trigger in both echo-2 arms (`capture_dsi_dumps.sh:201-207`); non-zero exit + stderr; kernel side bounded too (T-50-03) | closed |
| T-50-05 | Repudiation | diff format drift misclassifying evidence | medium | mitigate | DCS rows are distinct DH/D/DK parser kinds (`dsi_mmio_diff.sh:163-174`); selftest fixtures J-M pin classification (:751-854); determinism fixture E guards byte-stability; selftest 52/0 | closed |
| T-50-06 | Denial of Service | `i2cdetect -y` probing live adapters | low | mitigate | default quick-write probes only (`tcon_i2c_sweep.sh:15-16`); every probe fenced with `|| true` (:104, :116, :124, :130-131); dead bus archived, sweep continues; one sweep per arm, no loop | closed |
| T-50-07 | Repudiation | §6 mislabel surviving into Phase 53 hand-off | medium | mitigate | bit-accurate 0x6b004 decode at `DSI_MMIO_DIFF.md:370` (all four bit positions explicit, LP_RX_TIMEOUT bit 22 NOT set); evidence gate `test_dsi_mmio_evidence.sh` 7/0 + ledger gate 4/0 re-run after edits | closed |
| T-50-08 | Tampering | scope widening beyond the 0x6b004 row | low | mitigate | §4.2 and RESUME_FIX_LEDGER.md untouched (50-03-SUMMARY diff-verified; 50-VERIFICATION.md:77 "no contradicting changes found"); only §6 rows changed | closed |
| T-50-09 | Tampering | deploy clobbering the rollback asset | high | mitigate | rollback sha-verified on device BEFORE dpkg (`deploy_d330_kernel.sh:143-169`, missing/mismatch = hard fail); distinct incoming name `deploy_incoming_<sha12>.deb` (:203); uploaded deb re-sha-verified on device before `dpkg -i` (:209-219); "There is no `rm` anywhere in this file" (:18, verified by grep); incoming deb kept after install (:202); rollback reminder always printed (:254) | closed |
| T-50-10 | Information Disclosure | sudo credential leakage over ssh | medium | mitigate | scripted-sudo stdin only: `PW` sourced from env or `IFS= read -r` (:184-195), piped to `sudo -S` (:223, :232); rollback reminder prints the placeholder `'<device-sudo-password>'` (:115-116); grep of every file committed this phase finds no password literal — only `sudo -S ... via stdin` narrative in 50-04/50-05-SUMMARY. Carried-forward context: pre-existing phase-48 scripts are out of this phase's delta | closed |
| T-50-11 | Repudiation | evidence fetch mismatch | medium | mitigate | "Host sha256s byte-identical to device records" (50-05-SUMMARY:27); per-file sha256 in TCON_IDENTIFICATION.md provenance table; `prepare_safety_kit.sh --verify` round-trip exit 0 over all 9 tcon artifacts (`sha256sum -c MANIFEST.sha256`, prepare_safety_kit.sh:149) | closed |
| T-50-12 | Repudiation | tracepoints left enabled after the session | low | mitigate | runbook step 5 disables all four + archives trace (50-04-PLAN:135, 50-05-PLAN:100); post-session check executed: "all 4 tracepoints disabled after (`:0` verified)" (50-04-SUMMARY:48) | closed |
| T-50-13 | Repudiation | verdict substitution in the doc | high | mitigate | user eyes-on verdicts recorded verbatim ("image visible" X=Y ×2; "screen lit but black" X=Z — 50-04/50-05-SUMMARY); machine evidence agrees with no divergence to reconcile; verdict quotes per-read matrix verbatim (TCON_IDENTIFICATION.md:11-18) | closed |
| T-50-14 | Repudiation | over-claim from kernel-era-only I2C traces | medium | mitigate | PARTIAL: time-window scoping present ("during the echo-2 instrument run", "during wake-to-capture", TCON_IDENTIFICATION.md:42); the declared **mandatory** "pre-kernel GOP blind spot" sentence is ABSENT (50-VERIFICATION.md:137 confirms) | open — below high threshold (non-blocking) |
| T-50-15 | Denial of Service | blind invocation wedging the black-resume session | medium | mitigate | resume2 trigger timeout-wrapped (`capture_dsi_dumps.sh:205` covers both echo-2 arms); worst case = loud non-zero failure with captured stderr, session never hangs | closed |
| T-50-16 | Repudiation | identity over-claim from MEDIUM-confidence fingerprints | medium | mitigate | dead-path branch fired: zero ID bytes captured (`avail=0` ×15 across 3 runs), so no fingerprint matching occurred and no name was forced; verdict states identity NOT obtainable (TCON_IDENTIFICATION.md:9); candidate list stays "open, gated on Phase 53" (:23); the A1-caveat clause applies only to the unmatched-ID branch (50-05-PLAN:175-176), which never fired | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-17 | 17 | 16 | 1 (non-blocking) | gsd-security-auditor |

Notes:
- T-50-SC is declared identically in all five plan registers; counted once.
- The one open threat (T-50-14, medium) is below the `block_on: high` gate: tracked, does not block ship. One-line fix: add the explicit pre-kernel GOP I2C blind-spot sentence (needs Phase 53 hardware) to TCON_IDENTIFICATION.md's I2C conclusion.
- Carried-forward (pre-existing, not this phase's delta): sudo password presence in legacy phase-48 deploy scripts — out of scope for phase-50 verification; phase-50 files are clean.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-10-17
