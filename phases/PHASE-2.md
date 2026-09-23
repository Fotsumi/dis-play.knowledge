# Phase 2 — Capture + Persistence

## Objective
Capture the current display state into a serializable profile and round-trip it through save/load, so `apply_profile` (Phase 3) has something to apply.

## Scope
- In: capture current topology → `Profile`; serialize/deserialize; store under user profile dir.
- Out: applying the profile (Phase 3), verification (Phase 4).

## Tasks
| # | Task | Output |
|---|---|---|
| T2.1 | Capture current state via resolver output → `Profile` struct | capture fn |
| T2.2 | Serialize/deserialize (serde) + file I/O under `%LOCALAPPDATA%` | round-trip |
| T2.3 | Round-trip test: capture → save → load → equal | passing test |

## Gate
- [ ] Profile round-trips through save/load without loss. **OBSERVED** (test run)
- [ ] Schema stable across a reboot (no field drift). **OBSERVED**

## Potential Blockers
- Depends on Phase 1 resolver being correct. If capture produces wrong candidates, persistence is meaningless.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 1_

## Status
**BLOCKED by Phase 1.**
