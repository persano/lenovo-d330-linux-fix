# Phase 38: PipeWire DSP Activation - Validation

**Validated:** 2026-10-08 | **Result:** READY (slim pipeline, no plan-checker)

| Item | Verdict | Evidence |
|------|---------|----------|
| Goal well-formed | PASS | ROADMAP `### Phase 38`; SC1 (nodes loaded, hardware) + SC2 (missing plugin non-zero, machine-checkable) |
| Scope bounded | PASS | 2 conf files + installer + 2 tests + README + CHANGES_AUDIT §4.3 |
| Placement correctness | PASS | PipeWire `pipewire.conf.d` vs `filter-chain.conf.d` is documented behaviour (R1) |
| SC2 testable here | PASS | `D330_LADSPA_DIRS` seam -> fake present = rc 0, absent = rc 1 |
| Risk: SC1 needs daemon | MED | Scoped as a hardware override (like 33/34/36); machine half = static graph validation + files under pipewire.conf.d |
| Risk: routing claim | LOW | Downgrade §4.3 to honest "virtual sink, select to route"; no untested wireplumber config |
| Data loss / irreversible | NONE | Config/docs only |

**Requirement coverage:** no REQUIREMENTS.md -> SC-based frontmatter (SC1 nodes loaded; SC2 missing-plugin non-zero).
**Blockers:** none.
