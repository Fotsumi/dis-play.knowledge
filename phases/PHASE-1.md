# Phase 1 — Identity & Resolver

## Objective
Turn Phase 0 evidence into a pure-Rust identity model + resolver that, given a `binding_policy` (`Auto`/`Physical`/`Connector`) per entry, returns the correct candidate. No Windows calls in this phase's logic (pure functions over captured state).

## Scope
- In: `DisplayEntry` model with `binding_policy`; resolver mapping policy → candidate; unit tests over recorded Phase 0 fixtures.
- Out: persistence, apply, UI (later phases).

## Tasks
| # | Task | Output |
|---|---|---|
| T1.1 | `model/candidate.rs` — DisplayCandidate + DisplayEntry with binding_policy | pure Rust types |
| T1.2 | `core/resolver.rs` — policy → candidate resolution | pure fn, unit-tested |
| T1.3 | Unit tests over Phase 0 captured fixtures (E1–E4 data) | passing tests |

## Gate
- [ ] Resolver returns correct candidate for each binding_policy on recorded HW state. **OBSERVED** (fixtures from Phase 0)
- [ ] Unit tests pass; no Windows calls in resolver logic. **DOCUMENTED** (code review)

## Potential Blockers
- Depends on D-P1/D-P2 being FINAL (Phase 0 gate). If binding model is still PENDING-EVIDENCE, this phase cannot start.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 0_

## Status
**BLOCKED by Phase 0.**
