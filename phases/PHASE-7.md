# Phase 7 — Hardening

## Objective
Harden the tray app for real use: error handling, logging, single-instance, autostart option, packaging (MSI/NSIS), and a clean uninstall path.

## Scope
- In: global error handling + log file; single-instance guard; optional autostart; installer build.
- Out: none — this is the final phase before release.

## Tasks
| # | Task | Output |
|---|---|---|
| T7.1 | Global error handling + structured log file | no silent panics |
| T7.2 | Single-instance guard (mutex) | one instance only |
| T7.3 | Optional autostart (registry run key) | opt-in autostart |
| T7.4 | Installer build (MSI/NSIS) + uninstall path | installable artifact |

## Gate
- [ ] No silent panics across a forced-failure matrix on HW. **OBSERVED**
- [ ] Install → run → uninstall is clean; no leftover state. **OBSERVED**

## Potential Blockers
- Needs Phases 3–6 stable; hardening wraps them.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 6_

## Status
**BLOCKED by Phase 6.**
