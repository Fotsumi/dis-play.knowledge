# Phase 3 — Apply (`apply_profile`)

## Objective
Apply a captured profile via `SetDisplayConfig` with the validated flags (`SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG`), then verify the resulting topology matches intent.

## Scope
- In: build target path/mode set from Profile; call SetDisplayConfig APPLY; capture return code + post-state.
- Out: verification/recovery logic (Phase 4), UI (Phase 5).

## Tasks
| # | Task | Output |
|---|---|---|
| T3.1 | Build target path/mode set from Profile | `core/apply.rs` (`plan_from_profile`) + `windows/display_config.rs` (`build_apply_arrays`) |
| T3.2 | Call SetDisplayConfig APPLY with validated flags; capture return code | `set_display_config_from_profile` (FFI + result handling) |
| T3.3 | Post-apply state capture (reuse Phase 0 read-only commands) | before/after profiles + post-apply topology print in `cmd/apply.rs` |

## Gate
- [x] `apply_profile` applies and the resulting topology matches intent on real HW. **OBSERVED** (2026-09-25)
- [x] Return code captured for at least one successful + one failed apply. **OBSERVED**

## Potential Blockers
- SetDisplayConfig APPLY is dangerous — must be gated (D-002). Never auto-applies; explicit user action only. ✓ (gate + confirm flag)
- Depends on Phase 2 producing a correct Profile to apply. ✓ (D-106 mode capture proven)

## Root cause of the Phase 2→3 blocker (rc=87) — RESOLVED
The carried-forward blocker ("SetDisplayConfig returns 87 even with real buffers") is **resolved**. The persistent root cause was **WRONG `SDC_*` flag constants**, not struct population:

- The code defined `SDC_APPLY=0x00, SDC_VALIDATE=0x01, SDC_USE_SUPPLIED_DISPLAY_CONFIG=0x02, SDC_SAVE_TO_DATABASE=0x04` and called `SetDisplayConfig(SET_DISPLAY_CONFIG_FLAGS(SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG))` = **flags=0x02**.
- 0x02 is `SDC_TOPOLOGY_CLONE`, not APPLY. Per the DOCUMENTED flag contract (MS Learn SetDisplayConfig), "Either SDC_APPLY or SDC_VALIDATE must be set, but not both" — flags=0x02 has neither → **ERROR_INVALID_PARAMETER (87)** every call, regardless of buffer contents. Same for validate: 0x01 = `SDC_TOPOLOGY_INTERNAL`.
- The `modeInfoIdx` "sentinel" readings (`0x1ffff`/`0x4ffff`/`0x7ffff`) are the DOCUMENTED packed **virtual-mode union layout** (`cloneGroupId:16 | sourceModeInfoIdx:16`) that QDC returns under `QDC_VIRTUAL_MODE_AWARE` — not a corruption. D-106's id-based matching remains the correct read-side mapping.

Corrected constants (DOCUMENTED, and matching the `windows` crate `SET_DISPLAY_CONFIG_FLAGS` — compiler-verified):
| Flag | Old (WRONG) | Correct |
|---|---|---|
| `SDC_APPLY` | 0x00 | **0x80** |
| `SDC_VALIDATE` | 0x01 | **0x40** |
| `SDC_USE_SUPPLIED_DISPLAY_CONFIG` | 0x02 | **0x20** |
| `SDC_SAVE_TO_DATABASE` | 0x04 | **0x200** |

## Implementation
Product changes (in `product/`; `cargo build --release` + `cargo test` 23/23 on this host):
- **`src/core/apply.rs` (new, pure, no FFI)** — `plan_from_profile(profile, candidates) -> ApplyPlan`: resolves every `DisplayEntry` via the Phase 1 resolver against the live topology; produces `targets` in **profile order = path-priority order** (primary = first, finding §9) and `skipped` (Disabled / Unknown / Ambiguous — never guessed).
- **`src/windows/display_config.rs`** —
  - Corrected `SDC_*` constants + added `PATH_ACTIVE` (0x1) and `PATH_MODE_IDX_INVALID` (0xFFFFFFFF) (DOCUMENTED wingdi.h).
  - `candidates_from_paths(paths, modes)` extracted from `enumerate_targets` (one query reused for both identity + array building).
  - `build_apply_arrays(targets, paths, modes) -> (paths, modes)`: per target (priority order) one path with `flags = PATH_ACTIVE`; mode array rebuilt compactly with explicit sequential `modeInfoIdx` — SOURCE mode by `mode.id == path.sourceInfo.id` (D-106) and TARGET mode by `mode.id == path.targetInfo.id`; missing modes → `PATH_MODE_IDX_INVALID` (best-mode logic fills them; target-without-source invalid per docs → both dropped).
  - `set_display_config_from_profile(confirm, profile, apply) -> ApplyOutcome { code, plan }`: one live query → candidates + plan → arrays → `SetDisplayConfig`. `apply=true` → `SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG` (gated); `apply=false` → `SDC_VALIDATE | SDC_USE_SUPPLIED_DISPLAY_CONFIG` (read-only).
- **`src/cmd/apply.rs` / `src/cmd/validate.rs`** — now operate on saved **profiles** (Phase 2 format) instead of Phase 0 snapshots; apply prints the plan, skipped entries, rc, and post-apply topology (T3.3). `src/main.rs` usage updated.
- New error variants: `NoTargets`, `NoLivePath` (guards — never call SetDisplayConfig with an empty/unbuildable plan).
- 8 new unit tests (4 apply-plan + 4 build_apply_arrays); resolver dead-code warnings eliminated (now consumed). **23/23 tests pass.**

