# Phase 8 — Mode & Position Preservation (disabled-monitor config restore)

## Objective
Make a disabled→re-enabled monitor come back with its **captured** configuration — resolution, refresh rate, orientation, and desktop position — instead of whatever live/best-mode Windows happens to apply. Also make applies **persist** to the Windows display database so the config survives across sessions/reboots.

## Origin (why this phase exists)
All Phases 0–7 are complete and the product works (apply/verify/recover/hotkey/tray all OBSERVED on HW). Post-release review identified one real gap:

> "All functionalities work, but disabled monitor configurations are not preserved like selected resolution, refresh settings, display orientation, display positions."

**OBSERVED** (user report, 2026-09-26). The disable step is correct (Phase 4 OBSERVED a real detach); the **re-enable** step restores topology but not the disabled monitor's settings.

## Root-Cause Analysis

Three independent code-level causes, all **DOCUMENTED** by source inspection; the mechanisms are **INFERRED** (deduced from the documented CCD contract) and must be validated on HW.

### R1 — `desired_mode` is captured but never applied (D-112 scope)
- `core/capture.rs:38` records `desired_mode` (width/height/refresh/rotation) at capture.
- `core/apply.rs:18,64` carries it on `PlannedTarget` with `#[allow(dead_code)]` — never consumed.
- `windows/display_config.rs:268-307` (`build_apply_arrays`) builds the mode array **purely from live QDC modes** (`modes[s].clone()` / `modes[t].clone()`); a missing mode → `PATH_MODE_IDX_INVALID` = Windows **best-mode** logic (native res, preferred refresh, identity rotation).

For an actively-running monitor, live mode == captured mode, so topology-only applies look correct. Once a monitor is **disabled**, its source/target modes are no longer the live active ones; on re-enable the code either clones a stale/absent live mode or falls back to best-mode — hence lost resolution / refresh / orientation.

### R2 — Desktop position is neither captured nor applied
- `model/candidate.rs:32-39` `ModeInfo` has `width/height/refresh_rate_hz/rotation` — **no position field**. The V2 plan explicitly listed `desired_mode: … position/offset` (`DIS-PLAY-REVIEW_FINDINGS_v2.md:93`), but the implemented model dropped it.
- The desktop offset lives in `DISPLAYCONFIG_SOURCE_MODE.position` (POINTL). The applied source mode is a live clone (`display_config.rs:281`), so the re-enabled monitor gets whatever position its source reports at apply time.
- `model/profile.rs:45` `DisplayRole.position` is only a path-priority *index* (informational), and `role` is always captured `None` (`capture.rs:37`).
- Secondary contributor: `pick_path` (`display_config.rs:217-238`) re-attaches a detached target on "the first source not already claimed", not necessarily its original source.

### R3 — `SDC_SAVE_TO_DATABASE` is never passed
- Constant defined (`display_config.rs:40`) with `#[allow(dead_code)]`; apply flags are only `SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG` (`display_config.rs:350-354`).
- Without `SDC_SAVE_TO_DATABASE` (DOCUMENTED: "save the specified topology to the display database"), applies are **session-only**; the Windows display database — the mechanism that makes Windows remember a disconnected monitor's settings and restore them on re-attach/reboot — is never updated. Even the OS-native restore path is bypassed because dis-play supplies explicit (live/best) modes.

### Corroborating evidence
The Phase 6 hotkey wedge was the same gap from the other direction: SAM0D20 live `rot=0` vs captured `rot=270` made verification PARTIAL and lkg never advanced. `verify` already detects `ModeMismatch` (`core/verify.rs:119`), so "enforce mode" has a ready-made check.

## Scope
- **In:** mode enforcement on apply; position capture + apply; `SDC_SAVE_TO_DATABASE`; the supporting data-model change; HW probes to answer the UNKNOWNs.
- **Out:** window-position management (explicitly out per `DIS-PLAY-REVIEW_MASTER_PLAN.md:199` — "identify whether window-position management belongs in V1; do not add it without strong justification"); E3 driver-update test (still deferred).

