# Phase 5 — Tray Application

## Objective
Wrap the CLI logic in a Windows tray application: menu lists profiles, selecting one drives `apply_profile` (Phase 3) with verification (Phase 4). No hotkeys yet.

## Scope
- In: tray icon + context menu; menu items = saved Profiles; selection → apply + verify; verify result visible in the tray (tooltip + menu status line).
- Out: hotkeys (Phase 6), hardening/packaging (Phase 7), auto-recover "without user intervention beyond a log line" is D-115 tray scope but is implemented as a **manual** `Recover last-known-good` menu item (full auto-recover on boot/mismatch = Phase 7 hardening).

## Tasks
| # | Task | Output |
|---|---|---|
| T5.1 | Tray app skeleton (icon + menu) | `cmd/tray.rs` — hidden window + `Shell_NotifyIconW` icon + `CreatePopupMenu` context menu |
| T5.2 | Menu lists saved Profiles; selection → apply_profile | menu ids 1..N → `apply_profile` (reuses `core/apply` planning + gated `set_display_config_from_profile`) |
| T5.3 | Post-apply status shown in menu (verify result) | tooltip via NIM_MODIFY + disabled status line at top of the menu; menu rebuilt on every click |

## Gate
- [x] Tray app runs and a menu selection applies the intended profile on HW. **OBSERVED** (2026-09-25, target HW)
- [x] Verify result visible after apply. **OBSERVED** (2026-09-25, target HW)

## Potential Blockers
- Needs Phase 3+4 working; tray is presentation over them. ✓ (both complete)
- Tray apps need a real message loop + a window that can receive `Shell_NotifyIcon` callback messages — the `windows` crate modules for windowing/menus/notify-icons were unverified before this phase. Resolved by probing the crate on this host first (see Implementation).

## Implementation
Product changes (in `product/`; `cargo build --release` clean, `cargo test` 39/39 on this host):
- **`Cargo.toml`** — added `windows` crate features for the tray UI: `Win32_UI_WindowsAndMessaging` (window/menu/msg APIs + `NOTIFYICONDATAW`/`Shell_NotifyIconW`), `Win32_UI_Shell`, `Win32_Graphics_Gdi` (WNDCLASSEXW references GDI handles), `Win32_System_LibraryLoader` (`GetModuleHandleW`).
- **`src/cmd/tray.rs` (new)** — `display-manager tray`:
  - **T5.1 skeleton:** registers a window class, creates a hidden 1x1 window (WndProc = `tray_wnd_proc`), installs a `Shell_NotifyIconW` notification icon (`NIM_ADD`, `NIF_MESSAGE | NIF_TIP | NIF_ICON`, callback `WM_APP+40`, default app icon via `LoadIcon(IDI_APPLICATION)` — no .ico asset this phase), then runs a blocking `GetMessage` loop. Right- or left-click on the icon posts the callback message → `show_menu` builds a `CreatePopupMenu` + `AppendMenuW` menu at the cursor (`TrackPopupMenu` with `TPM_RIGHTBUTTON | TPM_RETURNCMD`).
  - **T5.2 menu → apply:** one `MF_STRING` item per saved profile (id = `ID_BASE_PROFILE + index`, `1..N`); a disabled item when no profiles exist. Selection → `apply_profile` (loads the profile, calls the gated `set_display_config_from_profile(true, …)` — same code path as `cmd/apply.rs`), then re-verifies and records last-known-good.
  - **T5.3 status display:** every apply/verify/recover ends in `set_status` — the result is written to the tray **tooltip** (`Shell_NotifyIconW NIM_MODIFY, NIF_TIP`) and printed to stdout (evidence path). The menu's top line is a **disabled status item** rebuilt fresh on every click: it re-loads last-known-good and runs a **read-only live verification** against it (`status: last applied '<name>' — verification OK/PARTIAL/FAILED`), so the verify result is always visible before and after an apply. Fixed commands: `Verify live topology` (read-only verify of lkg), `Recover last-known-good` (gated re-apply, mirrors `cmd/recover.rs`), `Refresh profiles`, `Exit` (`PostQuitMessage` → loop exits → `NIM_DELETE` + `DestroyWindow`).
  - D-114 honored: last-known-good is updated **only on rc==0 AND verification OK**; a failed/mismatched apply leaves it untouched and reports so.
- **`src/cmd/mod.rs`** — `pub mod tray;`; **`src/main.rs`** — dispatch `"tray" => cmd::tray::run()`, usage string updated.
- **Pure/testable surface:** `MenuAction` + `action_for(cmd, profile_count)` (menu-id → action mapping) and `clamp_tip` (127-char tooltip clamp). 4 new unit tests (profile-id mapping, fixed ids, out-of-range → None, clamp). **39/39 tests pass.**

## Actual Results (all on target HW, 2026-09-25)
### T5.1 — Skeleton runs
- `display-manager tray` (release build) launched from a console: `tray: icon installed; click the icon to open the profile menu. Exit via the menu.` **OBSERVED.** The tray icon appeared next to the system clock; the process stayed alive in the message loop.
- Window/icon FFI chain validated first in an isolated probe on this host (RegisterClassExW atom, CreateWindowExW, Shell_NotifyIconW NIM_ADD → true, menu build) before being folded into the product module. **OBSERVED.**

