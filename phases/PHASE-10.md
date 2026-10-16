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
| T10.2 | **Toast notifications** for success / PARTIAL / failure (dismissable, non-intrusive; opt-out in config) | toast on every switch | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW toast display via X10.1 pending user-run) |
| T10.3 | **Profile management in tray** (rename, delete, duplicate) + CLI (`profile rename`/`delete`/`dup`) | management menu actions + CLI subcommands | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW menu/prompt interaction pending user-run) |
| T10.4 | **Active-profile indicator** in tray menu + tooltip (which profile is currently applied / last-known-good) | tray UI | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW menu/tooltip display pending user-run) |
| T10.5 | **Per-profile hotkeys** (`Ctrl+Alt+W`, `Ctrl+Alt+G`, …) — configurable per profile, replacing/extending the two-profile toggle | per-profile hotkey config + registration | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW hotkey fire/conflict = X10.2 pending user-run) |
| T10.6 | **Hotkey config UI / "learn by press"**: capture key combos into config; detect & report conflicts | learn-by-press UI + conflict reporting | **COMPLETE** (2026-10-16, implemented + `cargo test`/`clippy` OBSERVED on target HW; on-HW capture/conflict interaction pending user-run) |
| T10.7 | **Settings surface** (tray menu → small settings window or JSON): hotkeys, default profile, autostart toggle, log level, toast on/off | settings UI + config schema | **PLANNED** |
| T10.8 | **Recent switches + Undo**: last-N applied profiles in tray; "Undo" re-applies the previous profile | recent list + Undo action | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):**
- T10.2 — WinRT `Windows.UI.Notifications` (Win10+): **DOCUMENTED**; Rust bindings + target-HW behavior = **SPIKE** (add the `winrt` crate in a spike first). **RESOLVED (D-131, 2026-10-16):** the spike chose the tray icon's **shell notification** (`Shell_NotifyIconW` + `NIF_INFO`, already-enabled `Win32_UI_Shell`) over WinRT — it renders as a standard, dismissable system toast on Win10/11 with **no new dependency** and no unpackaged-AppUserModelID/Start-Menu-shortcut requirement. Implemented in T10.2.
- T10.5 — `RegisterHotKey`: **DOCUMENTED** (already used in T6.3); multi-hotkey registration + per-key `ERROR_HOTKEY_ALREADY_REGISTERED` (1409) handling = **SPIKE**. **RESOLVED (T10.5, 2026-10-16):** per-profile bindings register individually (`HK_BINDING_BASE + index`, `MOD_NOREPEAT`); a failing key is logged/surfaced per key and never prevents the others. Combination strings are parsed/validated by a pure `core::hotkeys::parse_hotkey` mock-tested on the target HW; the Win32 conversion (`HOT_KEY_MODIFIERS`/VK) happens only at the tray registration site.
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