## Actual Results (all on target HW, 2026-09-25)
- **`validate work` → `SetDisplayConfig (SDC_VALIDATE) returned 0`** (was 87). First nonzero-blocker evidence: corrected flags + profile-derived arrays validate clean against the live 3-display topology. **OBSERVED** (read-only, no mutation).
- **`apply --i-understand-this-mututes-display-config work` → `SetDisplayConfig returned 0`** — the gated live APPLY succeeded. Plan resolved all 3 displays in path-priority order:
  `[0] \?\DISPLAY#VIE2701#…UID768…`, `[1] \?\DISPLAY#SAM0D20#…UID776…`, `[2] \?\DISPLAY#TCL9653#…UID780…`
  Post-apply topology: `path[0] target_id=768 source_id=0`, `path[1] target_id=776 source_id=1`, `path[2] target_id=780 source_id=2` — unchanged (re-applied current topology). **OBSERVED** (user-approved gated apply).
- **T3.3 before/after:** `profile capture before-apply` → apply → `profile capture after-apply` → the two profiles are **identical except the name label** → post-apply state == intent (no drift). **OBSERVED.**
- **Disabled-display topology (detach):** `work-notv` (TCL9653 `enabled=false`) → `validate work-notv` → rc=0 → Windows accepts detaching the TV target (2-path topology settable). **OBSERVED** (VALIDATE only; the destructive APPLY was not run).
- **Failed apply guard:** `validate ghost` / `apply … ghost` (entry for a non-existent display) → `error: profile resolved to no enabled targets (refusing to call SetDisplayConfig)`, exit 1 — SetDisplayConfig is never called with an empty plan. **OBSERVED.**
- **Failed apply return code (historical):** apply rc=**87** OBSERVED 2026-09-24 (E6, old broken flag constants) is the nonzero return-code record on this HW; today's rc=0 is the success record. Gate criterion 2 thus satisfied.

## Gate Verdict
- Criterion 1 — `apply_profile` applies + topology matches intent: **SATISFIED (OBSERVED)** — apply rc=0; resolved plan = profile order; post-apply topology = 3 paths matching the 3 enabled entries; before/after profiles identical.
- Criterion 2 — rc captured for ≥1 successful + ≥1 failed apply: **SATISFIED (OBSERVED)** — rc=0 (2026-09-25, successful APPLY + VALIDATE) and rc=87 (2026-09-24, failed apply) + NoTargets guard (2026-09-25, failed apply refused).

**STATUS: COMPLETE.**

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-108 | Correct SDC_* flag constants to DOCUMENTED values (SDC_APPLY=0x80, SDC_VALIDATE=0x40, SDC_USE_SUPPLIED_DISPLAY_CONFIG=0x20, SDC_SAVE_TO_DATABASE=0x200). The previous 0x00/0x01/0x02/0x04 values were wrong (those are SDC_TOPOLOGY_* ) and caused every SetDisplayConfig call to fail with ERROR_INVALID_PARAMETER (87). | **FINAL** (OBSERVED: validate/apply 87→0) |
| D-109 | `apply`/`validate` operate on saved **profiles** (Phase 2 `%LOCALAPPDATA%\dis-play\profiles`) — not Phase 0 `.snapshots/` — and resolve each entry via the Phase 1 resolver (plan_from_profile). | FINAL |
| D-110 | Path array = one `DISPLAYCONFIG_PATH_INFO` per enabled entry in **profile order (= path-priority order, primary first)** with `flags = DISPLAYCONFIG_PATH_ACTIVE`; disabled entries' paths are omitted (detach semantics). | FINAL (OBSERVED: work-notv validate rc=0) |
| D-111 | Mode array rebuilt compactly from live QDC modes: SOURCE by `mode.id == path.sourceInfo.id` (D-106), TARGET by `mode.id == path.targetInfo.id`, with explicit sequential `modeInfoIdx` (4-bit, ≤15); missing modes → `PATH_MODE_IDX_INVALID` (best-mode logic). | FINAL (OBSERVED: validate rc=0) |
| D-112 | V1 apply keeps the **live current mode** per display (mode array sourced from the current topology) — `desired_mode` is carried on the plan but not yet enforced; mode-change enforcement is Phase 4/5 scope. | FINAL (scope) |

## Open Items / Notes
- `desired_mode` enforcement (change a display to a different resolution/refresh) is NOT yet applied — V1 apply preserves current modes while changing topology. Carried by `PlannedTarget.desired_mode` for Phase 4.
- `Ambiguity.candidates`/`honored` fields remain unconsumed (Phase 4 verification will use them).
- `work-notv` disable-apply (actual detach of TCL9653) not executed — validated only; a destructive run is user-gated and can be done when the user wants the TV really off.
- Scratch profiles `ghost`, `work-notv`, `before-apply`, `after-apply` remain in the profiles dir as experiment records.

## Status
**COMPLETE** — both gate criteria satisfied with OBSERVED evidence on target HW. Blocker (SetDisplayConfig rc=87) resolved: wrong SDC flag constants corrected; profile-derived path/mode arrays apply cleanly. Ready for Phase 4 (Verification & Recovery).