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
| T11.2 | **Device-change notifications** (monitor attach/detach) → update tray status, re-resolve, never go stale | `WM_DEVICECHANGE` handler | **COMPLETE** |
| T11.3 | **Configurable auto-recovery on startup** (re-apply active profile, gated + verified) | startup auto-apply policy | **COMPLETE** |
| T11.4 | **Multiple recovery checkpoints** (keep last-N verified profiles); `recover <profile>` | checkpoint history + subcommand | **COMPLETE** |
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
| D-141 | Auto-recovery-on-startup **OFF by default (opt-in)**; when enabled it verifies first and re-applies only when degraded, through the gated+verified recover path; never claims full restore when a display is missing. | **FINAL (2026-10-16)** (reserved 2026-09-26 as "D-133"; **renumbered to D-141 2026-10-16** because D-133 was reassigned to Phase 10 T10.3) |
| D-134 | Recovery checkpoint history keeps up to **10** verified checkpoints in `state/recovery-history.json`, newest first, de-duplicated by profile name; `recover <profile>` re-applies the most recent checkpoint for that profile. Additive schema — `last-known-good.json` unchanged. | **FINAL (2026-10-16)** |

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

### T11.2 — Device-change notifications (monitor attach/detach): COMPLETE (2026-10-16, target HW, OBSERVED for build/test; hotplug gate item X11.2 pending user-run)

Implemented in `product/src/cmd/tray.rs`:

- `use` list extended with `DEV_BROADCAST_DEVICEINTERFACE_W`, `DBT_DEVICEARRIVAL`,
  `DBT_DEVICEREMOVECOMPLETE`, `DBT_DEVTYP_DEVICEINTERFACE`, `DEVICE_NOTIFY_WINDOW_HANDLE`,
  `HDEVNOTIFY`, `RegisterDeviceNotificationW`, `UnregisterDeviceNotification`, `WM_DEVICECHANGE`
  (all under the already-enabled `Win32_UI_WindowsAndMessaging` feature) + a new import
  `windows::Win32::Devices::Display::GUID_DEVINTERFACE_MONITOR` (feature already enabled) +
  `use std::ffi::c_void`. `DBT_DEVNODES_CHANGED` is imported inside the `tests` module (it is
  referenced only by the T11.2 unit test, so a top-level import would be an unused-import warning
  in the non-test lib build).
- Pure `device_change_is_display_event(u32)` — true only for `DBT_DEVICEARRIVAL` (0x8000) /
  `DBT_DEVICEREMOVECOMPLETE` (0x8004); every other `WM_DEVICECHANGE` (`DBT_DEVNODES_CHANGED`, …)
  is ignored.
- `register_display_notifications(hwnd) -> Option<HDEVNOTIFY>` — builds a
  `DEV_BROADCAST_DEVICEINTERFACE_W` filter for the `GUID_DEVINTERFACE_MONITOR` interface class and
  calls `RegisterDeviceNotificationW` with `DEVICE_NOTIFY_WINDOW_HANDLE`. Best-effort: on failure
  it logs a warning and returns `None` (the tray stays usable; status updates on the next menu open).
- `unregister_display_notifications(handle)` — `UnregisterDeviceNotification` on teardown.
- `on_device_change(hwnd)` — logs and calls the shared read-only `event_reverify(hwnd,"display
  change")` (T11.1 helper; never calls `SetDisplayConfig`).
- `tray_wnd_proc` gained a `WM_DEVICECHANGE` branch (after `WM_POWERBROADCAST`, before `TRAY_MSG`):
  refreshes live on `device_change_is_display_event(wparam)`, returns `LRESULT(1)` (handled).
- `run()`: `register_display_notifications(hwnd)` is the first statement in the startup `unsafe`
  block; the registration handle is released in teardown (after `DestroyWindow`, before the mutex
  release).
- Module-level doc comment: extended the `Phase 11 robustness:` section with the T11.2 line.
- `product/CHANGELOG.md`: added the T11.2 bullet under `[Unreleased] → Added`.
- One unit test: `device_change_is_display_event_filters`.

**OBSERVED (target HW):**

- `cargo test --release` → **112 passed; 0 failed** (was 111; +1).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean (no warnings). A first pass
  flagged `DBT_DEVNODES_CHANGED` as an unused import in the lib build; resolved by importing it in
  the `tests` module instead of the top-level `use` list.
- `cargo build --release` → `Finished \`release\` profile [optimized]` (clean).
- `target\release\dis-play.exe --version` → `dis-play 1.0.0-rc`, exit 0.

The monitor unplug/replug **gate item** (X11.2 / A8 / R2) remains **pending user-run** on target HW
(the TV E5 is NOT observable — always-on EDID; X11.2 must use a monitor that truly disconnects). No
new decision (reuses the OBSERVED read-only `verify` path + last-known-good state).

### T11.3 — Configurable auto-recovery on startup: COMPLETE (2026-10-16, target HW, OBSERVED for build/test; auto-recovery gate item X11.3 pending user-run)

Implemented in `product/src/core/settings.rs` + `product/src/cmd/tray.rs`:

- `product/src/core/settings.rs`: `Settings` gained `auto_recovery: bool` (**opt-in, default
  `false`** — D-141), `#[serde(default)]` like the other fields, so a v1.1 settings.json parses
  unchanged. `Default for Settings` sets `auto_recovery: false`. Existing tests updated
  (`settings_round_trip_through_file` now uses `auto_recovery: true`;
  `default_has_toasts_enabled` + `unknown_keys_ignored_and_missing_keys_default` also assert
  `!s.auto_recovery`) and one new test `auto_recovery_is_opt_in_and_round_trips`.
