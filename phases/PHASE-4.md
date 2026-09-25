# Phase 4 — Verification & Recovery

## Objective
After apply, verify the live topology matches intent; on mismatch or failure, recover (re-apply known-good state) without user intervention beyond a log line.

## Scope
- In: post-apply verification (compare captured state to intended); recovery path (re-apply last-known-good Profile).
- Out: UI presentation of verify/recover status (Phase 5).

## Tasks
| # | Task | Output |
|---|---|---|
| T4.1 | Verify post-apply state vs intended topology | `core/verify.rs` (`verify_profile`) + `cmd/verify.rs` (`verify <profile>`) |
| T4.2 | Recovery: re-apply last-known-good Profile on mismatch | `core/recovery.rs` (last-known-good persistence) + `cmd/recover.rs` (`recover`) |
| T4.3 | Log line + optional user notification hook (no UI yet) | post-apply verification report + last-known-good logging in `cmd/apply.rs` |

## Gate
- [x] Verification detects a real mismatch on HW. **OBSERVED** (2026-09-25, target HW)
- [x] Recovery restores intended topology after a forced bad apply. **OBSERVED** (2026-09-25, target HW)

## Potential Blockers
- Needs Phase 3 apply working first; recovery is only meaningful if apply can fail. ✓ (Phase 3 gate complete)
- **NEW (found this phase):** a display DETACHED by a bad apply disappears from the active-path enumeration (QDC_ONLY_ACTIVE_PATHS), so it could NOT be re-targeted — re-attaching it required QDC_ALL_PATHS. Resolved below (D-116).

## Implementation
Product changes (in `product/`; `cargo build --release` clean, `cargo test` 35/35 on this host):
- **`src/core/verify.rs` (new, pure, no FFI)** — `verify_profile(profile, live) -> Verification { status, findings, intended, active }`. Intent is derived from the profile alone:
  - an `enabled` entry that resolves uniquely = must be ACTIVE; `disabled` = must be DETACHED; `desired_mode` (when present) = the mode the target must run.
  - `Findings`: `MissingTarget` (enabled display not active / no live candidate carries its evidence), `UnexpectedTarget` (active but should be detached, or not listed in the profile at all), `ModeMismatch` (live mode vs `desired_mode`, refresh compared with a 0.01 Hz epsilon so 59.94 vs 60.0 stays distinguishable).
  - Status rules (honest, never a guess): no findings → `OK`; findings + ≥1 intended target active → `PARTIAL`; findings + 0 intended active → `FAILED`.
  - Ambiguous entries (identical units) can't be attributed → verification does NOT fabricate a verdict on them.
  - Connected-aware: a detached (inactive) candidate present under QDC_ALL_PATHS is NOT treated as active.
- **`src/core/recovery.rs` (new, pure persistence)** — last-known-good record (`%LOCALAPPDATA%\display-manager\state\last-known-good.json`) storing a **self-contained copy** of the applied profile + source name + applied-at. `save_last_known_good` / `load_last_known_good`; loading with no record → `Error::NoLastKnownGood`.
- **`src/cmd/verify.rs` (new, read-only)** — `verify <profile>`: load profile → live topology (active paths) → `verify_profile` → print status/findings. Never calls SetDisplayConfig.
- **`src/cmd/recover.rs` (new, gated)** — `recover --i-understand-this-mututes-display-config`: load last-known-good → re-apply → post-recovery verification → refresh last-known-good. Gated like apply (D-002).
- **`src/cmd/apply.rs`** — after a successful apply, re-query and run `verify_profile`; print the honest report + a recovery pointer on mismatch (T4.3). last-known-good is recorded **only when rc==0 AND verification == OK**; a failed apply (rc != 0) now returns `Error::ApplyFailed(rc)` → nonzero exit (a failed apply must not silently exit 0).
- **`src/windows/display_config.rs`** —
  - `query_all_paths_and_modes()` + `enumerate_targets_all()` using **QDC_ALL_PATHS | QDC_VIRTUAL_MODE_AWARE** for the apply/recover path. **Key finding:** QDC_ALL_PATHS returns the full source×target cross-product (OBSERVED: 140 paths / 420 modes for 3 displays — every target on every source), so `candidates_from_paths` now **dedupes by target id** (one candidate per display; `connected` = any path for the target has `PATH_ACTIVE`). Without dedup the resolver saw ~14 duplicate targets per display → false AMBIGUITY → `NoTargets` (this was the first failed re-attach attempt).
  - `pick_path` in `build_apply_arrays`: for each planned target, prefer the ACTIVE path (keep its current source); a DETACHED target gets the first source not already claimed by another planned target (re-attach). Path flags set with `|= PATH_ACTIVE` (preserves the QDC `PATH_IS_SUPPORTED`-style bit).
