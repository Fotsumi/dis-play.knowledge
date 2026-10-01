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
| 6 | Hotkeys | PHASE-6.md | Hotkeys registered + fired | COMPLETE |
| 7 | Hardening | PHASE-7.md | Error handling, logging, packaging complete | COMPLETE |
| 8 | Mode & Position Preservation | PHASE-8.md | Re-enabling a previously-disabled monitor restores its captured res/refresh/orientation/position; apply persists to the display database | COMPLETE (gate validated on HW 2026-09-26: disable→re-enable restores captured config incl. position; reboot persistence confirmed; 56/56 tests, clean release) |
| 9 | Release v1.0 (finish the current state) | PHASE-9.md | Signed + verified on clean machine; CI green; `--version` semver + CHANGELOG; `dis-play-tray` no-console, survives parent-cmd close | PLANNED |
| 10 | User Experience (tray profile mgmt, toasts, per-profile hotkeys, settings) | PHASE-10.md | Tray Save Current/rename/delete/duplicate; toasts w/ opt-out; per-profile hotkeys + conflict detection; settings persist | PLANNED |
| 11 | Robustness (sleep/wake, hotplug, deeper recovery) | PHASE-11.md | Sleep→wake re-verification; unplug/replug live updates; auto-recover-on-startup gated; A7/A8 pass | PLANNED |
| 12 | Diagnostics, Observability & CLI Polish | PHASE-12.md | `--help` for all commands; `diagnose` 0/1 exit contract; actionable per-variant errors; `verify --verbose` | PLANNED |
| 13 | Quality Automation (testing, CI matrix, property/fuzz) | PHASE-13.md | CI green full matrix; resolver property tests A1/A4/A5/A9; parser fuzz 0 crashes; no regressions | PLANNED |
| 14 | Extensibility & Future (deferred) | PHASE-14.md | Per sub-feature D-XXX + OBSERVED/DOCUMENTED gate; re-opened non-goals re-approved in STATUS.md first | PLANNED (deferred) |

## Cross-phase invariants (apply to every phase)
- Every factual claim carries an evidence label (DOCUMENTED / OBSERVED / INFERRED / UNKNOWN).
- No silent overwrites of historical findings — corrections annotate with `[SUPERSEDED by <source>]`.
- `STATUS.md` is updated at the end of every working session.
- Product source changes happen in `product/` only; this repo never tracks them.
