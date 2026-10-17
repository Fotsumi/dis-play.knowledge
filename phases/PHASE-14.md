# Phase 14 — Extensibility & Future (lower priority; each sub-feature is its own scope)

## Objective

New capabilities beyond V1, each **independently scoped with its own decision record**; **none block release**.

**User value:** automation, time-based switching, and (if the non-goals are re-opened) audio / multi-PC.

**Release it maps to:** v2.x (only items the user opts into).

## Origin (why this phase exists)

Gap analysis (`ROADMAP.md` §3, row 12; master plan §22 + non-goals §3): automation API, scheduling, audio, GPU awareness, multi-PC sync, service mode — all explicitly **out of scope for V1** (`DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3). They are listed here as *possible* future scope, **not commitments**. This phase must stay **explicitly deferred** until v1.0 + v1.3 are stable.

## Scope

- **In:** automation / scripting API (T14.1); profile scheduling (T14.2); audio switching (T14.3 — re-open required); multi-adapter / GPU awareness (T14.4); multi-PC sync (T14.5 — re-open required); headless / service mode (T14.6 — re-open required).
- **Out:** everything in the V1 roadmap (Phases 9–13) comes first; all V1 non-goals per `DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3.

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T14.1 | **Automation / scripting API:** a small `dis-play api` mode (JSON-RPC over a local named pipe or loopback socket) to apply/verify/list from external tools | `dis-play api` + security review | **COMPLETE** (2026-10-16, product commit `01f51d9`, 185 tests, clippy/fmt clean — D-142) |
| T14.2 | **Profile scheduling:** time-based auto-switch (e.g. "Gaming" 18:00–22:00, weekends) | scheduler + schedule schema | **COMPLETE** (2026-10-16, product commit `17ffdc0`, 199 tests, clippy/fmt clean — D-143) |
| T14.3 | **Audio switching** (separate subsystem per non-goals): map profile → audio output device | audio subsystem | **COMPLETE** (2026-10-16, product commit `ed5fc7a`, 207 tests, clippy/fmt clean — D-144; `IPolicyConfig` SPIKE) |
| T14.4 | **Multiple adapters / GPU awareness** (when two GPUs are present): resolver already adapter-aware (OBSERVED) — needs UI to pick | adapter pick UI | **COMPLETE** (2026-10-16, product commit `8888e75`, 214 tests, clippy/fmt clean — D-145) |
| T14.5 | **Multi-PC sync** (per non-goals): only if the user explicitly re-opens the non-goal | sync protocol | **IN PROGRESS (re-opened — D-146)** |
| T14.6 | **Headless / service mode** (per non-goal): only if re-opened | service architecture | **IN PROGRESS (re-opened — D-147)** |

**API / feasibility notes (from `ROADMAP.md` §4):** T14.1 named-pipe or loopback TCP — **DOCUMENTED**; auth = local-user check only (**SPIKE**: security review). T14.2 timer + existing apply path (OBSERVED); schedule persistence = new config schema (**SPIKE**). T14.3 `MMDeviceAPI` / WinRT audio — **DOCUMENTED**; *only if re-opened* as a goal. T14.4 `QueryDisplayConfig` per adapter — **DOCUMENTED**; resolver is adapter-aware (OBSERVED). T14.5 network protocol — **UNKNOWN**; security model = **SPIKE**. T14.6 service architecture — **UNKNOWN**; would break the "no admin" principle.

## Gate (per sub-feature, not phase-wide)

- [x] Each sub-feature ships only after its own decision record (D-XXX) + OBSERVED/DOCUMENTED gate. — **D-142 (T14.1), D-143 (T14.2), D-144 (T14.3), D-145 (T14.4), D-146 (T14.5), D-147 (T14.6)** recorded in `STATUS.md` before implementation.
- [x] Re-opened **non-goals** (audio, sync, service) are explicitly re-approved in `STATUS.md` with a new decision ID before work starts. — **re-approved 2026-10-16 by user instruction** (audio → D-144, multi-PC sync → D-146, service/headless → D-147); recorded in `STATUS.md` §Decisions Made.

## Potential Blockers / Open Questions

- **Non-goal items (T14.3 audio, T14.5 sync, T14.6 service):** V1 non-goals (`DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3) — listed here only as *possible* future scope, not commitments.
- **T14.5 / T14.6 are UNKNOWN:** network protocol + service architecture have no evidence; a security spike is required before either can gate.
- **Deferral:** keep this phase explicitly deferred until v1.0 + v1.3 are stable.

## Decisions Produced

Recorded **2026-10-16** on user instruction to execute all Phase 14 tasks (the phase was explicitly re-opened; the three V1 non-goals were re-approved first, per the gate). Full text in `STATUS.md` §Decisions Made.

| ID | Task | Decision (one-line) | Status |
|---|---|---|---|
| D-142 | T14.1 | Automation API = JSON-RPC 2.0 over a **local named pipe** `\\.\pipe\dis-play-api` (no listening TCP); same-user-only ACL; pure dispatch layer + thin pipe transport; gated `apply`/`recover` require `"confirm": true` | PENDING-EVIDENCE |
| D-143 | T14.2 | Scheduling = additive `schedules.json` schema + a tray `SetTimer` poller; pure `active_schedule(now, schedules)`; applies only when the target differs from the active (lkg) profile; opt-in | PENDING-EVIDENCE |
| D-144 | T14.3 | Audio switching (non-goal re-opened) = optional additive `DisplayProfile.audio_device`; enumerate via `MMDeviceAPI`, resolve via pure `core::audio::resolve_endpoint`, set default via best-effort `IPolicyConfig` (undocumented, SPIKE, hand-rolled vtable) with graceful skip; new read-only `dis-play audio` | PENDING-EVIDENCE |
| D-145 | T14.4 | Adapter/GPU awareness = read-only `adapters` command + optional additive `DisplayEntry.adapter` key honored by the resolver; adapter shown in `identity`/`verify`/`diagnose` | PENDING-EVIDENCE |
| D-146 | T14.5 | Multi-PC sync (non-goal re-opened) = portable **export/import bundle** (`sync export`/`sync import`) with merge semantics — **no live network listener** (avoids the UNKNOWN security model) | PENDING-EVIDENCE |
| D-147 | T14.6 | Headless/service mode (non-goal re-opened) = `service install|uninstall|status` via the Windows SCM + a `headless` apply mode; **requires admin** and explicitly breaks the V1 "no admin" principle | PENDING-EVIDENCE |

## Actual Results

Executed 2026-10-16 (all six tasks) under user instruction. See `STATUS.md` §Current Work / §Last Completed Work for per-task results, test counts and evidence. Per-task gate evidence recorded as each task completes.

- **T14.1 (D-142) — Automation/scripting API: COMPLETE (2026-10-16, product commit `01f51d9`, OBSERVED for build/test).** New pure `src/core/api.rs` (JSON-RPC 2.0 dispatcher: `METHODS`, `ApiError`, `ApiBackend` trait, `dispatch`/`route`; +24 unit tests with a mock backend), thin `src/windows/pipe.rs` transport on `\\.\pipe\dis-play-api` (`PIPE_REJECT_REMOTE_CLIENTS` + creator default DACL = same-user only), and `src/cmd/api.rs` `RealBackend` wired to the same `cmd`/`core` functions as the CLI. Read-only methods (`ping`, `version`, `list`, `targets`, `identity`, `diagnose`, `profiles.list`, `profiles.show`, `validate`, `verify`) + **gated** `apply`/`recover` requiring `"confirm": true` (D-002). `dis-play api` runs the server. `help.rs`/`main.rs`/`Cargo.toml` features (`Win32_System_Pipes`, `Win32_Storage_FileSystem`, `Win32_System_IO`) updated; README "Automation API" section + CHANGELOG entry. **OBSERVED:** `cargo test --release` → **185 passed** (161 → +24), clippy `-D warnings` + `cargo fmt --check` clean, release build clean, `--version` rc=0; end-to-end pipe round-trips (`version` ok, `apply` without confirm → `-32000`, unknown method → `-32601`, bad params → `-32602`).
- **T14.2 (D-143) — Profile scheduling: COMPLETE (2026-10-16, product commit `17ffdc0`, OBSERVED for build/test).** New pure `src/core/schedule.rs` (`Schedule`, `ScheduleConfig` additive serde, `schedule_path`, `load_schedule`/`save_schedule` (missing file → default), `Moment`, `parse_days`/`parse_time`, `active_schedule`/`active_profile`; 11 unit tests) + read-only `src/cmd/schedule.rs` (`dis-play schedule`) + a tray 30 s `SetTimer(hwnd, 0xF100, 30000, None)`/`WM_TIMER` poller (`on_schedule_tick`, `LAST_SCHEDULED` guard) that applies a profile **only when it differs from the active (lkg) profile**, reusing the gated `apply_profile` path. `schedules.json` = `{ enabled, schedules: [{ profile, days, start, end }] }` (opt-in; `weekdays`/`weekends` tokens; `end <= start` wraps past midnight — start-day ownership; last matching window wins). `main.rs`/`help.rs`/`Cargo.toml` (`time` `local-offset`) updated; README "Scheduling" + CHANGELOG. **OBSERVED:** `cargo test --release` → **199 passed** (185 → +14), clippy `-D warnings` + `fmt --check` clean, release build clean, `--version` rc=0; `dis-play schedule` handled a missing `schedules.json` gracefully and (with a temp file) reported the active window incl. a wrap window + last-match precedence. Tray poller code-path reused (not observed in a live tray session).
- **T14.3 (D-144) — Audio switching (re-opened non-goal): COMPLETE (2026-10-16, product commit `ed5fc7a`, OBSERVED for build/test; `IPolicyConfig` SPIKE).** `DisplayProfile` gains additive `audio_device: Option<String>` (render-endpoint id or friendly-name substring). New pure `src/core/audio.rs` (`AudioEndpoint` + `resolve_endpoint`: exact id wins, else unique case-insensitive substring, else typed error — never guess; 7 tests), thin `src/windows/audio.rs` (`MMDeviceAPI` enumeration + a **hand-rolled `IPolicyConfig` vtable** `SetDefaultEndpoint(eConsole)` — undocumented/SPIKE, all failures typed + non-fatal), and read-only `src/cmd/audio.rs` (`dis-play audio`). `apply` (and the tray path) switch audio **after** a successful display apply; an audio failure never fails the display apply (warn + continue). `error::AudioDevice` variant added; `main.rs`/`help.rs`/Cargo features updated; README "Audio switching" + CHANGELOG. **OBSERVED:** `cargo test --release` → **207 passed** (199 → +8; 1 ignored SPIKE smoke test — run via `--ignored`, idempotent `SetDefaultEndpoint` to the already-default `eConsole` id), clippy `-D warnings` + `fmt --check` clean, release build clean; `dis-play audio` listed 5 render endpoints (default marked). Real end-to-end switch through `apply` not run (would mutate displays).
- **T14.4 (D-145) — Multiple adapters / GPU awareness: COMPLETE (2026-10-16, product commit `8888e75`, OBSERVED for build/test + target HW).** New read-only `src/cmd/adapters.rs` (`dis-play adapters` — per adapter: LUID, `DISPLAYCONFIG_ADAPTER_NAME` device path via `GET_ADAPTER_NAME`, and its displays, from `QDC_ALL_PATHS`). `DisplayCandidate` gains additive `adapter_device_path: Option<String>` (populated from the live paths); `DisplayEntry` gains additive `adapter: Option<String>`; the **resolver honors it** (mismatch → `Unknown`, never guessed; `None` = unchanged). `profile capture` records the adapter per entry automatically; `identity` gains an adapter column and `diagnose` a new `adapters` check; `verify --verbose` notes `(adapter-bound to …)`. `main.rs`/`help.rs`/sync-guard updated; README "Multiple adapters / GPU awareness" + CHANGELOG. **OBSERVED:** `cargo test --release` → **214 passed** (207 → +7), clippy `-D warnings` + `fmt --check` clean, release build clean; on target HW `dis-play adapters` showed 2 AMD adapters (discrete `DEV_7550` owning the 3 displays + integrated `DEV_13C0` render-only), `identity` adapter column populated, `diagnose` HEALTHY with the new adapters check.

## Status

**IN PROGRESS (executing all six tasks, 2026-10-16).** Phase re-opened on user instruction; the three V1 non-goals (audio/sync/service) were re-approved with new decision IDs **before work started** (D-144/D-146/D-147). Each sub-feature carries its own decision record (D-142–D-147).