- **`src/cmd/enumerate.rs`** — `dump-all` (read-only): raw QDC_ALL_PATHS dump including path flags, so detached targets are observable during recovery work.
- **`src/core/apply.rs` / `src/core/resolver.rs`** — `PlannedTarget` now carries `honored: HonoredBinding` and `SkipReason::Ambiguous(honored)`; apply reports which binding was honored per target. Consumes the previously dead-code `Match.honored` / `Ambiguity.honored` fields (Phase 4 consumer). `HonoredBinding` gets a `Display` impl.
- New error variants: `NoLastKnownGood`, `ApplyFailed(i32)`.
- 12 new unit tests (7 verify + 2 recovery + 2 path-selection + 1 connected/ambiguous adjust). **35/35 tests pass.**

## Actual Results (all on target HW, 2026-09-25)
### T4.1 — Verification (read-only, no mutation)
- **`verify work` → status OK** — live 3-display topology matches the `work` profile intent exactly (3 intended, 3 active, no findings). **OBSERVED.**
- **`verify work-notv` → status PARTIAL** — **real mismatch detected on HW**: `entry[2] \?\DISPLAY#TCL9653#… is ACTIVE but not intended (should be detached)` (TV still active; the profile wants it detached). **This is the gate criterion 1 evidence.** **OBSERVED.**
- **`verify ghost` → status FAILED** — `entry[0] …NOPE000#… expected ACTIVE but not present` + all 3 live displays reported as not intended. **OBSERVED.**
- **Mode-mismatch fixture** (`verify-mode-mismatch`, scratch profile with VIE2701 `desired_mode` edited to 999×999) → status PARTIAL: `entry[0] … mode mismatch: expected 999x999@320.00Hz rot=0, live 2560x1440@320.00Hz rot=0`. **OBSERVED.**

### T4.2/T4.3 — Recovery (gated, user-approved)
- **Forced bad apply #1 (topology mutation):** `apply work-notv` → rc=0, plan = 2 targets (TV skipped as `disabled`), post-apply topology = **2 paths** (`path[0] 768/src0`, `path[1] 776/src1`) — **the TV (780) was really DETACHED from the live topology**. Verification honestly reported OK for work-notv (the live state matched *its* intent). **OBSERVED.**
- **Key discovery:** after the detach, `targets`/`verify work` (active-only enumeration) no longer listed the TV, and `apply work` failed with `NoTargets` — **QDC_ONLY_ACTIVE_PATHS cannot see a detached target**, so recovery of a detached display was impossible until QDC_ALL_PATHS was added (D-116).
- **Recovery by re-apply (topology restored):** after the QDC_ALL_PATHS fix, `apply work` → rc=0, plan = 3 targets, TV **re-attached on source 2** (its original source — first source not claimed by VIE/src0 or SAM/src1), post-apply topology = 3 paths again; `verify work` → **OK**; `targets` lists all 3. **The forced bad apply (work-notv) was reversed by re-applying the known-good profile — gate criterion 2 evidence.** **OBSERVED.**
- **Forced bad apply #2 (SetDisplayConfig failure):** scratch `duplicate-vie` profile (VIE2701 enabled twice) → `validate duplicate-vie` → rc=**87** (ERROR_INVALID_PARAMETER); `apply duplicate-vie` → **`SetDisplayConfig returned 87`**, `last-known-good NOT updated`, exit code 1 (failed apply now signals failure). **OBSERVED.**
- **`recover --i-understand-this-mututes-display-config`** (after the rc=87 failure, last-known-good still = `work`): re-applied `work` → rc=0 → `Post-recovery verification: OK` → `Recovery complete; last-known-good refreshed`. **OBSERVED.**
- **`recover` gating:** `recover` without the confirm flag → `error: apply not confirmed (refusing to mutate live display config)`, exit 1 — no mutation, no lkg read. **OBSERVED.**
- **Failed apply does not clobber known-good:** `apply ghost` (NoTargets guard) and `apply duplicate-vie` (rc=87) both left `last-known-good.json` = `work` (verified: recover restored exactly `work`). **OBSERVED.**

