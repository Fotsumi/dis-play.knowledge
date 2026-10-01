# Phase 11 — Robustness (sleep/wake, hotplug, deeper recovery)

## Objective

Keep the app correct across power and hotplug events and make it **self-recover without manual intervention** (configurable).

**User value:** wake the PC or unplug/replug a display and dis-play knows — it re-verifies, notifies, and (optionally) re-applies the intended profile.

**Release it maps to:** v1.2.

## Origin (why this phase exists)

Gap analysis (`ROADMAP.md` §3, rows 5–7): master-plan Phase 7 acceptance criteria A7 (sleep/wake) and A8 (hotplug) have no implementation, and recovery is a **single** last-known-good snapshot (D-114); V1 plan §13 asks for multiple checkpoints + configurable auto-recovery on startup. The app re-resolves lazily on apply but does not react to power/hotplug events at all.

## Scope

- **In:** sleep/resume detection (T11.1); device-change notification (T11.2); configurable auto-recovery on startup (T11.3); multiple recovery checkpoints (T11.4); deferred identity re-validation (T11.5).
- **Out:** UX features (Phase 10); diagnostics (Phase 12); release process (Phase 9); quality automation (Phase 13).

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T11.1 | **Sleep/resume detection** → on resume, re-verify the active profile; if PARTIAL/FAILED, toast + offer re-apply | resume handler | **PLANNED** |
| T11.2 | **Device-change notifications** (monitor attach/detach) → update tray status, re-resolve, never go stale | `WM_DEVICECHANGE` handler | **PLANNED** |
| T11.3 | **Configurable auto-recovery on startup** (re-apply active profile, gated + verified) | startup auto-apply policy | **PLANNED** |
| T11.4 | **Multiple recovery checkpoints** (keep last-N verified profiles); `recover <profile>` | checkpoint history + subcommand | **PLANNED** |
| T11.5 | **Deferred-identity re-validation:** on resume/hotplug, re-run the identity resolver and flag any entry that became AMBIGUOUS/UNKNOWN | resolver re-run on events | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):**
- T11.1 — `WM_POWERBROADCAST` + `SetPowerBroadcastStatus`: **DOCUMENTED**; target-HW behavior = **OBSERVED** needed.
- T11.2 — `WM_DEVICECHANGE` via `RegisterDeviceNotification`: **DOCUMENTED** (already cited as OPTIONAL in the plan); filtering to the display class = **SPIKE**.
- T11.3/T11.4 — reuse existing `recover`/`verify` + lkg (OBSERVED state); T11.4 extends the `state/` dir (OBSERVED single-lkg file) with a history file, schema additive.
- T11.5 — pure `core/resolver` (OBSERVED, hardware-free); already exists, just wire into the new events.

## Experiments / Tests (user-run on target HW)

| # | Experiment | What to record |
|---|---|---|
| X11.1 | **Sleep → wake (T11.1, A7):** sleep the PC, wake it; confirm the active profile was re-verified, the verdict, and the toast/re-apply offer when degraded | gate item 1 |
| X11.2 | **Monitor unplug/replug (T11.2, A8, R2):** unplug/replug a **monitor** (a display that truly disconnects — the TV E5 is NOT observable, always-on EDID) → tray status updates without manual Refresh; re-resolution still maps correctly | gate item 2 |
| X11.3 | **Auto-recovery on startup (T11.3):** with auto-recovery enabled, start the tray against a mismatched topology → re-apply only after verify OK; verify it never claims a full restore when a display is missing | gate item 3 |

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [ ] Sleep → wake: active profile re-verified, correct verdict, user notified if degraded (OBSERVED).
- [ ] Unplug/replug a monitor: tray status updates without a manual Refresh; re-resolution still maps correctly (OBSERVED).
- [ ] Auto-recovery-on-startup, when enabled, re-applies the active profile only after verification OK and never claims full restore when a display is missing (OBSERVED).
- [ ] Acceptance tests **A7** (sleep/wake) and **A8** (hotplug) from the master plan pass (OBSERVED).

## Potential Blockers / Open Questions

- **TV lifecycle (R2; E5 NOT OBSERVABLE):** the TCL9653 has an always-on EDID (`connected=true` even "off"). T11.2 must be validated on a **monitor** (a display that truly disconnects) as primary proof, with the TV treated as the always-enumerated edge case.
- **Identity permanence (R1; E3 DEFERRED):** T11.5 (re-running the resolver on every power/hotplug event) is the mitigation — profiles stay usable after a driver update **even if** the E3 evidence is never recorded. Keep E3 on the to-do for when drivers change.

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-133 | Auto-recovery-on-startup default (off vs. on) and its verification gate | **PENDING** (reserved 2026-09-26, not yet decided; T11.3) |
| D-134 | Recovery checkpoint history size / retention | **PENDING** (reserved 2026-09-26, not yet decided; T11.4) |

## Actual Results

None — no tasks executed yet. Per user instruction (2026-09-26), documentation only: no new task or phase was executed.

## Status

**PLANNED (not started, 2026-09-26)** — tasks T11.1–T11.5 detailed from `ROADMAP.md` §4. D-133/D-134 reserved but undecided. No code executed.