## Tasks
| # | Task | Output | Status |
|---|---|---|---|---|
| T8.1 | Extend `ModeInfo` with `position: Option<(i32,i32)>` (`#[serde(default)]`, backward-compatible with schema v1) | `model/candidate.rs` | **COMPLETE** (backward-compat OBSERVED) |
| T8.2 | Capture position in `mode_for_path` (read `DISPLAYCONFIG_SOURCE_MODE.position`) | `windows/display_config.rs` | **COMPLETE** (live capture OBSERVED) |
| T8.3 | Capture the full `DISPLAYCONFIG_TARGET_MODE` timing (pixelRate, active/total pixels+lines, sync, scaling, scanLineOrdering) into the profile at capture time — the ONLY reliable source of the last-used mode for a detached target (T8.6 finding) | `model/profile.rs`, `windows/display_config.rs` | **COMPLETE** (live capture OBSERVED) |
| T8.4 | Enforce `desired_mode` in `build_apply_arrays`: build SOURCE mode from `desired_mode` (width/height/position), set `path.targetInfo.rotation`, reconstruct TARGET mode from the captured timing (T8.3); missing timing → `PATH_MODE_IDX_INVALID` best-mode + `ModeUnavailable`, never guess | `windows/display_config.rs` | **COMPLETE** (unit-tested) |
| T8.5 | Apply position in the built source mode | `windows/display_config.rs` | **COMPLETE** (unit-tested) |
| T8.6 | HW probe: `dump-all` before/after a disable — what the QDC ALL_PATHS mode array holds for a detached target (answers the UNKNOWN) | evidence | **COMPLETE** (see Actual Results) |
| T8.7 | Add `SDC_SAVE_TO_DATABASE` to apply flags (validate unchanged) | `windows/display_config.rs` | **COMPLETE** (validate rc=0 OBSERVED; apply+save combo needs HW) |
| T8.8 | Tests (unit + regression 54/54) + release build + HW validation of the gate | `product/` | **COMPLETE** (56/56 tests + clean release OBSERVED; gate HW validation OBSERVED user-run 2026-09-26) |

## Fix Sketch

### T8.1/T8.2 — position data model + capture
`ModeInfo` gains one field (additive, `#[serde(default)]` so existing `schema_version=1` files parse unchanged):

```rust
pub struct ModeInfo {
    pub width: u32,
    pub height: u32,
    pub refresh_rate_hz: f64,
    pub rotation: u32,
    #[serde(default)]
    pub position: Option<(i32, i32)>, // DISPLAYCONFIG_SOURCE_MODE.position
}
```

In `mode_for_path`, populate `position` from the SOURCE mode's `position` (`source.position` → `(x, y)`). No schema-version bump needed for an additive optional field; note it in the doc comment. **INFERRED** backward-compatible; confirm by loading an existing profile JSON after the change.

### T8.3 — capture the TARGET mode timing in the profile (REVISED after T8.6)
T8.6 proved the QDC ALL_PATHS mode array contains **no mode data for a detached target** (see Actual Results). Therefore the last-used target timing cannot be recovered from the live enumeration after a disable — it must be **captured into the profile while the display is active** and reconstructed on re-enable.

Add a serialized capture of `DISPLAYCONFIG_TARGET_MODE.targetVideoSignalInfo` (the documented timing fields: `pixelRate`, `hSyncFreq`, `hSyncPolarity`, `hSyncActivePixels`, `hSyncTotalPixels`, `vSyncFreq`, `vSyncPolarity`, `vSyncActiveLines`, `vSyncTotalLines`, `vSyncRefreshDivider`, `scanLineOrdering`, `scaling`) as an optional field on `DisplayEntry` (`#[serde(default)]` — schema v1 files stay readable). Filled at capture time from the live QDC TARGET mode (`infoType == TARGET && id == target`). `None` when unobservable (→ apply falls back to best-mode + `ModeUnavailable`).

### T8.4 — enforce `desired_mode` in `build_apply_arrays` (REVISED after T8.6)
`build_apply_arrays` already receives `&[PlannedTarget]`, which carries `desired_mode`. Per target with `Some(m)`:

