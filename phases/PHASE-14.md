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
| T14.1 | **Automation / scripting API:** a small `dis-play api` mode (JSON-RPC over a local named pipe or loopback socket) to apply/verify/list from external tools | `dis-play api` + security review | **IN PROGRESS** |
| T14.2 | **Profile scheduling:** time-based auto-switch (e.g. "Gaming" 18:00–22:00, weekends) | scheduler + schedule schema | **IN PROGRESS** |
| T14.3 | **Audio switching** (separate subsystem per non-goals): map profile → audio output device | audio subsystem | **IN PROGRESS (re-opened — D-144)** |
| T14.4 | **Multiple adapters / GPU awareness** (when two GPUs are present): resolver already adapter-aware (OBSERVED) — needs UI to pick | adapter pick UI | **IN PROGRESS** |
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
| D-144 | T14.3 | Audio switching (non-goal re-opened) = optional additive `DisplayEntry.audio_device`; enumerate via `MMDeviceAPI`, set default via best-effort `IPolicyConfig` (undocumented, SPIKE) with graceful skip | PENDING-EVIDENCE |
| D-145 | T14.4 | Adapter/GPU awareness = read-only `adapters` command + optional additive `DisplayEntry.adapter` key honored by the resolver; adapter shown in `identity`/`verify`/`diagnose` | PENDING-EVIDENCE |
| D-146 | T14.5 | Multi-PC sync (non-goal re-opened) = portable **export/import bundle** (`sync export`/`sync import`) with merge semantics — **no live network listener** (avoids the UNKNOWN security model) | PENDING-EVIDENCE |
| D-147 | T14.6 | Headless/service mode (non-goal re-opened) = `service install|uninstall|status` via the Windows SCM + a `headless` apply mode; **requires admin** and explicitly breaks the V1 "no admin" principle | PENDING-EVIDENCE |

## Actual Results

Executed 2026-10-16 (all six tasks) under user instruction. See `STATUS.md` §Current Work / §Last Completed Work for per-task results, test counts and evidence. Per-task gate evidence recorded as each task completes.

## Status

**IN PROGRESS (executing all six tasks, 2026-10-16).** Phase re-opened on user instruction; the three V1 non-goals (audio/sync/service) were re-approved with new decision IDs **before work started** (D-144/D-146/D-147). Each sub-feature carries its own decision record (D-142–D-147).
