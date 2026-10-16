# Phase 10 — User Experience (tray profile management, notifications, per-profile hotkeys, settings)

## Objective

Complete the three V1 promises the current build lacks: **tray profile management, toast notifications, per-profile hotkeys** — plus a thin settings surface.

**User value:** the tray becomes a real manager (not just an apply button); every switch gives visible feedback; each profile has its own shortcut; settings are tweakable without the CLI.

**Release it maps to:** v1.1.

## Origin (why this phase exists)

Gap analysis (`ROADMAP.md` §3, rows 1–4): the V1 plan's §16 "Save Current… / Manage Profiles…", §17 "Ctrl+Alt+W / Ctrl+Alt+G", §18 "clear notifications", and §19 settings surface are **not implemented** in the current build:

- **Profile management:** the *capability* exists (`core/persistence.rs::save_profile`, `profile capture` — OBSERVED). What is missing is the **management surface** (Save Current, rename, delete, duplicate) in the tray/CLI — new file operations beyond `persistence.rs`'s current `save_profile`/`load_profile`/`list_profiles` (file reviewed, OBSERVED).
- **Notifications:** currently only the tray tooltip + menu status line (D-118); no toast / success / PARTIAL / failure surfacing.
- **Per-profile hotkeys:** currently a single Ctrl+Alt+D two-profile toggle (D-122); no per-profile, configurable shortcuts.
- **Settings:** CLI autostart only (T7.3); no UI for hotkeys / default profile / log level / toast opt-out.

## Scope

- **In:** tray "Save Current Configuration…" (T10.1); toast notifications (T10.2); tray + CLI profile management (T10.3); active-profile indicator (T10.4); per-profile hotkeys (T10.5); hotkey config UI / learn-by-press (T10.6); settings surface (T10.7); recent switches + Undo (T10.8).
- **Out:** sleep/wake + hotplug + recovery depth (Phase 11); diagnostics / CLI polish (Phase 12); release / signing / CI (Phase 9); testing automation (Phase 13).

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T10.1 | Tray **Save Current Configuration…** (prompted name, capture live topology via the existing `profile capture` path) | tray menu action + saved profile | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW prompt interaction pending user-run) |
| T10.2 | **Toast notifications** for success / PARTIAL / failure (dismissable, non-intrusive; opt-out in config) | toast on every switch | **PLANNED** |
| T10.3 | **Profile management in tray** (rename, delete, duplicate) + CLI (`profile rename`/`delete`/`dup`) | management menu actions + CLI subcommands | **PLANNED** |
| T10.4 | **Active-profile indicator** in tray menu + tooltip (which profile is currently applied / last-known-good) | tray UI | **PLANNED** |
| T10.5 | **Per-profile hotkeys** (`Ctrl+Alt+W`, `Ctrl+Alt+G`, …) — configurable per profile, replacing/extending the two-profile toggle | per-profile hotkey config + registration | **PLANNED** |
| T10.6 | **Hotkey config UI / "learn by press"**: capture key combos into config; detect & report conflicts | learn-by-press UI + conflict reporting | **PLANNED** |
| T10.7 | **Settings surface** (tray menu → small settings window or JSON): hotkeys, default profile, autostart toggle, log level, toast on/off | settings UI + config schema | **PLANNED** |
| T10.8 | **Recent switches + Undo**: last-N applied profiles in tray; "Undo" re-applies the previous profile | recent list + Undo action | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):**
- T10.2 — WinRT `Windows.UI.Notifications` (Win10+): **DOCUMENTED**; Rust bindings + target-HW behavior = **SPIKE** (add the `winrt` crate in a spike first).
- T10.5 — `RegisterHotKey`: **DOCUMENTED** (already used in T6.3); multi-hotkey registration + per-key `ERROR_HOTKEY_ALREADY_REGISTERED` (1409) handling = **SPIKE**.
- T10.1/T10.3/T10.4/T10.8 — reuse OBSERVED existing paths/state (capture, lkg, apply); file ops on the `%LOCALAPPDATA%\dis-play` dirs, no new OS API.
- T10.7 — registry autostart already exists (T7.3); new keys go into `%LOCALAPPDATA%\dis-play\config` (OBSERVED dir).

## Experiments / Tests (user-run on target HW)

| # | Experiment | What to record |
|---|---|---|
| X10.1 | **Toast channel (T10.2, R3):** trigger success / PARTIAL / failure applies; check toasts appear, are dismissable, and opt-out is respected on the user's OS (enterprise-policy case if present) | gate item 2; fallback decision (tooltip+log) if toasts are unreliable |
| X10.2 | **Hotkey conflicts (T10.5, R4):** register the same combo for two profiles → per-key `ERROR_HOTKEY_ALREADY_REGISTERED` surface + conflict message; confirm the menu path still applies the profile | gate item 3 |

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [ ] User can Save Current / rename / delete / duplicate profiles entirely from the tray; state persists across restarts (OBSERVED).
- [ ] Every switch (success / PARTIAL / failure) shows a dismissable toast; opt-out is respected (OBSERVED on target HW).
- [ ] Each profile can bind its own hotkey; conflicts are detected and surfaced; `ERROR_HOTKEY_ALREADY_REGISTERED` per-key handled (OBSERVED).
- [ ] Settings (autostart, default profile, log level, toast on/off) persist and take effect on restart (OBSERVED).

