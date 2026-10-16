# 48-02 Task 1 Progress: Deploy script with rollback guard

## What was built

`scripts/deploy_d330_kernel.sh` (POSIX `#!/bin/sh`, 238 lines) — host-side deploy
of a CI-built kernel .deb to `santiago-D330` with an unbreakable rollback guard:

1. local deb sha256 verify (BEFORE any ssh)
2. on-device rollback asset verify (exists + sha equals the recorded constant;
   simulated locally via `DRY_RUN=1` + `D330_FAKE_ROLLBACK_SHA`)
3. scp deb to `/home/santiago/<basename>`
4. device-side re-verify of the uploaded copy (scp-corruption guard)
5. `dpkg -i` via scripted sudo (password piped into `ssh … "sudo -S -p '' …"` stdin only)
6. reboot + wait for ssh (up to 300 s), then print the rollback command reminder

Failure at ANY sha step exits non-zero before install; the rollback deb is never
removed/moved/overwritten (no `rm` exists anywhere in the script); no curl|sh.

## Rollback constant (captured live from the device 2026-10-14)

```
ROLLBACK_DEB = /home/santiago/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb
ROLLBACK_SHA = 20dc04db5dab7066333e2382896af43cf50622276b9d8f62c75d3d92a2839e91
```

Device read: `ssh santiago-D330 sha256sum` → matches the repo record
(docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md:155, 47-03-SUMMARY.md). Full sha
recorded as the in-script constant (not just the 20dc04db…9e91 prefix).

## Credential handling (stronger than the plan's grep criterion)

The password appears NOWHERE in the script (zero occurrences — the grep criterion
"no plaintext password outside the stdin pattern" passes trivially and strictly).
Read at runtime from `D330_SUDO_PW` (env, recommended for the task-2 scripted
run), else hidden stty prompt, else one stdin line; piped only into ssh stdin.
Never echoed, never written to any file.

## Test evidence (all local, zero device side effects)

Failure paths run via `bash <tmp>/test_deploy_paths.sh` (ssh/scp shimmed out;
shim also mimics `sha256sum` with a controlled fake sha for real-mode paths):

- 14/14 cases passed, final line: `deploy-script local tests: passed=14 failed=0`
- local deb missing → rc=1; bad sha format → rc=1; local sha mismatch → rc=1
  BEFORE any ssh (shim log empty on those paths)
- rollback missing (DRY_RUN sim) → rc=1; rollback sha mismatch (sim) → rc=1
- real-mode rollback missing / mismatch (fake remote sha) → rc=1, password never
  read, no scp/dpkg in shim log
- empty-password guard → rc=1 after rollback OK, no dpkg in shim log
- DRY_RUN pass path → rc=0, `no device changes were made`; uppercase sha tolerated
- shim argv logs prove ordering: rollback verify precedes password/scp; dpkg
  unreachable when any check fails
- `sh -n scripts/deploy_d330_kernel.sh` → OK syntax

## Ledger gate status: PRE-EXISTING RED (not this task's change)

`bash scripts/test_pitfalls_ledger.sh` exits 1 — and exited 1 identically at
HEAD before this task started. A/B proof: gate re-run with this task's script
removed from the tree → same 3/4, `[FAIL] pristine-tree-passes`. The script is
not in the gate's scan set at all (scan = *-PLAN.md/*-SUMMARY.md + docs/research).

Sole cause: `.planning/phases/48-clean-dmi-gated-fix-mmio-guided/48-01-SUMMARY.md`
lines 55/59/60/75 — its Deviations section QUOTES the lever aliases
(`intel_dsi_post_disable`, `0x160018`, `panel power cycle`, `glk_cold_boot`) and
its `planner-discipline-allow` markers do not cover its own text (committed red
in 5d53f26). Not fixed here: it is another plan's committed artifact and the
exact per-string marker choice belongs to its author/orchestrator. Suggested
remedy: append per-string markers to 48-01-SUMMARY.md (e.g. allow:
`intel_dsi_post_disable`, `0x160018`, `panel power cycle`, `glk_cold_boot`) as a
docs commit, then re-run the gate.

## Deviations from plan

1. [Rule 2, minor] Added step 4 (device-side sha re-verify of the scp'd deb
   before dpkg -i). Plan named only the local verify; the threat model lists
   "flashing an unverified image" — this closes the scp TOCTOU gap. 3 lines.
2. [Rule 2, strengthening] Password read at runtime instead of the embedded
   `echo 'Persano2949'` convention: writing the password into the script file
   would violate the "never write the password to a file" rule. The stdin-only
   usage pattern (`printf '%s\n' "$PW" | ssh … "sudo -S -p '' …"`) is preserved
   verbatim at the call sites.
3. Pre-existing ledger-gate red documented above (out of scope, not auto-fixed).

## Notes for task 2 (orchestrator)

- Script usage: `bash scripts/deploy_d330_kernel.sh <local-deb> <expected-sha256>`
  with `D330_SUDO_PW` set (scripted run) — or without it for the hidden prompt.
- File is written but NOT staged: orchestrator handles staging + the 100755
  mode bit at commit time.
- No commits made (deferred-commit mode). Planned commit for /gsd-ship:
  `feat(48-02): sha-verified deploy script with rollback guard` — files:
  scripts/deploy_d330_kernel.sh
