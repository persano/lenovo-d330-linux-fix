# Phase 34: PPS/Display Resume Fix — Validation Strategy

**Created:** 2026-10-08 (plan-phase; slim pipeline — no separate pattern-mapper, analogs folded into planner prompt)
**ASVS level:** 1, **block on:** high (workflow.security_enforcement active)

## Security Validation

| Threat | Mitigation / validation |
|---|---|
| Optional kernel-source patch corrupts a kernel tree (high) | `patch -p1 --dry-run` must pass before real apply; apply only to the tree the user explicitly passed via `--kernel-src`; loud `[WARN]` + skip on context mismatch; never applied implicitly |
| Installer runs arbitrary patch content as root | patch ships in-repo (trusted), applied with `--dry-run` gate; no `eval`, no network fetch |
| DKMS build failure bricks module install | `MAKE_MATCH[0]` + `BUILT_MODULE_LOCATION[0]` guards; build failure warns, install continues (existing posture) |
| False advertising (audit root cause) | README/CHANGES_AUDIT claims must be statically asserted against shipped files by suite cases; no "work reliably" guarantee language |
| Deleting resume service breaks install symmetry | removal touches copy/enable/disable/rm in installer + postinst + spec + docs; suite asserts zero stale references |

Blocking: any **high** finding blocks the phase; medium → fix in code review.

## Functional Validation

1. Static gates: `bash -n` touched shell files; `patch --dry-run` self-test against a fabricated context fixture (proves the gate mechanics without a kernel tree); `gcc -fsyntax-only` or `make -n` for the module if toolchain present (else source-level asserts).
2. Suite (extend `scripts/test_resume_loop.sh` bug fix + new static cases in a repo-consistent suite): PM handler no longer has the dead `elapsed < 600ms` post-suspend sleep; honest banner string present; `video=efifb:nobgrt` decision asserted (research: real efifb option → KEEP, roadmap premise disproven — deviation recorded); CHANGES_AUDIT §2.2 claims match shipped grub.d content; README option descriptions match shipped behavior (grep-asserted anchors); resume-service zero-reference sweep; Makefile/dkms.conf keys present; `--kernel-src` dry-run-first ordering asserted.
3. `scripts/test_resume_loop.sh` SC2 bug: `((passed++))` under `set -e` aborts at cycle 1 (research-verified) — fix so 5 cycles run; in this environment real suspend cycles are impossible → dry-run/CI path must run 5 simulated cycles, physical loop deferred to UAT.
4. Existing gates stay green: `test_hibernate_guards.sh` 21/0, `test_storage_cellular.sh --dry-run` rc=0.

## On-Target / Human Acceptance (deferred → VERIFICATION overrides)

- SC1: `dmesg | grep lenovo_d330_fix` DMI match on hardware.
- SC2: physical `scripts/test_resume_loop.sh` 5 real suspend/resume cycles with the clamp Option 2 applied.
- Actual panel TCON behavior after the honest-banner module change (no more dead sleep).