- `product/src/cmd/tray.rs`: new `ID_SETTINGS_AUTORECOVERY = 0xF012` + `MenuAction::ToggleAutoRecovery`
  (`action_for` maps the id; `dispatch_action` → `toggle_auto_recovery`); `append_settings_submenu`
  appends `Auto-recovery on startup: on/off` after the autostart item; `toggle_auto_recovery`
  mirrors `toggle_toasts` (persist + status + log).
- New `auto_recover_on_startup(hwnd)`: reads last-known-good (no record → log + return), enumerates
  the live topology, `verify_profile`s; when OK it logs "already matches - no re-apply" and returns;
  when degraded it logs the verdict + finding count and calls the existing gated + verified
  `recover_now`, so the true PARTIAL/FAILED verdict is surfaced (a missing display is never reported
  as a full restore).
- `apply_startup_settings`: the default-profile block now records `applied_default`; when this
  launch did **not** apply a configured default profile and `settings.auto_recovery` is on, it logs
  and calls `auto_recover_on_startup` first-verify.
- Test `action_for_maps_settings_and_undo_ids` extended with
  `assert_eq!(action_for(ID_SETTINGS_AUTORECOVERY, 3), MenuAction::ToggleAutoRecovery)`.
- `product/CHANGELOG.md` (`[Unreleased] → Added`) + `product/README.md` (`## Settings` table/JSON
  + note) updated.

**OBSERVED (target HW):**

- `cargo test --release` → **113 passed; 0 failed** (was 112; +1 test `auto_recovery_is_opt_in_and_round_trips`).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean (no warnings).
- `cargo build --release` → `Finished \`release\` profile [optimized]` (clean).
- `target\release\dis-play.exe --version` → `dis-play 1.0.0-rc`, exit 0.

The auto-recovery-on-startup **gate item** (X11.3) remains **pending user-run** on target HW (start
the tray against a mismatched topology with auto-recovery enabled → confirm re-apply only after
verify OK and no false full-restore claim). **Decision D-141 decided FINAL (opt-in, verify-first).**

### T11.4 — Multiple recovery checkpoints (D-134): COMPLETE (2026-10-16, target HW, OBSERVED for build/test)

Implemented across `product/src/core/recovery.rs`, `product/src/error.rs`, `product/src/cmd/recover.rs`,
`product/src/cmd/apply.rs`, `product/src/cmd/tray.rs` and `product/src/main.rs`:

- `product/src/core/recovery.rs`: new `CHECKPOINT_FILE = "recovery-history.json"`,
  `MAX_CHECKPOINTS = 10`, `checkpoint_path(dir)`, `load_checkpoints(dir)` (missing file → empty
  history, not an error), `record_checkpoint(dir, source, profile)` (moves `source` to the front,
  de-duplicates by profile name, truncates to `MAX_CHECKPOINTS`) and `find_checkpoint(dir, name)`
  (newest-first scan). Additive — `last-known-good.json` is unchanged.
- `product/src/error.rs`: new `Error::NoCheckpoint(String)` variant (after `NoLastKnownGood`) with its
  `Display` arm.
- `product/src/cmd/recover.rs`: the existing `recover` records a checkpoint when the post-recovery
  verdict is OK; new gated `recover_profile(confirm, name)` re-applies `find_checkpoint(dir, name)`
  through the same gated + verified path (errors `NoCheckpoint` when absent).
- `product/src/cmd/apply.rs`: `verify_and_record`'s OK branch also calls `record_checkpoint`.
- `product/src/cmd/tray.rs`: `apply_profile`'s OK branch and `recover_now`'s OK branch also record a
  checkpoint.
- `product/src/main.rs`: `recover <flag> [profile]` dispatches to `recover_profile` when a positional
  profile name is present, else the original `recover`; usage string updated.
- `product/CHANGELOG.md` (`[Unreleased] → Added`) + `product/README.md` (CLI table row + state-dir
  note) updated.
- Four unit tests: `load_checkpoints_missing_file_is_empty`,
  `record_checkpoint_is_newest_first_and_dedupes`, `record_checkpoint_caps_at_max`,
  `find_checkpoint_returns_most_recent_for_name`.

**OBSERVED (target HW):**

- `cargo test --release` → **117 passed; 0 failed** (was 113; +4).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean (no warnings).
- `cargo build --release` → `Finished \`release\` profile [optimized]` (clean).
- `target\release\dis-play.exe --version` → `dis-play 1.0.0-rc`, exit 0.

**Decision D-134 decided FINAL** (10 checkpoints, newest first, de-duplicated by profile name,
`recover <profile>`; additive schema).


## Status

**IN PROGRESS (2026-10-16)** — tasks T11.1–T11.5 detailed from `ROADMAP.md` §4. T11.1 (sleep/resume re-verify), T11.2 (device-change notifications), T11.3 (opt-in auto-recovery on startup, D-141 FINAL) and T11.4 (rolling recovery checkpoints, D-134 FINAL) implemented on target HW (OBSERVED for build/test); gate items X11.1/X11.2/X11.3 pending user-run. Next executable task: **T11.5** (deferred-identity re-validation).
