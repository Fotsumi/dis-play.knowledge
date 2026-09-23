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
- [ ] Hotkey fires and applies the intended profile on HW. **OBSERVED**
- [ ] Key conflict produces a clear error, not a crash. **OBSERVED**

## Potential Blockers
- Needs Phase 3+4 working; hotkey is a trigger over them.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 5_

## Status
**BLOCKED by Phase 5.**
