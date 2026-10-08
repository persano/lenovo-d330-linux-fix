# Project Retrospective
*A living document updated each milestone. Lessons feed forward future planning.*

## Milestone: v7.0 - Pre-Deployment Audit Remediation

**Shipped:** 2026-10-08
**Phases:** 11 | **Plans:** 15 | **Tasks:** 53 | **Sessions:** ~1 (autonomous run)

### What Was Built
- Data-loss & boot safety guards in `tools/d330-microsd-setup.sh` (explicit `--device`, three ordered pre-write guards, safe fstab writer with rollback).
- Physically-completable hibernate (disk-backed swapfile unit, install-time-rendered `resume=` cmdline) and the real PPS/display-resume DKMS module.
- Manifest-driven installer/uninstaller symmetry, desktop-session wiring (suffix-free tools, systemd **user** tablet-daemon unit), real PWM/sensor tools, activated PipeWire DSP, corrected udev/hwdb/wireless, single-writer power stack.
- A trustworthy 36-script test harness and documentation/packaging parity (`100755` exec bits, FCC hook, fail-loud packagers, `test_doc_parity.sh`).

### What Worked
- Machine-checkable guards per phase (`test_*.sh`) caught real regressions immediately (e.g. the hibernate guard failed the moment a packager rename was refactored — as designed).
- The milestone audit's independent integration checker found the one cross-phase gap the phase-level verifications could not see.

### What Was Inefficient
- Two subagent runs (planner, executor) were cancelled mid-run and had to be re-dispatched.
- Guard suites that hard-coded incidental packager line shapes broke on a legitimate refactor; guards should assert the contract (suffix-free name + `chmod 755`), not the exact implementation.

### Patterns Established
- Per-phase VERIFICATION overrides for hardware/daemon/build-only criteria, re-run at sign-off.
- `test_doc_parity.sh` as a repo-wide doc-vs-code parity gate.
- Packaging and the installer must share one exec-name contract.

### Key Lessons
1. Duplicated install logic across paths (installer + 3 packagers + CI) drifts; single-source or assert the contract in a guard.
2. A milestone audit is worth the cycle — it found a real shipped-package defect no phase SC covered.
3. Tests coupled to implementation text are liabilities; assert observable contract.

### Cost Observations
- Model mix: not measured this run.
- Sessions: 1 autonomous run.
- Notable: the slim pipeline (skip plan-checker, keep research/execute/verify) kept 11 phases moving; the audit's integration check was the highest-value single step.

---

## Cross-Milestone Trends

### Process Evolution
| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1-v6 | - | 0-31 | Iterative feature milestones (archived) |
| v7.0 | 1 | 32-42 | Audit-remediation milestone; machine-checkable guards per phase; milestone integration audit |

### Cumulative Quality
| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v7.0 | 36 guard scripts | machine-checked SCs + documented HW overrides | FCC hook, DSP graphs, user unit |

### Top Lessons (Verified Across Milestones)
1. Assertments must match reality — the v7.0 audit existed because docs/tests claimed behavior the code did not have.
2. Hardware-only criteria must be explicitly deferred, not faked green.
