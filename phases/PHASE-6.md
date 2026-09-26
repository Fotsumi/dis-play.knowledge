# Phase 6 — Hotkeys

## Objective
Register global hotkeys that trigger `apply_profile` for a chosen Profile, so the user can switch without opening the tray menu.

## Scope
- In: register hotkey(s) → apply selected Profile (reuse Phase 3+4 path).
- Out: hardening/packaging (Phase 7).

## Tasks
| # | Task | Output |
|---|---|---|
| T6.1 | Register global hotkey(s) via RegisterHotKey / low-level hook | registered key(s) |
| T6.2 | Hotkey fire → apply_profile for bound Profile | wired handler |
| T6.3 | Conflict handling (key already taken by another app) | graceful error |

## Gate
- [x] Hotkey fires and applies the intended profile on HW. **OBSERVED**
- [x] Key conflict produces a clear error, not a crash. **OBSERVED**

## Potential Blockers
- Needs Phase 3+4 working; hotkey is a trigger over them.

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-122 | The global hotkey (Ctrl+Alt+D) **toggles between a configured pair of profiles** (`%LOCALAPPDATA%\dis-play\config\hotkeys.json`, e.g. `["samtv","samtv-notv"]`), applied via `toggle_other` — deterministic and independent of verification results. REJECTS the initial design where the hotkey cycled from `last-known-good.source` through ALL saved profiles: that design was **OBSERVED to wedge** on HW — lkg only advances on verification OK, so a persistent mismatch (a display taken away for repair) made every press re-apply the same profile forever. | **FINAL** (OBSERVED: toggle worked press1 `samtv-notv`/press2 `samtv`, both verification OK) |
| D-123 | Taskbar icon = **`taskbar-icon.png` in the `product/` repo (`product/taskbar-icon.png`), embedded at compile time (`include_bytes!`) and decoded to `HICON` via GDI+** (`GdipCreateBitmapFromFile` → `GdipCreateHICONFromBitmap`, temp file for the file-based decoder). Replaces the Phase 5 `LoadIcon(IDI_APPLICATION)` placeholder (D-120 deferral). Failure degrades to the system icon with a warning, never a crash. **[SUPERSEDED by repo move]** the icon resource now lives in `product/` (was: knowledge repo root) — per the product-files-in-`product/` rule | **FINAL** (OBSERVED: `tray: icon installed` with no decode warning on target HW) |

## Actual Results
_Phase 6 executed 2026-09-26 on target HW (this host)._

### T6.1 — Hotkey registration (OBSERVED)
`dis-play tray` → `tray: icon installed; ...` + `tray: hotkey registered: Ctrl+Alt+D toggles the configured profile pair`. `RegisterHotKey(Some(hwnd), id, MOD_ALT|MOD_CONTROL|MOD_NOREPEAT, VK_D)` posts `WM_HOTKEY` to the tray window, handled in the same WndProc as the tray icon.

### T6.2 — Hotkey fire → apply (OBSERVED, user-run on target HW)
With `hotkeys.json = {"profiles": ["samtv", "samtv-notv"]}` and lkg = `samtv` (TV on):
- press 1 → `applied 'samtv-notv' - verification OK (last-known-good updated)` — **TV detached**.
- press 2 → `applied 'samtv' - verification OK (last-known-good updated)` — **TV re-attached**.
- Final: `verify samtv` → OK (2 intended, 2 active); lkg = `samtv`.

The hotkey reuses the exact menu apply path (`apply_profile` → gated `set_display_config_from_profile` → post-apply `verify_profile` → lkg on rc==0 AND OK), so the tooltip/status line shows the verdict identically.

### Design finding — the lkg-based cycle wedged (OBSERVED)
First implementation advanced from `last-known-good.source` through ALL saved profiles. On HW the post-apply verification for `work`/`work-notv` stayed **PARTIAL** because a display (VIE2701) had been physically taken away (in for repair) and SAM0D20's live rotation differed from the captured profile (`rot=0` vs `rot=270`). Since lkg only updates on OK, the cycle position never advanced and EVERY press re-applied `work-notv` — the user's second press could not restore `work`. Root cause: **verification-gated state is not a reliable cycle position** (D-122). Fixed by the deterministic toggle.

### T6.3 — Conflict handling (OBSERVED)
Launching a second tray instance while the first held Ctrl+Alt+D:
`tray: warning: global hotkey Ctrl+Alt+D NOT registered (the combination Ctrl+Alt+D is already in use by another app) - the tray menu still works` — process kept running (no crash), menu still usable. Detected via `RegisterHotKey`'s `ERROR_HOTKEY_ALREADY_REGISTERED` (1409) mapped from `windows::core::HRESULT::from_win32`.

### Icon task (user request) (OBSERVED)
`tray: icon installed` printed with **no decode warning** on every run → `taskbar-icon.png` embedded + GDI+-decoded successfully; the tray shows the app icon, not the Phase 5 `IDI_APPLICATION` placeholder. `GdiplusStartup`/`GdiplusShutdown` wrap the decode; the icon handle is `DestroyIcon`'d after `NIM_DELETE` on exit.

### Environment note (OBSERVED)
VIE2701 is physically absent (in for repair) — the discrete GPU (RX 9070 XT) enumerates it as an inactive target only. Profiles `work`/`work-notv` (VIE-based) now resolve with a skipped/unknown VIE entry. Two new profiles capture the current hardware: `samtv` (SAM + TV active) and `samtv-notv` (SAM only, TV disabled); both `validate` → rc=0 and verify OK on HW.

## Tests
- `cargo test` → **47/47 pass** (39 prior + 5 hotkey-toggle + 2 icon + 1 icon-bytes). New:
  - `core::hotkeys::toggle_other*` — pair swap, unknown/absent → first, empty pair → None; config JSON round-trip; missing config → NotFound (no panic).
  - `windows::icon::taskbar_icon_png_is_a_valid_png` — the `include_bytes!` contract (file exists at repo root, PNG magic).
  - `windows::icon::decode_rejects_invalid_png` — GDI+ decode failure path returns `None` (graceful).
  - `cmd::tray::hotkey_constants_are_app_unique` — id/vk/modifier consistency.
- Release build **clean (zero warnings)**.

## Status
**COMPLETE** — both gate criteria satisfied with OBSERVED evidence on target HW.
