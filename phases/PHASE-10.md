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
| T10.1 | Tray **Save Current Configuration…** (prompted name, capture live topology via the existing `profile capture` path) | tray menu action + saved profile | **PLANNED** |
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

None — no tasks executed yet. Per user instruction (2026-09-26), documentation only: no new task or phase was executed.

## Status

**PLANNED (not started, 2026-09-26)** — tasks T10.1–T10.8 detailed from `ROADMAP.md` §4. D-131/D-132 reserved but undecided. Recommended precondition: Phase 9 (v1.0 released). No code executed.