1. **Rotation:** set `p.targetInfo.rotation = DISPLAYCONFIG_ROTATION(rot_const(m.rotation))` with the inverse of the read-side mapping in `mode_for_path` (90→`ROTATE90`(2), 180→`ROTATE180`(3), 270→`ROTATE270`(4); 0→IDENTITY(1)). **DOCUMENTED** constants.
2. **Source mode:** build/replace the SOURCE `DISPLAYCONFIG_MODE_INFO` with `sourceMode.width = m.width`, `sourceMode.height = m.height`, `sourceMode.position = m.position` (T8.5) or live, `sourceMode.pixelFormat` kept from live.
3. **Target mode:** reconstruct the `DISPLAYCONFIG_TARGET_MODE` from the profile-captured timing (T8.3). If present → reference it; if absent/invalid → `PATH_MODE_IDX_INVALID` (best-mode) **and surface `ModeUnavailable`** on the target (never guess silently).
4. `desired_mode == None` → keep today's live-clone/best-mode behavior.

**SUPERSEDED mechanism:** the earlier sketch proposed *matching* `desired_mode` against live QDC ALL_PATHS target modes. T8.6 **OBSERVED** this is infeasible — a detached target has no mode entries in the live array, so there is nothing to match.

### T8.7 — `SDC_SAVE_TO_DATABASE`
```rust
let flags: u32 = if apply {
    SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_SAVE_TO_DATABASE
} else {
    SDC_VALIDATE | SDC_USE_SUPPLIED_DISPLAY_CONFIG
};
```
Remove the `#[allow(dead_code)]` on `SDC_SAVE_TO_DATABASE`. Validate keeps no-save semantics. **INFERRED** valid combination; the DOCUMENTED flag contract allows OR-ing, but confirm on HW that apply+save returns 0 on the target machine.

## Gate
- [x] Re-enabling a previously-disabled monitor returns it to its **captured** `desired_mode` (resolution, refresh, orientation) — confirmed on HW. **OBSERVED** (user-run 2026-09-26, via `dis-play tray` + visual settings check; a raw command-line `verify <profile>` verdict was not separately run and remains an optional final confirmation).
- [x] Re-enabling a previously-disabled monitor returns to its **captured desktop position**. **OBSERVED** (user-run 2026-09-26).
- [x] After `apply` with `SDC_SAVE_TO_DATABASE`, the topology persists across a reboot (session-only applies do not). **OBSERVED** (user-run 2026-09-26).
- [x] No regressions: `validate` rc=0, detach semantics intact (Phase 4 scenario), recovery + hotkey toggle still OK. **OBSERVED** (user-run 2026-09-26).
- [x] All prior tests still pass (56/56); release build clean (zero warnings). **OBSERVED** (already recorded in T8.1–T8.5).

## Potential Blockers / Open Questions
- **RESOLVED by T8.6 (OBSERVED):** does the QDC ALL_PATHS mode array retain a detached target's last-used mode? **No.** Modes exist only for ACTIVE paths; a detached target's entries are zero-filled. This forced the fix to capture TARGET timing in the profile (T8.3) instead of matching live modes.
- **RESOLVED by T8.8 (OBSERVED 2026-09-26):** the `SDC_APPLY | SDC_SAVE_TO_DATABASE` combination is valid — apply+save returned rc=0 and the topology persisted across a reboot (user-run).
- **RESOLVED by T8.8 (OBSERVED 2026-09-26):** a profile-captured `DISPLAYCONFIG_TARGET_MODE` is valid for SetDisplayConfig after a disable — the re-enabled monitor returned to its captured timing. The best-mode + `ModeUnavailable` fallback remains for profiles lacking captured timing (old `work`-era profiles, until re-captured with the new binary).
- Note: profiles `all`/`play`/`tv`/`work` currently exist (no `samtv` pair); live topology OBSERVED has drifted from captures (VIE 2560x1440@60 vs captured @320; TV native 3840x2160@60 vs captured 2560x1440@144) — the exact Phase 8 symptom, reproducible on demand.

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-128 | Apply MUST enforce each entry's `desired_mode` (resolution, refresh, rotation) instead of cloning live/best-mode modes — supersedes D-112's "keep live mode". Source mode built from `desired_mode` (width/height/position); rotation written to `path.targetInfo.rotation`; **TARGET mode reconstructed from the timing captured in the profile at capture time (T8.3)**. [SUPERSEDED mechanism: matching `desired_mode` against live QDC ALL_PATHS target modes — OBSERVED infeasible, a detached target has no live mode entries]. No captured timing → `PATH_MODE_IDX_INVALID` best-mode + `ModeUnavailable` surface, never guess. | **FINAL** (HW validated 2026-09-26, T8.8 OBSERVED — disable→re-enable restored captured mode) |
| D-129 | `ModeInfo` gains `position: Option<(i32,i32)>` (`#[serde(default)]`, schema v1 stays readable); capture records `DISPLAYCONFIG_SOURCE_MODE.position`; apply writes it back so a re-enabled monitor returns to its captured desktop offset. | **FINAL** (HW validated 2026-09-26, T8.8 OBSERVED — position restored) |
| D-130 | Apply flags = `SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_SAVE_TO_DATABASE` so topology + modes persist into the Windows display database; `validate` keeps `SDC_VALIDATE` without save. | **FINAL** (HW validated 2026-09-26, T8.8 OBSERVED — reboot persistence confirmed) |