### T5.2 + T5.3 — Menu-driven apply + verify result visible
- Menu opened from the tray icon listed all saved profiles (`work`, `work-notv`, `ghost`, `duplicate-vie`, …) with the status line at the top. **OBSERVED.**
- **Selecting `work`** from the menu → `applied 'work' - verification OK (last-known-good updated)`; the tooltip + menu status line showed the verification result. **Gate criterion 2 evidence.** **OBSERVED.**
- **Selecting `work-notv`** (TV disabled in that profile) → `applied 'work-notv' - verification OK (last-known-good updated)` — the TV was really DETACHED (this is the same profile whose CLI apply detached the TV in Phase 4); the tray honestly verified *its* intent (D-113). **OBSERVED.**
- **Re-selecting `work`** from the menu → `applied 'work' - verification OK (last-known-good updated)` — the detached TV was **re-attached** through the same QDC_ALL_PATHS path (D-116), restoring the 3-display topology. **OBSERVED.**
- **`Verify live topology`** from the menu → `verify 'work': OK (3 intended, 3 active, 0 finding(s))` — read-only verification surfaced in the tray. **OBSERVED.**
- **`Recover last-known-good`** from the menu → `recovered 'work' - verification OK` — the gated recovery path driven from the tray. **OBSERVED.**
- **`Refresh profiles`** → `menu refreshed`; **`Exit`** → the process left the message loop, removed the icon and exited (verified: no `display-manager` process remained). **OBSERVED.**
- **Final state check (read-only CLI):** `verify work` → `status: OK` (`intended enabled targets: 3 active: 3`, no findings) and `last-known-good.json` = `work` — the destructive `work-notv` apply performed during the tray test was fully reverted by re-applying `work` from the tray. **OBSERVED.**

## Gate Verdict
- Criterion 1 — Tray app runs and a menu selection applies the intended profile on HW: **SATISFIED (OBSERVED)** — the tray process ran with an installed icon; selecting `work` APPLIED it (verified OK), selecting `work-notv` really detached the TV, and re-selecting `work` re-attached it (live topology restored, `verify work` → OK).
- Criterion 2 — Verify result visible after apply: **SATISFIED (OBSERVED)** — after each menu apply the tray tooltip + menu status line showed the verification verdict (`applied 'work' - verification OK (last-known-good updated)`); the status line re-verifies live on every menu open.

**STATUS: COMPLETE.**

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-117 | Tray app = a **`tray` subcommand of the same binary** (`display-manager tray`), not a separate crate/binary — it reuses `core/apply`, `core/verify`, `core/recovery` and the gated `set_display_config_from_profile` in-process. No daemonization/packaging yet (Phase 7). | **FINAL** (OBSERVED: `display-manager tray` ran on HW) |
| D-118 | Tray status surface = **tray tooltip** (NIM_MODIFY/NIF_TIP after every apply/verify/recover) **+ a disabled status line at the top of the context menu** that re-verifies last-known-good read-only on every menu open (the menu is rebuilt per click). The verify result is therefore always visible before and after an apply. | **FINAL** (OBSERVED: `applied 'work' - verification OK` + `verify 'work': OK (3 intended, 3 active)` visible in the tray) |
| D-119 | Menu command ids: profile items = `1..N` (index into the freshly-listed names), fixed ids for `Verify`/`Recover`/`Refresh`/`Exit`; dispatch via `TrackPopupMenu(TPM_RETURNCMD)` synchronous return (no WM_COMMAND plumbing). Pure `action_for(cmd, count)` maps id → `MenuAction`. | **FINAL** (OBSERVED: apply/verify/recover/exit all dispatched from the menu) |
| D-120 | Tray icon = **`LoadIcon(IDI_APPLICATION)`** (system default app icon) for Phase 5; a purpose-built `.ico`/`CreateIcon` icon is deferred to Phase 7 packaging. | FINAL (scope) |
| D-121 | The tray's `Recover last-known-good` is the **manual** recovery surface (mirrors the gated `recover` CLI). D-115's "auto-recover without user intervention beyond a log line" (e.g. on startup / on mismatch) remains **Phase 7 hardening scope** — this phase only provides the manual menu path. | FINAL (scope) |

## Open Items / Notes
- The tray re-applies whatever profile the user picks, including destructive ones (`work-notv` detaches the TV) — the same trust model as the gated CLI apply. Verification reports honestly per the profile's intent (D-113); recovery is one menu click away.
- Tooltip text is clamped to 127 chars (szTip is `[u16; 128]` incl. NUL); menu status line is unbounded.
- `desired_mode` remains verified-but-not-enforced (D-112); mode-changing applies are still future scope.
- Phase 5 keeps the single-instance question open: a second `display-manager tray` registers the same class name (atom 0 = already registered) and creates a second icon — harmless, but Phase 7 should decide single-instance semantics.
- Scratch/fixture profiles from Phases 3–4 (`work`, `work-notv`, `ghost`, `duplicate-vie`, `verify-mode-mismatch`, `before-apply`, `after-apply`) remain under `%LOCALAPPDATA%\display-manager\profiles` and were listed by the tray menu.

## Status
**COMPLETE** — both gate criteria satisfied with OBSERVED evidence on target HW: the tray app ran with an installed icon, its menu listed the saved profiles, a selection applied the profile (including a destructive `work-notv` detach that was reverted by re-applying `work` from the same menu), and the verify result was visible in the tray tooltip + menu status line after every apply. 39/39 tests pass, release build clean. Ready for Phase 6 (Hotkeys).