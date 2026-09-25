# Phase Index — DIS-PLAY

Operational phase docs live here. Each `PHASE-N.md` records: objective, scope, tasks, experiments/tests, expected evidence, **gate (completion criteria)**, potential blockers, decisions produced, actual results, follow-up changes required, status.

A phase is complete only when its gate is satisfied with at least one OBSERVED or DOCUMENTED item per criterion (see root `AGENTS.md` — Phase Execution Rules).

| # | Phase | Doc | Gate summary | Status |
|---|---|---|---|---|
| 0 | Evidence Spike (diagnostic CLI) | PHASE-0.md | Identity mapping table with stable IDs across reboot/driver-update; primary = path-priority confirmed on real HW | COMPLETE |
| 1 | Identity & Resolver | PHASE-1.md | Resolver returns correct candidate for each binding_policy (Auto/Physical/Connector) | COMPLETE |
| 2 | Capture + Persistence | PHASE-2.md | Profile round-trips through save/load | COMPLETE |
| 3 | Apply (`apply_profile`) | PHASE-3.md | `apply_profile` applies and verifies topology | COMPLETE |
| 4 | Verification & Recovery | PHASE-4.md | Verify + recovery paths exercised on real HW | COMPLETE |
| 5 | Tray Application | PHASE-5.md | Tray app runs; menu drives apply | COMPLETE |
| 6 | Hotkeys | PHASE-6.md | Hotkeys registered + fired | BLOCKED by 5 |
| 7 | Hardening | PHASE-7.md | Error handling, logging, packaging complete | BLOCKED by 6 |

## Cross-phase invariants (apply to every phase)
- Every factual claim carries an evidence label (DOCUMENTED / OBSERVED / INFERRED / UNKNOWN).
- No silent overwrites of historical findings — corrections annotate with `[SUPERSEDED by <source>]`.
- `STATUS.md` is updated at the end of every working session.
- Product source changes happen in `product/` only; this repo never tracks them.
