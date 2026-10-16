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
| T12.1 | **`--help` / `-h`** (all commands) and **`--version`** (semver) | CLI flags | **COMPLETE** |
| T12.2 | **Actionable error messages:** map `Error::*` (e.g. `NoTargets`, `Ambiguous`, `ModeUnavailable`) to human hints ("display X missing — plug it in or remove it from the profile") | error → hint mapping | **COMPLETE** |
| T12.3 | **`diagnose` command** (health check, **read-only**): identity-evidence quality per display, hotkey registration state, autostart state, config sanity, log tail; exit 0/1 | `diagnose` subcommand | **COMPLETE** |
| T12.4 | **Verbose verification:** surface per-display desired-vs-actual findings (already computed internally as the `finding(s)` count) | `verify --verbose` output | **COMPLETE** |
| T12.5 | **Log ops:** `logs` subcommand (tail/view), rotation/size cap, level config (`DEBUG/INFO/WARN`) | `logs` subcommand + config | **COMPLETE** |

**API / feasibility notes (from `ROADMAP.md` §4):** T12.2 = pure mapping over the existing `error.rs` (structure OBSERVED). T12.3 reads existing state only — **no `SetDisplayConfig`** (D-002 read-only invariant, safe). T12.4 reuses `core/verify` findings (OBSERVED); CLI formatting only. T12.5 file ops (OBSERVED log dir); level = config key.

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [x] `--help` lists every command with a one-line description (OBSERVED).
- [x] `diagnose` exits 0 on a healthy machine, 1 with a specific reason on an unhealthy one; exit codes stable for scripting (OBSERVED).
- [x] Every `Error` variant produces a distinct, actionable message (OBSERVED via test fixture).
- [x] `verify --verbose` lists per-display mismatches (resolution/refresh/rotation/position) (OBSERVED).

## Potential Blockers / Open Questions

- **Read-only invariant (D-002):** keep `diagnose` **strictly read-only** — no `SetDisplayConfig` in any diagnostic path.
- **Exit-code contract:** 0 healthy / 1 unhealthy / 2 usage should be documented and frozen for automation (D-135).

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-135 | `diagnose` exit-code contract (0/1/2) and read-only guarantee | **FINAL** (decided 2026-10-16, T12.3) |

## Actual Results

**Phase 12 COMPLETE (2026-10-16, target HW, OBSERVED for build/test + CLI runs).** All five tasks implemented in `product/`; `cargo test --release` → **149/149**, `clippy --all-targets --all-features -- -D warnings` clean, `cargo build --release` clean.

- **T12.1** (product commit `64cd108`): new `product/src/cmd/help.rs` (`COMMANDS` table + `render()`/`print_help()`), `cmd/mod.rs` registered, `main.rs` `--help`/`-h`/`help` arm + a fallback hint; `--version`/`-V`/`version` → `dis-play 1.0.0-rc`. **OBSERVED:** `--help` lists every command with a one-line description.
- **T12.2** (product commit `f72bd1a`): `Error::hint() -> String` + `Error::render()` in `src/error.rs`; `main.rs` prints a `hint:` line and includes the hint in the file log. **OBSERVED via test fixture:** `every_variant()` asserts each `Error` variant's hint is distinct + non-empty.
- **T12.3** (product commit `74279d4`): new read-only `product/src/cmd/diagnose.rs` (8 checks: live-displays, identity-evidence, profiles, hotkeys, settings, autostart, last-known-good, log tail; `Severity`/`Check`/`summarize()`); `Error::DiagnoseUnhealthy(String)`; `logging::tail_lines`; `main.rs` `exit_code()` via `ExitCode::from`. **OBSERVED:** healthy → exit **0** (`verdict: HEALTHY`); malformed `settings.json` → exit **1** with a specific reason (`settings.json malformed: JSON error: EOF while parsing a value at line 1 column 18`); bad usage → exit **2**. No `SetDisplayConfig` in any diagnostic path (read-only invariant, D-002). **D-135 FINAL.**
- **T12.4** (product commit `02df2fe`): `core/verify.rs` gained position-aware `mode_mismatch_dimensions()` (resolution/refresh/rotation/**position**) + a pure `verbose_report(profile, live)`; `Finding::ModeMismatch` Display now names the differing dimension(s) + `pos=`; `cmd/verify.rs` `verify(name, verbose)`; `main.rs` wires `--verbose`/`-v`. **OBSERVED:** `verify --verbose work` prints per-display desired vs actual incl. `pos=[0,0]` / `pos=[-1080,0]` with `OK`/`MISMATCH` markers.
- **T12.5** (product commit `9c744b1`): new `product/src/cmd/logs.rs` (`logs [--tail N]` default 50, `--path`, `--list`; reports the effective level); `logging.rs` gained `MAX_LOG_BYTES` (5 MiB) + `should_rotate` + `rotate_if_needed` (`<stem>.1.log`) called best-effort in `get_logger()`. **OBSERVED:** `logs`, `logs --tail 3`, `logs --path`, `logs --list` all run (exit 0); `--help` lists `logs [--tail N]`; bad `--tail` → exit 2. **Level config was already satisfied by T10.7** (`settings.json` `log_level` + `logging::set_min_level`) — not re-implemented; `logs` reports the effective threshold.

**Gate satisfied** — every criterion has OBSERVED evidence (see checkboxes above).

## Status

**COMPLETE (2026-10-16)** — T12.1–T12.5 implemented + verified on target HW (149/149 tests, clippy clean, release build clean). D-135 FINAL. All gate criteria OBSERVED.