## Potential Blockers / Open Questions

- **Toast channel unproven in Rust (R3):** T10.2 needs a WinRT-bindings spike before committing to toast as the notification channel; **fallback: tray tooltip + log** if toasts are unreliable on the user's OS/policy.
- **Toast policy:** opt-in/out + "do not disturb" behavior must be validated on the **user's** OS (some apps/enterprise policies suppress toasts).
- **T10.3 rename references:** rename = save-as + delete + update any hotkey/auto-refs to the new name (**SPIKE**).
- **Suggested sequence (`ROADMAP.md` §4):** T10.1 → T10.5 → T10.2 → T10.6 → T10.7 (highest value first).

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-131 | Toast notification channel (WinRT vs. tray-only) + opt-out default | **PENDING** (reserved 2026-09-26, not yet decided; T10.2 spike will inform it) |
| D-132 | Hotkey model — replace the two-profile toggle with per-profile hotkeys (schema migration for `hotkeys.json`) | **PENDING** (reserved 2026-09-26, not yet decided; T10.5) |

## Actual Results

### T10.1 — Tray "Save Current Configuration…" (COMPLETE, 2026-10-16)

**Implemented (product):**

- **New tray menu action** `Save Current Configuration…` (`product/src/cmd/tray.rs`): new
  `ID_SAVE_CURRENT = 0xF005`, new `MenuAction::SaveCurrent` variant, mapped in the pure
  `action_for()`, dispatched from `dispatch_action()`. The action is placed between the
  profile list and `Verify live topology`.
- **New modal text-input prompt** (`product/src/windows/prompt.rs`, new): a small Win32
  popup hosting a `static` label, a standard `edit` control and OK/Cancel `button`s.
  Enter = OK / Escape = Cancel via an edit-control subclass (`SetWindowLongPtrW`/`CallWindowProcW`).
  The prompt prefills a suggested name (`display-YYYYMMDD-HHMMSS`, selected) and runs a nested
  modal loop with its owner disabled. A process-wide `is_active()` flag makes the tray window
  procedure ignore tray/hotkey messages while the prompt is open (no menu re-entry behind the
  dialog). Built only from the `windows` crate already in use — **no new OS API** (per the
  T10.1 feasibility note).
- **Reuse of the existing capture path** (`product/src/cmd/profile.rs`): the body of
  `profile capture` was factored into `pub fn capture_profile(name) -> Result<(DisplayProfile, PathBuf)>`;
  `capture()` now calls it (identical CLI behavior), and the tray's `save_current()` calls the
  same function — so the tray captures/validates/persists exactly as the CLI does.
- **Status + logging:** the tray tooltip/menu status line reports
  `saved '<name>' (N display(s)) to <path>` (or `save: cancelled` / `save: no name entered`),
  and the save is written to the T7.1 log file. Empty/whitespace names are rejected.
- **README** (`product/README.md`): the Tray-app section now lists `Save Current Configuration…`.

**Evidence (target HW, 2026-10-16):**
- `cargo check --all-targets`, `cargo clippy --all-targets --all-features -- -D warnings` →
  clean (**OBSERVED**).
- `cargo test --release` → **60/60 pass** (was 57; +3: `windows::prompt::active_flag_tracks_guard`,
  `windows::prompt::encode_wide_appends_nul`, `cmd::tray::default_profile_name_is_a_valid_stem`;
  `action_for` also gained the `ID_SAVE_CURRENT` mapping assertion) (**OBSERVED**).
- `cargo build --release` → clean; `dis-play.exe` 1,531,904 B, `dis-play-tray.exe` 1,431,040 B
  (**OBSERVED**); `dis-play --version` → `dis-play 1.0.0-rc` rc=0 (**OBSERVED**).
- **Pending user-run (not yet OBSERVED):** opening the tray, choosing `Save Current
  Configuration…`, typing a name and confirming that a profile JSON is written under
  `%LOCALAPPDATA%\dis-play\profiles` and appears in the menu after `Refresh profiles`.

**Gate impact:** Phase-10 gate item 1 ("Save Current / rename / delete / duplicate") is
**partially satisfied** by T10.1 (Save Current); the rename/delete/duplicate half is T10.3.

**Decisions:** none new — T10.1 reuses OBSERVED paths and introduces no new behavior choice.
D-131 (toast channel) / D-132 (per-profile hotkeys) remain **PENDING** (untouched).

Other tasks: **none executed.**

## Status

**IN PROGRESS (2026-10-16)** — T10.1 (tray "Save Current Configuration…") COMPLETE: implemented
+ `cargo test --release` 60/60 + `clippy -D warnings` clean + release build (OBSERVED on target
HW); on-HW prompt interaction pending user-run. Tasks T10.2–T10.8 remain PLANNED. D-131/D-132
reserved but undecided. Recommended sequence (`ROADMAP.md` §4): T10.1 → T10.5 → T10.2 → T10.6 →
T10.7; next executable task is **T10.5** (per-profile hotkeys) or T10.3 (profile management).