## Gate Verdict
- Criterion 1 — Verification detects a real mismatch on HW: **SATISFIED (OBSERVED)** — `verify work-notv` → PARTIAL with a concrete `UnexpectedTarget` finding while the TV was live; `verify verify-mode-mismatch` → PARTIAL with a concrete `ModeMismatch`; `verify ghost` → FAILED.
- Criterion 2 — Recovery restores intended topology after a forced bad apply: **SATISFIED (OBSERVED)** — `apply work-notv` detached the TV (2 paths); re-applying the known-good `work` re-attached it on source 2 (3 paths, `verify work` → OK); the `recover` command re-applied last-known-good after an rc=87 failure with post-recovery verification OK.

**STATUS: COMPLETE.**

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-113 | Post-apply verification is **profile-intent-driven**: an enabled entry = must be active, a disabled entry = must be detached, `desired_mode` (when present) = the mode the target must run. Verdicts: OK / PARTIAL / FAILED — never a guess. Ambiguous (identical-unit) entries are not verdicts. | **FINAL** (OBSERVED: OK/PARTIAL/FAILED all reproduced on HW) |
| D-114 | Recovery record = **last-known-good profile copy** (`%LOCALAPPDATA%\display-manager\state\last-known-good.json`) — self-contained, survives edits/deletion of the source profile. Updated **only on rc==0 AND verification OK**; a failed or mismatched apply leaves the previous known-good intact and signals failure (nonzero exit). | **FINAL** (OBSERVED: ghost rc-1 and duplicate-vie rc=87 leaves did not clobber lkg; recover restored `work`) |
| D-115 | `recover` is a **gated command** like apply (D-002). "Without user intervention beyond a log line" is Phase 5 tray-app behavior; the CLI requires the explicit confirm flag. | FINAL (scope) |
| D-116 | Apply/recover enumerate via **QDC_ALL_PATHS** (every source×target combo) with **dedup by target id** (one candidate per display; `connected` = any path active) so a DETACHED display can be re-targeted. Read-only commands keep QDC_ONLY_ACTIVE_PATHS. Path selection: active path wins; detached target re-attaches on the first source not claimed by another planned target. | **FINAL** (OBSERVED: TV re-attached on source 2 after work-notv detach; without dedup the resolver false-ambiguities → NoTargets) |

## Open Items / Notes
- **`desired_mode` is verified but still not enforced** (D-112 stands): V1 apply keeps the live current mode; a mode change (e.g. switching VIE2701 to a different resolution) is a future phase. Verification already detects the mismatch honestly.
- `role`/`primary` remain informational (D-107, D-105); verification does not (yet) check primary/path-priority order beyond profile-order = path-priority.
- The iGPU/adapter-2 targets (`id` 256–269) enumerated under QDC_ALL_PATHS are deduped and never match profile evidence — they appear in `dump-all` but are ignored by apply/verify.
- Scratch fixtures kept as experiment records: `verify-mode-mismatch`, `duplicate-vie` (plus the Phase 3 `ghost`, `work-notv`, `before-apply`, `after-apply`).
- Recovery is CLI-explicit (gated). The auto-recover-on-mismatch behavior ("no user intervention beyond a log line") belongs to the Phase 5 tray app.

## Status
**COMPLETE** — both gate criteria satisfied with OBSERVED evidence on target HW. Verification is honest and connected-aware (OK/PARTIAL/FAILED with concrete findings); recovery restores a detached display via QDC_ALL_PATHS + source-aware path selection and re-applies last-known-good after failed applies. Ready for Phase 5 (Tray Application).