- ~~**Toast channel unproven in Rust (R3):** T10.2 needs a WinRT-bindings spike before committing to toast as the notification channel; **fallback: tray tooltip + log** if toasts are unreliable on the user's OS/policy.~~ **RESOLVED (2026-10-16, D-131):** the spike chose the tray icon's **shell notification** (`Shell_NotifyIconW` + `NIF_INFO`) — no new dependency; the tooltip + log remain the fallback.
- **Toast policy:** opt-out + "do not disturb" behavior must still be validated on the **user's** OS (some apps/enterprise policies suppress toasts) — X10.1 (user-run).
- **T10.3 rename references:** rename = save-as + delete + update any hotkey/auto-refs to the new name (**SPIKE**).
- **Suggested sequence (`ROADMAP.md` §4):** T10.1 → T10.5 → T10.2 → T10.6 → T10.7 (highest value first).

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-131 | Toast notification channel (WinRT vs. tray-only) + opt-out default | **FINAL** (2026-10-16, T10.2): channel = tray icon **shell notification** (`Shell_NotifyIconW` + `NIF_INFO`, no new dependency); opt-out default = **toasts ON** (`settings.json` `{ "toasts": false }` to silence) |
| D-132 | Hotkey model — per-profile hotkeys; the legacy Ctrl+Alt+D toggle pair is kept (schema migration for `hotkeys.json`) | **FINAL** (2026-10-16, T10.5): additive schema — `HotkeyConfig` gains `bindings: [{ profile, hotkey }]` (`#[serde(default)]`); the legacy `profiles` toggle pair is retained unchanged, so a v1.0 config still parses and the OBSERVED toggle keeps working; a combination needs ≥1 modifier; conflicts (another profile / the built-in toggle / another app) are reported, never silently applied |
| D-133 | Profile-management surface (T10.3): each tray profile is a **per-profile submenu** (`Apply` / `Rename…` / `Duplicate…` / `Delete`); delete is confirmed via a stock `MessageBoxW` Yes/No; a **rename rewrites** any `hotkeys.json` entry and the last-known-good `source` reference to the new name (the rename-reference spike). No new crate/feature — `Win32_UI_WindowsAndMessaging` already enabled. | **FINAL** (2026-10-16, T10.3; implementation + tests OBSERVED, on-HW menu interaction pending user-run) |

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
D-131 (toast channel) was decided later by **T10.2**; D-132 (per-profile hotkeys) remains
**PENDING** (untouched by T10.1).

### T10.2 — Toast notifications (COMPLETE, 2026-10-16)

**Implemented (product):**

- **Channel decision (D-131):** the tray icon's **shell notification**
  (`Shell_NotifyIconW` + `NIF_INFO`), not WinRT. On Windows 10/11 the shell renders this as a
  standard, **dismissable system toast** (recorded in the Action Center) and honors quiet
  hours — with the already-enabled `Win32_UI_Shell` feature and **no new dependency** (WinRT
  would have added the `winrt`/`windows`-WinRT surface *and* an unpackaged-AppUserModelID
  requirement). Documented in `product/src/windows/toast.rs`.
- **New `product/src/windows/toast.rs`:** `ToastKind { Info, Warning, Error }` →
  `NIIF_INFO`/`NIIF_WARNING`/`NIIF_ERROR` (+`NIIF_RESPECT_QUIET_TIME`); `show(base, kind,
  title, body)` sets `NIF_INFO` on the passed `NOTIFYICONDATAW` and calls `NIM_MODIFY`,
  clamping the fixed `szInfo` (`[u16; 256]`) / `szInfoTitle` (`[u16; 64]`) fields. Best-effort
  (returns `bool`, never panics) — the tooltip + log stay the fallback.
- **New `product/src/core/settings.rs`:** `Settings { toasts: bool }` (`#[serde(default)]`,
  default **ON** — opt-out per D-131) at `%LOCALAPPDATA%\dis-play\config\settings.json`; a
  missing/malformed file falls back to the defaults (never fatal); `load_settings` /
  `save_settings` (the latter is the write path T10.7 will reuse). Additive schema so T10.7's
  hotkeys / default-profile / log-level keys can extend it without breaking a v1.1 file.
- **`product/src/cmd/tray.rs`:** a `notify()` helper (checks the opt-out, shows the toast,
  logs `toast [kind] title: body`); pure message builders `kind_for_verdict` (OK→info,
  PARTIAL→warning, FAILED→error), `fail_toast`, `verdict_toast`. Wired into every **switch**:
  `apply_profile` (load error / rc≠0 / rc=0-but-query-failed / OK / PARTIAL / FAILED),
  `recover_now` (error / rc≠0 / query failed / verdict), and the manual `verify_now` verdict.
  The hotkey toggle rides the same `apply_profile`, so it toasts too.
- **README** (`product/README.md`): new **Notifications** section (outcome→toast table,
  opt-out JSON, quiet-hours note) + tray/uninstall/troubleshooting updates. **CHANGELOG**
  (`product/CHANGELOG.md`): Unreleased entries for T10.1 + T10.2.

