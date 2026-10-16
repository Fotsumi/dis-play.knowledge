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
| T11.1 | **Sleep/resume detection** → on resume, re-verify the active profile; if PARTIAL/FAILED, toast + offer re-apply | resume handler | **COMPLETE** |
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
| D-141 | Auto-recovery-on-startup default (off vs. on) and its verification gate | **PENDING** (reserved 2026-09-26 as "D-133"; **renumbered to D-141 2026-10-16** because D-133 was reassigned to Phase 10 T10.3. Not yet decided; T11.3) |
| D-134 | Recovery checkpoint history size / retention | **PENDING** (reserved 2026-09-26, not yet decided; T11.4) |

## Actual Results

### T11.1 — Sleep/resume detection: COMPLETE (2026-10-16, target HW, OBSERVED for build/test; sleep→wake gate item X11.1 pending user-run)

Implemented in `product/src/cmd/tray.rs`:

- `use` list extended with `PBT_APMRESUMEAUTOMATIC`, `PBT_APMRESUMESUSPEND`, `WM_POWERBROADCAST`
  (all present under the already-enabled `Win32_UI_WindowsAndMessaging` feature).
- Two pure helpers near the other small pure helpers: `power_event_is_resume(u32)` (true for
  `PBT_APMRESUMEAUTOMATIC` = 18 and `PBT_APMRESUMESUSPEND` = 7) and
  `resume_needs_attention(VerifyStatus)` (true unless OK).
- Shared, **read-only** re-verify helper `event_reverify(hwnd, reason)` (used by T11.1 now;
  intended for re-use by T11.2 display-change and T11.5 deferred-identity events): resolves app
  dirs, loads last-known-good, enumerates the live topology, calls `verify_profile`, updates the
  tray status, logs at the verdict severity, and — when degraded — raises a toast pointing at
  `Recover last-known-good`. It never calls `SetDisplayConfig`.
- `on_resume(hwnd)` logs the resume and calls `event_reverify(hwnd, "resumed")`.
- `tray_wnd_proc` gained a `WM_POWERBROADCAST` branch (after the `WM_HOTKEY` block, before
  `TRAY_MSG`) that calls `on_resume` for resume `wParam` values and returns `LRESULT(1)`
  (TRUE = handled). The existing modal-dialog guard (`prompt::is_active() ||
  hotkey_capture::is_active()`) remains at the top of the proc.
- Module-level doc comment: added a `Phase 11 robustness:` section noting T11.1.
- `product/CHANGELOG.md`: added the T11.1 bullet under `[Unreleased] → Added`.
- Two unit tests: `power_event_is_resume_matches_resume_events`,
  `resume_needs_attention_only_when_not_ok`.

**OBSERVED (target HW):**

- `cargo test --release` → **111 passed; 0 failed** (was 109; +2).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean (no warnings).
- `cargo build --release` → `Finished \`release\` profile [optimized]` (clean).
- `target\release\dis-play.exe --version` → `dis-play 1.0.0-rc`, exit 0.

The sleep→wake **gate item** (X11.1 / A7) remains **pending user-run** on target HW — the code
path is built and unit-tested; the live resume event has not yet been observed.

No new decision (reuses the OBSERVED read-only `verify` path + last-known-good state).

None before T11.1 — Phase 11 execution began with this task.


## Status

**READY (unblocked 2026-10-16)** — tasks T11.1–T11.5 detailed from `ROADMAP.md` §4. Unblocked by Phase 10 completion (2026-10-16, gate verified on target HW). D-134 and D-141 reserved but undecided. No code executed yet; next executable phase when work resumes.
