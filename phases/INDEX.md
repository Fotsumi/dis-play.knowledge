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
| 9 | Release v1.0 (finish the current state) | PHASE-9.md | Signed + verified on clean machine; CI green; `--version` semver + CHANGELOG; `dis-play-tray` no-console, survives parent-cmd close | IN PROGRESS (T9.1 COMPLETE; T9.3–T9.7 COMPLETE 2026-10-16 — `1.0.0-rc` + CHANGELOG, CI green, README, installer polish, GUI-subsystem `dis-play-tray.exe`; T9.2 IN PROGRESS, blocked on R5 per D-138) |
| 10 | User Experience (tray profile mgmt, toasts, per-profile hotkeys, settings) | PHASE-10.md | Tray Save Current/rename/delete/duplicate; toasts w/ opt-out; per-profile hotkeys + conflict detection; settings persist | COMPLETE (2026-10-16 — T10.1–T10.8 implemented + `cargo test --release` 109/109 + clippy clean; all four gate items verified by user-run on target HW per `PHASE-10-CHECKLIST.md`: profile mgmt + restart, toasts/opt-out (X10.1), per-profile hotkeys/conflicts (X10.2), settings + restart persistence. D-131/D-132/D-133/D-139/D-140 FINAL) |
| 11 | Robustness (sleep/wake, hotplug, deeper recovery) | PHASE-11.md | Sleep→wake re-verification; unplug/replug live updates; auto-recover-on-startup gated; A7/A8 pass | CODE-COMPLETE (2026-10-16 — T11.1–T11.5 implemented: resume re-verify, `WM_DEVICECHANGE` live update, opt-in auto-recovery on startup, rolling recovery checkpoints, deferred identity re-validation; `cargo test --release` 121/121 + clippy clean. D-134 + D-141 FINAL. Gate — X11.1 sleep→wake/A7, X11.2 hotplug/A8, X11.3 auto-recovery — pending user-run on live HW) |
| 12 | Diagnostics, Observability & CLI Polish | PHASE-12.md | `--help` for all commands; `diagnose` 0/1 exit contract; actionable per-variant errors; `verify --verbose` | COMPLETE (2026-10-16 — T12.1–T12.5 implemented + verified on target HW: `cargo test --release` 149/149 + clippy clean; all four gate items OBSERVED: `--help` lists every command; `diagnose` exits 0 healthy / 1 unhealthy (specific reason) / 2 usage; per-variant error hints distinct (test fixture); `verify --verbose` per-display diff incl. position. D-135 FINAL) |
| 13 | Quality Automation (testing, CI matrix, property/fuzz) | PHASE-13.md | CI green full matrix; resolver property tests A1/A4/A5/A9; parser fuzz 0 crashes; no regressions | COMPLETE (2026-10-17 — T13.1–T13.5 implemented + OBSERVED: CI run `38984784843` green across `windows-2022`/`windows-2025` × debug/release + installer; 7 proptest properties A1/A4/A5/A9; cargo-fuzz 100 000 runs 0 crashes; 161/161 tests + clippy/fmt clean + zero-warning release) |
| 14 | Extensibility & Future (deferred) | PHASE-14.md | Per sub-feature D-XXX + OBSERVED/DOCUMENTED gate; re-opened non-goals re-approved in STATUS.md first | CODE-COMPLETE (2026-10-16 — re-opened on user instruction; non-goals re-approved D-144/D-146/D-147 before work; T14.1–T14.6 implemented with D-142–D-147, clippy/fmt clean, 239/240 tests. Audio set-default + service session-0 remain SPIKE/UNKNOWN) |

## Cross-phase invariants (apply to every phase)
- Every factual claim carries an evidence label (DOCUMENTED / OBSERVED / INFERRED / UNKNOWN).
- No silent overwrites of historical findings — corrections annotate with `[SUPERSEDED by <source>]`.
- `STATUS.md` is updated at the end of every working session.
- Product source changes happen in `product/` only; this repo never tracks them.