## Actual Results
### T8.6 — QDC ALL_PATHS mode array vs a detached target (OBSERVED 2026-09-26, target HW)
Procedure: current state = `work` (VIE2701+SAM0D20 active, TCL9653 detached). Toggled with the gated applies, capturing `dump-all` (read-only) at each step. All applies rc=0.

| State | Active paths | Populated mode entries (of 420) | Notes |
|---|---|---|---|
| Baseline (`work`, TV detached) | 2 (768/src0, 776/src1) | **6** — modes 0–5 | TARGET+SOURCE+DESKTOP_IMAGE per active path; the other 414 entries zeroed (`infoType=0 id=0`) |
| After `apply all` (TV attached) | 3 (768/src0, 776/src1, 780/src2) | **9** — modes 0–8 | TV target 780 has TARGET+SOURCE+DESKTOP_IMAGE; TV source mode = **3840x2160** (best-mode, NOT captured 2560x1440@144) |
| After `apply work` (TV detached) | 2 (768/src0, 776/src1) | **6** — modes 0–5 | target 780 modes **gone** — zero-filled |

**Answer to the UNKNOWN:** the QDC ALL_PATHS mode array does **NOT** retain a detached target's last-used (or any) mode. It contains one TARGET + SOURCE + DESKTOP_IMAGE group **per active path only**, at the *currently active* timing; every other entry is zero-filled. → The "match `desired_mode` against live target modes" approach cannot work for a detached target; the timing must be captured in the profile (T8.3).

**Incidental confirmation of the Phase 8 root cause (OBSERVED):** `apply all` re-attached the TV (rc=0) but verification was **PARTIAL** with mode mismatches — the exact reported symptom:
- `entry[0] VIE2701 mode mismatch: expected 2560x1440@320.00Hz rot=0, live 2560x1440@60.00Hz rot=0`
- `entry[2] TCL9653 mode mismatch: expected 2560x1440@144.00Hz rot=0, live 3840x2160@60.00Hz rot=0`

Re-enable engaged best-mode logic and returned the TV at its **native 3840x2160@60** instead of the captured 2560x1440@144; VIE's refresh dropped 320→60. This is the user-reported "disabled monitor configurations are not preserved" reproduced on HW.

**Cleanup/state:** final state = `work` (VIE+SAM active, TV detached) — identical to the session-start topology. No profile/lkg changes (verification PARTIAL → lkg NOT updated, per D-114).

### T8.1–T8.5, T8.7 — implementation (OBSERVED 2026-09-26, this host = target HW)
Implemented in `product/` exactly per the fix sketch (D-128..D-130):

- **T8.1** `ModeInfo.position: Option<(i32,i32)>` (`#[serde(default)]`) — `model/candidate.rs`.
- **T8.2** `mode_for_path` fills `position` from `DISPLAYCONFIG_SOURCE_MODE.position` (`windows/display_config.rs`).
- **T8.3** new serialized `TargetTiming` (pixel_rate, h/v_sync_freq rationals, active/total size, raw signal-info bitfield, scan_line_ordering) captured by new `target_timing_for_path` from the live TARGET mode (`infoType == TARGET && id == target`); carried on `DisplayCandidate` → `DisplayEntry` (`#[serde(default)]`). The `windows` crate exposes `DISPLAYCONFIG_VIDEO_SIGNAL_INFO.Anonymous` only as a raw `_bitfield` u32 (it collapses the documented hSyncPolarity/vSyncPolarity/vSyncRefreshDivider/hSyncActivePixels/hSyncTotalPixels/vSyncActiveLines/vSyncTotalLines/scaling bitfield) — stored losslessly, written back verbatim.
- **T8.4** `build_apply_arrays` per target with `Some(desired_mode)`: rotation → `path.targetInfo.rotation` (`rot_const`: 90→2, 180→3, 270→4, else 1 — DOCUMENTED constants), SOURCE mode built from width/height/position (pixelFormat kept from live), TARGET mode reconstructed from `target_timing`; missing timing → `PATH_MODE_IDX_INVALID` + index surfaced in a new `ApplyOutcome.mode_unavailable` list (reported by `apply` as a WARNING, D-128 "never guess silently"). `desired_mode == None` keeps the old live-clone/best-mode behavior.
- **T8.5** position applied via the built SOURCE mode (falls back to live position when the profile lacks it).
- **T8.7** apply flags = `SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG | SDC_SAVE_TO_DATABASE` (`#[allow(dead_code)]` removed); validate keeps `SDC_VALIDATE | SDC_USE_SUPPLIED_DISPLAY_CONFIG` (no save).

