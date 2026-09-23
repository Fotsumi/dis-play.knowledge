# Phase 3 — Apply (`apply_profile`)

## Objective
Apply a captured profile via `SetDisplayConfig` with the validated flags (SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG), then verify the resulting topology matches intent.

## Scope
- In: build target path/mode set from Profile; call SetDisplayConfig APPLY; capture return code + post-state.
- Out: verification/recovery logic (Phase 4), UI (Phase 5).

## Tasks
| # | Task | Output |
|---|---|---|
| T3.1 | Build target path/mode set from Profile | apply fn |
| T3.2 | Call SetDisplayConfig APPLY with validated flags; capture return code | FFI + result handling |
| T3.3 | Post-apply state capture (reuse Phase 0 read-only commands) | before/after diff |

## Gate
- [ ] `apply_profile` applies and the resulting topology matches intent on real HW. **OBSERVED**
- [ ] Return code captured for at least one successful + one failed apply. **OBSERVED**

## Potential Blockers
- SetDisplayConfig APPLY is dangerous — must be gated (D-002). Never auto-applies; explicit user action only.
- Depends on Phase 2 producing a correct Profile to apply.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 2_

## Status
**BLOCKED by Phase 2.**
