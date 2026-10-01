# Phase 12 — Diagnostics, Observability & CLI Polish

## Objective

Make the app **easy to diagnose when something goes wrong** and easy to use.

**User value:** when a switch misbehaves, the user (or support) can run one command and get a clear answer, plus readable logs and detailed verification diffs.

**Release it maps to:** v1.3.

## Origin (why this phase exists)

Gap analysis (`ROADMAP.md` §3, rows 8–9): there is **no diagnostics command**, no `--help`/`--version` (`product/src/main.rs` is CLI dispatch only), no verbose verification output; and log ops are a dated append log (T7.1) with no viewer, no rotation/size cap, and no level config.

## Scope

- **In:** `--help`/`-h` + `--version` (T12.1); actionable error messages (T12.2); `diagnose` command (T12.3); verbose verification (T12.4); log ops (T12.5).
- **Out:** profile management / notifications / hotkeys / settings (Phase 10); robustness (Phase 11); quality automation (Phase 13); extensibility (Phase 14).

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T12.1 | **`--help` / `-h`** (all commands) and **`--version`** (semver) | CLI flags | **PLANNED** |
| T12.2 | **Actionable error messages:** map `Error::*` (e.g. `NoTargets`, `Ambiguous`, `ModeUnavailable`) to human hints ("display X missing — plug it in or remove it from the profile") | error → hint mapping | **PLANNED** |
| T12.3 | **`diagnose` command** (health check, **read-only**): identity-evidence quality per display, hotkey registration state, autostart state, config sanity, log tail; exit 0/1 | `diagnose` subcommand | **PLANNED** |
| T12.4 | **Verbose verification:** surface per-display desired-vs-actual findings (already computed internally as the `finding(s)` count) | `verify --verbose` output | **PLANNED** |
| T12.5 | **Log ops:** `logs` subcommand (tail/view), rotation/size cap, level config (`DEBUG/INFO/WARN`) | `logs` subcommand + config | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):** T12.2 = pure mapping over the existing `error.rs` (structure OBSERVED). T12.3 reads existing state only — **no `SetDisplayConfig`** (D-002 read-only invariant, safe). T12.4 reuses `core/verify` findings (OBSERVED); CLI formatting only. T12.5 file ops (OBSERVED log dir); level = config key.

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [ ] `--help` lists every command with a one-line description (OBSERVED).
- [ ] `diagnose` exits 0 on a healthy machine, 1 with a specific reason on an unhealthy one; exit codes stable for scripting (OBSERVED).
- [ ] Every `Error` variant produces a distinct, actionable message (OBSERVED via test fixture).
- [ ] `verify --verbose` lists per-display mismatches (resolution/refresh/rotation/position) (OBSERVED).

## Potential Blockers / Open Questions

- **Read-only invariant (D-002):** keep `diagnose` **strictly read-only** — no `SetDisplayConfig` in any diagnostic path.
- **Exit-code contract:** 0 healthy / 1 unhealthy / 2 usage should be documented and frozen for automation (D-135).

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-135 | `diagnose` exit-code contract (0/1/2) and read-only guarantee | **PENDING** (reserved 2026-09-26, not yet decided; T12.3) |

## Actual Results

None — no tasks executed yet. Per user instruction (2026-09-26), documentation only: no new task or phase was executed.

## Status

**PLANNED (not started, 2026-09-26)** — tasks T12.1–T12.5 detailed from `ROADMAP.md` §4. D-135 reserved but undecided. No code executed.