**Evidence (target HW, 2026-10-16):**
- `cargo check --all-targets` clean; `cargo clippy --all-targets --all-features -- -D warnings`
  clean (**OBSERVED**).
- `cargo test --release` → **72/72 pass** (was 60; +12: `core::settings` 5,
  `windows::toast` 3, `cmd::tray` 4 toast/verdict tests) (**OBSERVED**).
- `cargo build --release` clean; `dis-play.exe` 1,542,144 B, `dis-play-tray.exe` 1,441,280 B
  (**OBSERVED**); `dis-play --version` → `dis-play 1.0.0-rc` rc=0 (**OBSERVED**).
- **Pending user-run (X10.1, not yet OBSERVED):** trigger success / PARTIAL / failure applies
  on the user's OS; confirm the toasts appear, are dismissable, and that
  `{ "toasts": false }` in `settings.json` silences them (enterprise-policy case included).

**Gate impact:** Phase-10 gate item 2 ("every switch shows a dismissable toast; opt-out
respected") is **partially satisfied** by T10.2 — implementation + tests OBSERVED; the on-HW
toast display + opt-out is X10.1 (user-run).

**Decisions:** **D-131** decided (FINAL) — shell-notification channel, toasts ON by default
opt-out. D-132 remains PENDING (T10.5).

### T10.3 — Profile management: rename / delete / duplicate (COMPLETE, 2026-10-16)

**Implemented (product):**

- **CLI:** `dis-play profile delete <name>`, `dis-play profile rename <old> <new>`,
  `dis-play profile dup <src> <dst>`. `src/main.rs`'s `profile` dispatch was restructured into a
  single `match args[1]` with `list`/`capture`/`show`/`delete`/`rename`/`dup` arms; the `usage:`
  fallback string lists the new subcommands.
- **`product/src/core/persistence.rs`:** three new file ops on the existing
  `%LOCALAPPDATA%\dis-play\profiles` dir — `persist_rename` (load old → set `name` → save new →
  remove old), `persist_duplicate` (copy with a new `name`, source untouched), `persist_delete`.
  Guards: empty / self (same sanitized stem) → `Error::Usage`; existing target →
  `Error::Io(AlreadyExists)`; missing delete target → `Error::Io(NotFound)` (never a silent no-op).
- **`product/src/cmd/profile.rs`:** composite `rename_profile` / `duplicate_profile` /
  `delete_profile` (used by both the CLI wrappers and the tray). The **rename-reference spike**
  (D-133) is resolved here: after the file move, any `hotkeys.json` entry equal to the old name is
  rewritten (via the new `core::hotkeys::save_hotkey_config` + pure `rename_in_config`), and the
  last-known-good `source` label is updated when it matched (best-effort; a self-contained lkg copy
  still recovers regardless).
- **`product/src/windows/prompt.rs`:** new `confirm_box` — a stock `MessageBoxW`
  (`MB_YESNO | MB_ICONQUESTION`, Yes-only) used to confirm a delete. Already-enabled
  `Win32_UI_WindowsAndMessaging` feature; **no new OS API/crate/dependency**.
- **`product/src/cmd/tray.rs`:** each saved profile is now a **per-profile submenu**
  `Apply` / `Rename…` / `Duplicate…` / `Delete` (D-133). New id ranges
  `ID_BASE_RENAME=0x1000`, `ID_BASE_DUP=0x2000`, `ID_BASE_DELETE=0x3000`; `MenuAction` gained
  `RenameProfile` / `DuplicateProfile` / `DeleteProfile`; `action_for` maps every range
  (`base .. base + count`). Rename/Duplicate reuse `prompt::input_box` (prefilled with the current
  name / `<name>-copy`); Delete uses `confirm_box`. Submenus are attached with `MF_POPUP` so
  `DestroyMenu(parent)` frees them (no double-free).
- **`product/README.md`:** Tray app menu description updated; CLI table gained the three
  profile-management rows. **`product/CHANGELOG.md`:** Unreleased entry added.

**Evidence (target HW, 2026-10-16):**
- `cargo test --release` → **83/83 pass** (was 72; +11: `persistence` rename/dup/delete
  round-trips + guards, `hotkeys::save_hotkey_config`/`rename_in_config`, tray `action_for`
  management id ranges) (**OBSERVED**).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean; `cargo build --release` →
  clean (**OBSERVED**); `dis-play.exe` 1,561,600 B; `dis-play-tray.exe` 1,461,248 B (**OBSERVED**).
- **Pending user-run (not yet OBSERVED):** opening the tray and exercising the per-profile
  submenu — Rename…/Duplicate…/Delete via the prompt + confirm dialog — and confirming the
  profile files under `%LOCALAPPDATA%\dis-play\profiles` (and any `hotkeys.json` reference)
  update accordingly and survive a tray restart.

**Gate impact:** Phase-10 gate item 1 ("Save Current / rename / delete / duplicate profiles
entirely from the tray; state persists across restarts") is now **implementation-complete** by
T10.1 (Save Current) + T10.3 (rename/delete/duplicate); the on-HW tray interaction is pending
user-run.

**Decisions:** **D-133** decided (FINAL) — per-profile submenu + rename rewrites hotkey/lkg
references. D-132 remains PENDING (T10.5).

### T10.4 — Active-profile indicator (COMPLETE, 2026-10-16)

**Implemented (product):**

- **Definition of "active" = the existing last-known-good record** (`LastKnownGood.source`,
  `%LOCALAPPDATA%\dis-play\state\last-known-good.json`) — **no new state** and no new
  dependency (the T10.4 feasibility note: "reads existing lkg + apply state").
- **`product/src/cmd/tray.rs`:**
  - `active_profile() -> Option<String>` — best-effort read-only read of lkg `source`.
  - pure `active_label(active: Option<&str>) -> String` → `active: '<name>'` / `active: (none)`;
    pure `is_active(active, name) -> bool` (exact match). Both unit-tested.
  - `status_line()` (top disabled menu line) now leads with the active profile:
    `active: '<name>' — verification <status>` (or `live query failed` /
    `active: (none) — apply a profile to set one` / `active: ? — app data dirs unavailable`).
  - tooltip setter split: new `set_tooltip()` (NIM_MODIFY, no stdout) + `set_status()` =
    `set_tooltip()` + `println!`. `show_menu` now calls `set_tooltip(hwnd, &status)` on every
    open, so the tooltip always names the active profile without console spam.
  - **Menu indicator:** the active profile's top-level submenu and its `Apply` child carry
    `MF_CHECKED` (visible closed and open); other profiles unchanged. `action_for` id mapping
    and the T10.3 submenu structure are untouched.
- **`product/README.md`:** Tray app section documents the checkmark + `active: '<name>'` in the
  menu/tooltip. **`product/CHANGELOG.md`:** Unreleased entry added.

**Evidence (target HW, 2026-10-16):**
- `cargo test --release` → **85/85 pass** (was 83; +2: `is_active_matches_exact_name_only`,
  `active_label_names_profile_or_none`) (**OBSERVED**).
- `cargo clippy --all-targets --all-features -- -D warnings` → clean; `cargo build --release` →
  clean (**OBSERVED**); `dis-play.exe` 1,565,696 B; `dis-play-tray.exe` 1,464,320 B (**OBSERVED**).
- **Pending user-run (not yet OBSERVED):** opening the tray menu and visually confirming the
  checkmark on the active profile's submenu and the `active: '<name>'` text in the menu status
  line / tooltip.

**Gate impact:** supports Phase-10 gate items 1–2 (the tray is now a full manager with visible
state); no gate item is exclusively about the indicator.

**Decisions:** **none new** — T10.4 consumes the OBSERVED last-known-good state and introduces no
new behavior choice. D-132 remains PENDING (T10.5).

### T10.5 — Per-profile hotkeys (COMPLETE, 2026-10-16)

**Implemented (product):**

- **Schema (D-132, additive):** `product/src/core/hotkeys.rs` — `HotkeyConfig` gains
  `#[serde(default)] bindings: Vec<HotkeyBinding>` alongside the legacy
  `#[serde(default)] profiles: Vec<String>`; new `HotkeyBinding { profile, hotkey }`. A v1.0
  file that only carries `profiles` parses unchanged (bindings empty) and the Ctrl+Alt+D toggle
  is untouched — no destructive migration.
- **Combination parsing (pure, no Win32):** new `ParsedHotkey { ctrl, alt, shift, win, vk }`
  with `parse_hotkey("Ctrl+Alt+W")` → modifiers + virtual-key code (letters/digits/F1–F24 +
  named keys, case-insensitive), `canonical()`/`Display` (fixed modifier order), and
  `vk_name(vk)`. A combination requires **≥1 modifier** (a bare key would hijack typing).
  Virtual-key codes are the DOCUMENTED `winuser.h` values hardcoded in `core` so the module
  stays crate-free/unit-testable; the tray converts to `HOT_KEY_MODIFIERS`/VK at registration.
- **Registration (`product/src/cmd/tray.rs`):** `register_bindings` registers each binding as
  `HK_BINDING_BASE + index` (0x5000+), `MOD_NOREPEAT`, on the startup thread; `WM_HOTKEY` with a
  binding id applies the bound profile through the **same** `apply_profile` path
  (`on_hotkey_binding`). Unregistered ids are tracked in a `static BOUND_HOTKEYS: Mutex<Vec<(i32,
  String)>>` and released on teardown (`unregister_bindings`) and before each re-registration.
  Each key is **best-effort**: a combination already owned by another app
  (`ERROR_HOTKEY_ALREADY_REGISTERED`, 1409) is logged per key and never prevents the rest.
- **Reference integrity:** `cmd::profile::rename_profile` now also rewrites `bindings[].profile`
  (`rename_bindings`), and `delete_profile` drops the deleted profile from both `profiles` and
  `bindings` (`remove_binding`) — so no stale `hotkeys.json` entry points at a missing profile.

**Evidence (target HW, 2026-10-16):**
- `cargo check --all-targets`, `cargo clippy --all-targets --all-features -- -D warnings` →
  clean (**OBSERVED**).
- `cargo test --release` → **99/99 pass** (was 85; +14 — see T10.6 for the split) (**OBSERVED**).
- `cargo build --release` → clean; `dis-play.exe` **1,608,192 B**, `dis-play-tray.exe`
  **1,508,864 B** (**OBSERVED**); `dis-play --version` → `dis-play 1.0.0-rc` rc=0 (**OBSERVED**).
- **Pending user-run (X10.2, not yet OBSERVED):** fire each per-profile hotkey on HW; bind the
  same combo to two profiles and confirm the conflict message; confirm the menu path still applies
  when a key is claimed by another app.

**Gate impact:** Phase-10 gate item 3 ("each profile can bind its own hotkey; conflicts detected
and surfaced; `ERROR_HOTKEY_ALREADY_REGISTERED` per-key handled") is **implementation-complete**
by T10.5 + T10.6; on-HW behavior is X10.2 (user-run).

**Decisions:** **D-132** decided (FINAL) — per-profile bindings, additive schema, legacy toggle
kept.

### T10.6 — Hotkey config UI / "learn by press" (COMPLETE, 2026-10-16)

**Implemented (product):**

- **New `product/src/windows/hotkey_capture.rs`:** a modal popup (modeled on `windows::prompt`)
  that reads the **next** key combination; modifier state comes from `GetKeyState` at the instant
  of the key press (Ctrl/Alt/Shift/Win), so the returned `Captured::Combo("Ctrl+Alt+W")` reflects
  what the user actually held. `Delete` (no modifier) → `Captured::Clear`; `Escape` → cancel;
  a bare or unsupported key updates the on-screen hint and waits. `WM_KEYDOWN`/`WM_SYSKEYDOWN`
  return 0 (suppresses the Alt system-menu); `WM_SYSCHAR` is swallowed (no beep). A process-wide
  `is_active()` flag makes the tray WndProc ignore tray/hotkey messages while the dialog is up.
  Built only from the already-enabled `windows` crate — **no new OS API/crate/feature**.
- **Tray wiring (`product/src/cmd/tray.rs`):** each per-profile submenu gains
  `Set hotkey…  [<current combo>]` (`ID_BASE_HOTKEY = 0x4000`, `MenuAction::SetHotkey`).
  `set_hotkey_ui` performs learn-by-press capture, then **conflict detection**:
  (a) config-level — the combo is already bound to another profile (`binding_conflict`) or is the
  built-in `Ctrl+Alt+D` toggle (`TOGGLE_HOTKEY`); (b) OS-level — `RegisterHotKey` returns
  `ERROR_HOTKEY_ALREADY_REGISTERED` for the new key. Conflicts are reported via tooltip + toast
  and do **not** change the saved config. On success the binding is saved and all bindings are
  re-registered. `DELETE` clears; the outcome is logged (T7.1).
- **README** (`product/README.md`): the "Global hotkey" section is now **Global hotkeys**
  (toggle pair + per-profile bindings + learn-by-press + conflict rules); the Tray-app section
  lists `Set hotkey…`. **CHANGELOG** (`product/CHANGELOG.md`): Unreleased entries for T10.5 + T10.6.

**Evidence (target HW, 2026-10-16):**
- Same run as T10.5: `cargo test --release` → **99/99** (+14 total across T10.5/T10.6:
  `core::hotkeys` 9 — legacy-config parse, bindings round-trip, parse accept/reject, canonical,
  `vk_name`, conflict, set/remove/find, rename; `cmd::tray` 3 — hotkey id range, `to_modifiers`,
  menu label; `windows::hotkey_capture` 2 — active-flag guard, modifier-key recognition)
  (**OBSERVED**); clippy `-D warnings` clean (**OBSERVED**); release build clean (**OBSERVED**).
- **Pending user-run (X10.2, not yet OBSERVED):** open a profile's `Set hotkey…`, press a combo,
  confirm it registers + applies; press a combo already used by another profile → conflict message;
  confirm the Windows-native capture dialog and hints.

**Gate impact:** completes the implementation half of gate item 3 (see T10.5).

**Decisions:** none new (implements D-132; the learn-by-press UI uses `WM_KEYDOWN` +
`GetKeyState`, DOCUMENTED).

Other tasks: **T10.7–T10.8 not executed.**

## Status

**IN PROGRESS (2026-10-16)** — T10.1 (tray "Save Current Configuration…"), T10.2 (toast
notifications), T10.3 (profile management: rename / delete / duplicate + CLI), T10.4
(active-profile indicator), T10.5 (per-profile hotkeys) and T10.6 (hotkey config UI /
learn-by-press) COMPLETE: implemented + `cargo test --release` **99/99** +
`clippy -D warnings` clean + release build (OBSERVED on target HW); on-HW prompt/menu
interaction (T10.1, T10.3, T10.4), toast display/opt-out (T10.2, X10.1), and per-profile
hotkey fire / conflict / capture interaction (T10.5, T10.6, X10.2) pending user-run.
Tasks T10.7–T10.8 remain PLANNED. **D-131** (toast channel), **D-132** (per-profile hotkeys,
additive schema) and **D-133** (profile-management submenu) are FINAL. Recommended sequence
(`ROADMAP.md` §4): T10.1 → T10.5 → T10.2 → T10.6 → T10.7; next executable task is
**T10.7** (settings surface) or **T10.8** (recent switches + undo).
