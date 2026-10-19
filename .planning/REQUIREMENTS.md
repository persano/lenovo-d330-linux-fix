# REQUIREMENTS: Milestone v12.0 — Boot the Other OSes

Scoped 2026-10-19. Numbering continues from v11.0 (REL-01/02, AUDIT-01/02
exhausted); BLIS and CHRM are new categories.

## v1 Requirements

### BlissOS kernel + boot
- [ ] **BLIS-01**: A GitHub Actions workflow builds the BlissOS kernel from BlissRoms `kernel_common` with the GLK + CCS patches applied, and publishes the `bzImage` as a build artifact.
- [ ] **BLIS-02**: The build fails loudly (job red) if either patch fails to apply — an unpatched kernel is never published as an artifact.
- [ ] **BLIS-03**: BlissOS boots on the reference D330 from a USB stick with the patched kernel — panel lights up, orientation correct (user eyes-on verdict).
- [ ] **BLIS-04**: At least one suspend/resume cycle on BlissOS keeps the panel lit (user eyes-on verdict).

### ChromeOS kernel + boot
- [ ] **CHRM-01**: A GitHub Actions workflow builds the `chromeos-6.6` kernel with the same two patches and publishes the kernel artifact.
- [ ] **CHRM-02**: If the ChromeOS build exceeds the runner's disk or time limits, the job fails with a documented stop — no truncated or fake artifacts, ever.
- [ ] **CHRM-03**: ChromeOS boots on the reference D330 from a USB stick with the patched kernel — panel lights up (user eyes-on verdict).
- [ ] **CHRM-04**: Suspend/resume verified eyes-on on ChromeOS.

### Release + regression guard
- [ ] **REL-03**: A `v12.0` release carries both built kernels plus `SHA256SUMS` and step-by-step USB-writing instructions for each OS.
- [ ] **AUDIT-03**: CI re-verifies both patches apply clean (`git apply --check`) against freshly fetched tree sources at build time.

## Future Requirements (deferred)

- Fedora/Arch installer verification on real hardware (v11.0 leftover, needs such hardware).
- BlissOS full-ISO rebuild with integrated kernel (kernel-swap-into-stock-ISO is this milestone's path; a full OS build is 6-8 h + 350 GB, out of scope).

## Out of Scope

- Installing either OS on the D330's internal disk — every boot test is USB-only; internal Kubuntu/Windows layout untouched (user decision, 2026-10-19).
- Linux (kernel) display work — the fix shipped in v11.0; nothing here re-opens it.
- Upstream comment posting on #13225/#17401 — user-paste item, not buildable work.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BLIS-01 | Phase 57 | Pending |
| BLIS-02 | Phase 57 | Pending |
| AUDIT-03 | Phase 57 | Pending |
| BLIS-03 | Phase 58 | Pending |
| BLIS-04 | Phase 58 | Pending |
| CHRM-01 | Phase 59 | Pending |
| CHRM-02 | Phase 59 | Pending |
| CHRM-03 | Phase 60 | Pending |
| CHRM-04 | Phase 60 | Pending |
| REL-03 | Phase 61 | Pending |
