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
| T14.1 | **Automation / scripting API:** a small `dis-play api` mode (JSON-RPC over a local named pipe or loopback socket) to apply/verify/list from external tools | `dis-play api` + security review | **PLANNED** |
| T14.2 | **Profile scheduling:** time-based auto-switch (e.g. "Gaming" 18:00–22:00, weekends) | scheduler + schedule schema | **PLANNED** |
| T14.3 | **Audio switching** (separate subsystem per non-goals): map profile → audio output device | audio subsystem | **PLANNED (re-open required)** |
| T14.4 | **Multiple adapters / GPU awareness** (when two GPUs are present): resolver already adapter-aware (OBSERVED) — needs UI to pick | adapter pick UI | **PLANNED** |
| T14.5 | **Multi-PC sync** (per non-goals): only if the user explicitly re-opens the non-goal | sync protocol | **PLANNED (re-open required)** |
| T14.6 | **Headless / service mode** (per non-goal): only if re-opened | service architecture | **PLANNED (re-open required)** |

**API / feasibility notes (from `ROADMAP.md` §4):** T14.1 named-pipe or loopback TCP — **DOCUMENTED**; auth = local-user check only (**SPIKE**: security review). T14.2 timer + existing apply path (OBSERVED); schedule persistence = new config schema (**SPIKE**). T14.3 `MMDeviceAPI` / WinRT audio — **DOCUMENTED**; *only if re-opened* as a goal. T14.4 `QueryDisplayConfig` per adapter — **DOCUMENTED**; resolver is adapter-aware (OBSERVED). T14.5 network protocol — **UNKNOWN**; security model = **SPIKE**. T14.6 service architecture — **UNKNOWN**; would break the "no admin" principle.

## Gate (per sub-feature, not phase-wide)

- [ ] Each sub-feature ships only after its own decision record (D-XXX) + OBSERVED/DOCUMENTED gate.
- [ ] Re-opened **non-goals** (audio, sync, service) are explicitly re-approved in `STATUS.md` with a new decision ID before work starts.

## Potential Blockers / Open Questions

- **Non-goal items (T14.3 audio, T14.5 sync, T14.6 service):** V1 non-goals (`DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3) — listed here only as *possible* future scope, not commitments.
- **T14.5 / T14.6 are UNKNOWN:** network protocol + service architecture have no evidence; a security spike is required before either can gate.
- **Deferral:** keep this phase explicitly deferred until v1.0 + v1.3 are stable.

## Decisions Produced

None yet. No decision IDs are reserved for this phase (`ROADMAP.md` §5.2 reserves D-131–D-136 for other phases). Each future sub-feature gets its own D-XXX when it is re-approved/approved.

## Actual Results

None — no tasks executed yet. Per user instruction (2026-09-26), documentation only: no new task or phase was executed.

## Status

**PLANNED (deferred, not started, 2026-09-26)** — tasks T14.1–T14.6 detailed from `ROADMAP.md` §4. Explicitly deferred until v1.0 + v1.3 are stable. No code executed.
