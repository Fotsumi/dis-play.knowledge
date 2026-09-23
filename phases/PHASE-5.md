# Phase 5 — Tray Application

## Objective
Wrap the CLI logic in a Windows tray application: menu lists profiles, selecting one drives `apply_profile` (Phase 3) with verification (Phase 4). No hotkeys yet.

## Scope
- In: tray icon + context menu; menu items = saved Profiles; selection → apply + verify.
- Out: hotkeys (Phase 6), hardening/packaging (Phase 7).

## Tasks
| # | Task | Output |
|---|---|---|
| T5.1 | Tray app skeleton (icon + menu) | running tray process |
| T5.2 | Menu lists saved Profiles; selection → apply_profile | wired menu |
| T5.3 | Post-apply status shown in menu (verify result) | status display |

## Gate
- [ ] Tray app runs and a menu selection applies the intended profile on HW. **OBSERVED**
- [ ] Verify result visible after apply. **OBSERVED**

## Potential Blockers
- Needs Phase 3+4 working; tray is presentation over them.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 4_

## Status
**BLOCKED by Phase 4.**