**Verification on this host (= target HW):**
- **Backward compat OBSERVED:** the existing `schema_version=1` `work` profile loads after the change — `profile show work` renders `position: null` + `target_timing: null` (serde fills the new optional fields). No schema bump needed.
- **Live capture OBSERVED:** `profile capture` of the current 2-display topology fills both new fields with real values — VIE2701 `position:[0,0]`, SAM0D20 (portrait) `position:[-1080,0]`; `target_timing` carries `pixelRate` (VIE 241500000 ≈ 2720×1481×60, SAM 148500000 = 2200×1125×60 exactly), active/total sizes, `signal_info_flags` (255 / 25), `scan_line_ordering=1` (progressive). Refresh implied by pixelRate/totalSize matches the live 60Hz.
- **Regression OBSERVED:** `validate work` → `SetDisplayConfig (SDC_VALIDATE) returned 0` (validate keeps no-save semantics, rc=0 intact).
- **Tests OBSERVED:** `cargo test` → **56/56 pass** (54 prior + 2 new T8.4/T8.5: `desired_mode_builds_source_and_reconstructs_target`, `desired_mode_without_timing_surfaces_mode_unavailable`). `cargo build --release` → clean (zero warnings).
- Scratch profile `t8-scratch` used for the capture probe was deleted; the saved profile set (`all`/`play`/`tv`/`work`) is untouched.

**HW-validated (T8.8, 2026-09-26, user-run, OBSERVED):** the full gate is met — disable→re-enable returns to captured res/refresh/orientation/position; apply persists across a reboot via `SDC_SAVE_TO_DATABASE`; detach/recovery/hotkey regressions OK (see T8.8 subsection below). Old profiles (no `target_timing`) still exercise the ModeUnavailable fallback until re-captured with the new binary.

### T8.8 — Gate validation on HW (OBSERVED 2026-09-26, user-run, target HW)
User ran the full Phase 8 gate on the target machine:
- **Disable → re-enable round-trip (via `dis-play tray`):** the re-enabled monitor came back at its **captured** resolution, refresh rate, orientation, **and desktop position** — confirmed by the user's visual check of the restored display plus a settings check using the tray executable (the tray re-verifies the applied profile on every apply).
- **Reboot persistence:** confirmed — the applied topology (with `SDC_SAVE_TO_DATABASE`) survived a reboot.
- **Regressions:** `validate` rc=0, Phase 4 detach semantics, recovery, and the hotkey toggle all still OK.
- **Final criterion:** 56/56 tests pass + release build clean (zero warnings) (already OBSERVED).

*Method note:* the gate's "verify reports OK" was satisfied by the tray executable's own post-apply verification + the user's visual confirmation of the restored settings; a raw `verify <profile>` command-line verdict was not separately run and is available as an optional final confirmation.

## Status
**COMPLETE (2026-09-26)** — root cause recorded and **live-reproduced** (T8.6, OBSERVED); fix sketch revised (TARGET timing must be captured in the profile — live-mode matching rejected); **T8.1–T8.5, T8.7 implemented** (OBSERVED: 56/56 tests, clean release, live capture fills position+timing, old profiles load, `validate work` rc=0); **T8.8 gate validated on target HW** (user-run, OBSERVED — see Actual Results below). All five gate criteria met with at least one OBSERVED item each; D-128/D-129/D-130 promoted to FINAL. Phase 8 is done — next is **final verification + release preparation**.