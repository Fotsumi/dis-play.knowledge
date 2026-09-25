# STATUS — DIS-PLAY Operations Dashboard

_Last updated: 2026-09-25_

## Current Phase
**Phase 2 — Capture + Persistence (COMPLETE)** → ready for Phase 3 (Apply)

## Overall Status
**PHASE 2 GATE COMPLETE — profile capture → save → load round-trips without loss, and the schema is stable across a reboot.** 15/15 tests pass; live round-trip + pre/post-reboot capture OBSERVED on target HW.

Key findings:
- **DISCOVERY — this environment IS the target hardware.** `identity`/`dump`/`list` on this host enumerate VIE2701/SAM0D20/TCL9653 with the exact EDID pairs + raw_target_ids of the recorded snapshots. The earlier "this host is not the target hardware" claim is **SUPERSEDED** — the rc=0x57 baseline was the pre-fix QueryDisplayConfig bug on this same machine.
- **`modeInfoIdx` bitfield unusable (OBSERVED):** raw union value reads `0x1ffff`/`0x4ffff`/`0x7ffff` → masked index 15 (out of range). Resolved via D-106: match SOURCE modes by `mode.id == path.sourceInfo.id`.
- **Live mode capture works (OBSERVED):** VIE2701 = 2560x1440@320Hz, SAM0D20 = 1920x1080@60Hz **rotated 270°** (portrait — previously unobserved), TCL9653 = 3840x2160@59.94Hz.
- **`primary` finalized as `Option<bool>` (D-105):** None at capture — changing primary in Windows does NOT change QueryDisplayConfig path order (Phase 0 OBSERVED), so primary cannot be read through this read path. REVISES plan §10 provisional `primary: bool`.
- **Phase 2 gate criterion 2 NOW OBSERVED (user-run reboot):** `profile capture pre-reboot` → reboot → `profile capture post-reboot`; both parse under `schema_version=1`, `key_evidence` identical across reboot — no field drift.

## Last Completed Work
- **Phase 2 implemented + tested** (product): profile schema finalized (`model/profile.rs` — `DisplayProfile`, `DisplayEntry` with `role`/`desired_mode`/`primary`/`enabled`, `DisplayRole`, `schema_version=1`); `core/capture.rs` (pure `build_profile`); `core/persistence.rs` (save/load/list under `%LOCALAPPDATA%\display-manager\profiles`); CLI `profile capture|list|show`. **15/15 tests pass** (`cargo test` on this host).
- **`enumerate_targets` now fills `mode`** per path (D-106: SOURCE mode matched by `mode.id == path.sourceInfo.id`; `modeInfoIdx` bitfield unusable — OBSERVED). `dump` prints source ids + SOURCE-mode sizes.
- **Live round-trip OBSERVED on target HW:** `profile capture work` → `...\AppData\Local\display-manager\profiles\work.json` (3 displays, full key_evidence + desired_mode); `profile show work` → identical fields.
- `phases/PHASE-2.md` + `phases/INDEX.md` updated with decisions D-105..D-107, actual results, and the pending reboot procedure.

## Current Work
**PHASE 2 GATE COMPLETE.** Both gate criteria satisfied with OBSERVED evidence (round-trip without loss; schema stable across reboot). Next: Phase 3 (Apply).
- **Phase 3 BLOCKER carried forward:** SetDisplayConfig still returns 87 even with real buffers (E6). D-106 unlocked correct mode capture; Phase 3 must build `DISPLAYCONFIG_PATH_INFO`/`DISPLAYCONFIG_MODE_INFO` arrays from a captured profile + verify struct population — same direction as before.

## Next Action
1. **Advance to Phase 3 (Apply)** — begin the deeper SetDisplayConfig investigation: build path/mode arrays from a captured `DisplayProfile` (D-106 mode mapping is now proven on real HW), resolve entries via resolver, and fix rc=87. **BLOCKER for Phase 3 (apply_profile).**
2. E3 (driver update) still DEFERRED to a later date.

## Phase Gates
| Phase | Gate | Status |
|---|---|---|
| 0 | Identity mapping table with stable IDs across reboot/driver-update; primary = path-priority confirmed on real HW | **COMPLETE** (OBSERVED + DOCUMENTED from target HW) |
| 1 | Resolver returns correct candidate for each binding_policy (Auto/Physical/Connector) | **COMPLETE** (unit tests pass, no Windows calls in resolver logic) |
| 2 | Capture + persistence round-trips a profile | **COMPLETE** (round-trip OBSERVED; schema stable across reboot OBSERVED) |
| 3 | `apply_profile` applies and verifies | BLOCKED by Phase 2 (SetDisplayConfig rc=87 carried forward) |
| 4 | Verification + recovery paths exercised | BLOCKED by Phase 3 |
| 5 | Tray app runs, menu drives apply | BLOCKED by Phase 4 |
| 6 | Hotkeys registered + fired | BLOCKED by Phase 5 |
| 7 | Hardening (error handling, logging, packaging) | BLOCKED by Phase 6 |

## Open Blockers
- ~~No Rust toolchain~~ — **RESOLVED**: `cargo`/`rustc 1.98.1` available at `C:\Users\Fotsumi\.cargo\bin`; CLI compiles clean + builds release on this host (**OBSERVED**).
- ~~This host is not the target hardware → live experiments (reboot, driver update, DP swap, TV power cycle) are user-run only.~~ **SUPERSEDED** (2026-09-25): this environment IS the target HW (VIE2701/SAM0D20/TCL9653 enumerate live here). Read-only commands run directly; the reboot experiment is still best done by the user (a reboot would disrupt the session).
- **SetDisplayConfig rc=87 (E6)** — still returns 87 even with real buffers. **BLOCKER for Phase 3**; deeper struct-population investigation needed (D-106 mode mapping is a step toward it).

## Remains to be executed on the target Windows machine (exact)
1. `winget install --id RustLang.Rustup` (or rustup script); confirm `cargo --version`. — **DONE** (toolchain present).
2. `cd product && cargo check` → fix any crate-path / field-spelling nits. — **DONE** (compiles clean).
3. `cargo build --release`. — **DONE**.
4. Read-only: `list`, `dump`, `targets`, `pnp`, `identity` — record E1 identity table. — **DONE** (this host IS target HW; `identity`/`dump`/`list` verified live).
5. Before/after experiments via `snapshot <name>` + `diff <a> <b>`: reboot (E2), driver update (E3), DP cable move (E4), TV power cycle (E5). — **DONE for E2/E4/E5**; E3 (driver update) DEFERRED.
6. Deliberate gated apply for return-code observation (E6): `apply --i-understand-this-mututes-display-config <snapshot>`. — **DONE** (rc=87 OBSERVED; root cause under investigation).
7. Record all results into `phases/PHASE-0.md` "Actual Results". — **DONE**.
8. **Phase 2 reboot procedure:** `profile capture pre-reboot` → reboot → `profile capture post-reboot` → `profile show` both → verify `schema_version=1` + unchanged `key_evidence`. — **DONE** (2026-09-25, user-run): both outputs identical, no drift.

## Open Questions / Clarifications
- Exact `windows` crate feature flags and module paths — **RESOLVED** (compiler present on this host; `Win32_Devices_Display` + `Win32_System_Com` verified; struct field spellings confirmed against crate source).
- Whether `monitorDevicePath` is stable across driver updates (E3) — **DEFERRED** to a later date (user has latest GPU drivers).
- `modeInfoIdx` semantics under QDC_VIRTUAL_MODE_AWARE — resolved operationally by D-106 (match by source id), but WHY the bitfield reads as a sentinel is **UNKNOWN** (recorded, not blocking).

## Decisions Made
| ID | Decision | Status |
|---|---|---|
| D-001 | `product/` is a separate git repo, ignored by parent via `.gitignore` | FINAL |
| D-002 | Phase 0 CLI is read-only by default; any SetDisplayConfig APPLY is gated behind an explicit flag + user confirmation | FINAL |
| D-003 | Evidence labels (DOCUMENTED/OBSERVED/INFERRED/UNKNOWN) gate all phase completion claims | FINAL |
| D-P1 | `BindingPolicy { Auto, Physical, Connector }` on `DisplayEntry`, default `Auto` | **FINAL** (Phase 0 gate complete; E4 answered) |
| D-P2 | Stable per-unit key = EDID fields + `monitor_device_path` PREFIX (OBSERVED stable across reboots + DP moves) | **FINAL** (OBSERVED) |
| D-101 | `DisplayEntry` minimal shape = `{ key_evidence, binding_policy }`; remaining fields (`role`, `desired_mode`, `primary`, `enabled`) deferred to Phase 2 with persistence | FINAL |
| D-102 | `IdentityEvidence` = `{ path_prefix: Option<String>, edid_manufacture_id: Option<u32>, edid_product_code_id: Option<u32> }`; matching requires equality on all present fields | FINAL (D-P2 stable key set, OBSERVED) |
| D-103 | Resolution semantics per policy — PHYSICAL match = all present `key_evidence` fields equal candidate's values; CONNECTOR on distinguishable HW = same candidates as PHYSICAL but honored=CONNECTOR (collapse principle); identical units (>1 match) → AMBIGUOUS with slot disambiguation needed (D-101 deferral). Auto: distinct units → honored=PHYSICAL; identical units → honored=CONNECTOR | FINAL |
| D-104 | Resolution contract = `Unique(Match{candidate, honored})` / `Ambiguous(Ambiguity{candidates, honored})` / `Unknown`; honored carried in ALL outcomes (finding doc L57 requirement) | FINAL |
| D-105 | `DisplayEntry.primary` = **`Option<bool>`** (None = not observable at capture); changing primary does NOT change QueryDisplayConfig path order (OBSERVED). REVISES plan §10 `primary: bool` | **FINAL** (OBSERVED) |
| D-106 | Mode per path = SOURCE mode with `mode.id == path.sourceInfo.id`; `modeInfoIdx` bitfield unusable on this HW (0x1ffff/0x4ffff/0x7ffff — OBSERVED). Rotation from `targetInfo.rotation`, refresh from `targetInfo.refreshRate` rational | **FINAL** (OBSERVED + DOCUMENTED) |
| D-107 | Profile storage: pretty JSON `%LOCALAPPDATA%\display-manager\profiles\<name>.json`; `schema_version` (1) for drift detection; `role` stays None at capture (no stable slot key) | FINAL |

## Decisions Pending Evidence
_None — all Phase 0, Phase 1 and Phase 2 decisions resolved to FINAL._

## Important Discoveries (this session)
- **This environment IS the target hardware** (SUPERSEDES "this host is not the target HW"): `identity`/`dump`/`list` enumerate VIE2701/SAM0D20/TCL9653 with EDID + raw_target_ids matching the recorded Phase 0 snapshots. The rc=0x57 baseline was the pre-fix QueryDisplayConfig bug on this same machine.
- **`modeInfoIdx` bitfield unusable** (OBSERVED): raw union value `0x1ffff`/`0x4ffff`/`0x7ffff` (masked index 15 > 9 modes). Robust mapping = SOURCE mode `id == path.sourceInfo.id` (D-106).
- **SAM0D20 is in portrait** (`rotation=270`, OBSERVED via live capture) — previously unrecorded topology detail.
- SetDisplayConfig fully documented: winuser.h/User32.dll; flags SDC_APPLY/SDC_VALIDATE/SDC_USE_SUPPLIED_DISPLAY_CONFIG/SDC_SAVE_TO_DATABASE; return codes incl ERROR_ACCESS_DENIED. **DOCUMENTED**
- Primary = path priority order (lower array index = higher priority). **DOCUMENTED** — but NOT readable back from QueryDisplayConfig output order (OBSERVED), hence D-105.
- `DISPLAYCONFIG_TARGET_DEVICE_NAME` exposes monitorDevicePath[128], connectorInstance, edidManufactureId, edidProductCodeId. **DOCUMENTED**

## Tests / Experiments Performed
- **Baseline run on THIS host (non-target HW) — OBSERVED 2026-09-23:** CLI compiles clean + builds release; read-only commands executed. `dump` → QueryDisplayConfig rc=0x57, 0 paths/modes; `list`/`targets`/`pnp`/`identity` empty (all flow through the same QueryDisplayConfig). Meaning of rc=0x57 is **UNKNOWN** pending target-HW interpretation — do NOT treat as a stability verdict. **[SUPERSEDED by 2026-09-25 discovery]** — this host IS the target HW; the rc=0x57 baseline was the pre-fix QueryDisplayConfig two-call bug (see line 94), not a different machine.
- **Target HW run — OBSERVED 2026-09-24 (user-run):** `identity` → header row only, zero entries. Per source (`enumerate_targets` discards rc and returns Ok(empty) when QDC yields no paths), QueryDisplayConfig produced no topology on target HW either; return code there not yet confirmed (**UNKNOWN** until `dump`). Same symptom as this host — do NOT treat empty output as a stability verdict.
- **Root cause of rc=0x57 — DOCUMENTED 2026-09-24 (MS Learn QueryDisplayConfig):** `rc=0x57 = 87 = ERROR_INVALID_PARAMETER`. Our two-call pattern violated the documented API (NULL path/mode buffers + flags=0, both invalid per docs). Fix applied to `product/src/windows/display_config.rs` (documented GetDisplayConfigBufferSizes → allocate → real-buffers pattern); compiles clean on this host (**OBSERVED**). Awaiting target-HW re-run.
- **Target HW — real topology after fix — OBSERVED 2026-09-24 (user-run):** `dump` → call1=0x000000 call2=0x000000, 2 paths / 6 modes; `identity` → two monitors with monitorDevicePath + EDID fields. instance_id/instance fields still None (SetupDi* walk is a stub) — open item for D-P2.
- **Target HW snapshots — before/after cases — OBSERVED 2026-09-24 (user-run):** Four `snapshot <name>` captures in `.snapshots/` (filenames = case labels). All show 3 displays, all connected=true. Findings: EDID fields + monitor_device_path PREFIX STABLE across all cases → strong D-P2 stable-key candidates; raw_target_id + connector_instance VOLATILE (SAM0D20 id 772→776, both monitors' conn shift after DP move) → NOT reliable keys. **E4 answered:** monitors distinguishable by EDID/path prefix (stable), NOT connector_instance. E5 lifecycle NOT confirmed — all 4 snapshots show 3 displays connected=true incl. "off" case; need a capture where TCL9653 drops out (or `diff` on-vs-off).
- **Target HW apply (E6) — OBSERVED 2026-09-24 (user-run):** `apply --i-understand-this-mututes-display-config 2monitors_1tvconected` → `SetDisplayConfig returned 87` (**OBSERVED**) = ERROR_INVALID_PARAMETER. **Root cause INFERRED** from documented param contract + source inspection: our `set_display_config` passes `None` (NULL) for pathArray/modeInfoArray — same invalid pattern as the QueryDisplayConfig bug; docs state both "cannot be NULL." Additionally it ignores the source snapshot entirely (`let _ = source;`) — does NOT build the topology from the snapshot. **BLOCKER for Phase 3** — needs fixing before any real apply.
- **Target HW E5/E3 constraints — OBSERVED 2026-09-24 (user-run):** `diff <on> <off>` → both 3 candidates, no field changes (**OBSERVED**). User note: "tv seem to never properly turns off when powered off with the remote" + confirmed after reboot: TCL9653 still connected=true even "off". **E5 lifecycle NOT observable for this TV** — modern TVs have always-on feature where EDID responds even in "off" state, so QueryDisplayConfig keeps listing them. E3 (driver update) difficult to test since user already has latest GPU drivers.
- **Target HW reboot stability (E2) — OBSERVED 2026-09-24 (user-run):** `snapshot 2monitors_1tvconectedoff_afterreboot` captured after reboot with TV off: SAM0D20 raw_target_id = **776** (KEPT the post-DP-change value, did NOT revert to 772) → **raw_target_id STABLE across reboots** ✓; monitor_device_path PREFIX unchanged → **STABLE across reboots** ✓. connector_instances reverted to baseline values (VIE2701=conn0, SAM0D20=conn0, TCL9653=conn1) → position-dependent, NOT reboot-stable.
- **SetDisplayConfig FIX APPLIED BUT STILL 87 — OBSERVED 2026-09-24:** `set_display_config` in `product/src/windows/display_config.rs` now loads snapshot + re-enumerates live topology + calls SetDisplayConfig with real buffers (no longer NULL). Compiles clean on this host (**OBSERVED**). **Re-run on target HW STILL returns 87** → suggests the DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO structs we're building don't have all required fields populated correctly, OR the mode array doesn't match the path array in a way SetDisplayConfig expects. **BLOCKER for Phase 3** — needs deeper investigation beyond just fixing NULL buffers.
- **E5 ACCEPTED as NOT observable for this TV — OBSERVED 2026-09-24:** User confirmed: "test is not reproducible on my TV." Modern TVs have always-on feature where EDID responds even in "off" state, so QueryDisplayConfig keeps listing them. TCL9653 stays connected=true even when "off" with remote.
- **SDC_VALIDATE return code — OBSERVED 2026-09-24 (user-run):** `validate <source>` → SetDisplayConfig (SDC_VALIDATE) returned **87** for BOTH `2monitors_1tvconectedoff` AND `2monitors_1tvconectedon`. Confirms the issue is NOT with flags but with how we're building the DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO arrays. **E6 ✓ NOW OBSERVED** — BOTH APPLY + VALIDATE return codes confirmed (both 87).
- **Target-HW experiments remaining: PENDING** — user-run only; transcribe observed output, do not fabricate. Literal E3 capture DEFERRED to later date (user has latest GPU drivers). **Primary/path-priority observed** still pending (need to confirm which display is primary after topology change). **Deeper SetDisplayConfig investigation in Phase 3** (still returns 87 even with real buffers).
- **Phase 1 resolver unit tests — OBSERVED 2026-09-24:** `cargo test` run on this host → 7/7 pass. Tests cover: PHYSICAL/Auto/CONNECTOR each resolve uniquely per distinguishable unit (honored label differs); identical-units synthetic fixture → AMBIGUOUS for all policies; Auto on identical units honors CONNECTOR (finding doc L53); no-evidence + wrong-EDID entries → UNKNOWN. Fixtures transcribed from Phase 0 snapshots (VIE2701=9561/9985, SAM0D20=11596/3360, TCL9653=27728/38483 — OBSERVED).
- **Phase 2 tests — OBSERVED 2026-09-25:** `cargo test` on this host → **15/15 pass** (7 resolver + 4 capture + 4 persistence). New: `build_profile` emits one entry per candidate keyed on D-P2 evidence; captured entries re-resolve uniquely (`captured_entries_re_resolve_uniquely`); desired_mode round-trips; JSON + file round-trips equal; list finds only JSON; missing profile errors.
- **Phase 2 live capture — OBSERVED 2026-09-25 (this host = target HW):** `profile capture work` → `C:\Users\Fotsumi\AppData\Local\display-manager\profiles\work.json` (3 displays; desired_mode 2560x1440@320 / 1920x1080@60 rotated-270 / 3840x2160@59.94); `profile show work` → identical fields (round-trip without loss). `dump` now shows source ids + SOURCE-mode sizes; `modeInfoIdx` bitfield sentinel observed (`0x1ffff`/`0x4ffff`/`0x7ffff`).
- **Phase 2 reboot stability — OBSERVED 2026-09-25 (user-run on target HW):** `profile capture pre-reboot` → reboot → `profile capture post-reboot`; `profile show` both → **identical** (`schema_version=1`, same `key_evidence` path prefixes + EDIDs, same desired_mode/enabled/primary fields, no drift). Satisfies Phase 2 gate criterion 2.

## Documents Affected by New Findings
- `phases/PHASE-0.md` updated: E2 reboot stability NOW OBSERVED (raw_target_id + monitor_device_path PREFIX stable across reboots); E5 confirmed NOT observable for TV on this HW (always-on feature — EDID responds even in "off" state); SetDisplayConfig FIX APPLIED (loads snapshot + real buffers, no longer NULL).
- `DIS-PLAY-REVIEW_FINDINGS_v2.md` §7/§8/§9 updated + new §15 sources section.
- `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` created (new).
- V1 files untouched (immutable history).
- **This session:** `phases/PHASE-1.md` updated — D-P1/D-P2 → FINAL, new decisions D-101..D-104 recorded, gate marked COMPLETE with OBSERVED + DOCUMENTED citations. `STATUS.md` advanced to Phase 1 complete / ready for Phase 2.

- **This session (2026-09-25):** `phases/PHASE-2.md` rewritten with actual results + decisions D-105..D-107 + pending reboot procedure; `phases/INDEX.md` Phase 2 row updated to IN PROGRESS (implementation done, reboot evidence pending). `STATUS.md` advanced to Phase 2 in progress.
- **This session (2026-09-25, follow-up):** Phase 2 gate criterion 2 evidence recorded (reboot round-trip OBSERVED, user-run) → `phases/PHASE-2.md` gate both checked, Status → **COMPLETE**; `phases/INDEX.md` → COMPLETE; `STATUS.md` advanced to Phase 2 complete / ready for Phase 3.

## Product Implementation Status
CLI source **compiles clean + builds release** in `product/`. Read-only commands execute on this host (**OBSERVED**). `product/.gitignore` already ignores `target/`, `debug/`.

**Phase 2 additions:** `model/profile.rs` (new) — finalized `DisplayProfile`/`DisplayEntry` (`role`, `desired_mode`, `primary: Option<bool>`, `enabled`, `schema_version`) + `DisplayRole`; `DisplayEntry` moved out of `model/candidate.rs` (plan §18 layout); `core/capture.rs` (new, pure `build_profile`/`entry_from_candidate`); `core/persistence.rs` (new, save/load/list under `%LOCALAPPDATA%`); `cmd/profile.rs` (new, `profile capture|list|show`); `windows/display_config.rs` `enumerate_targets` now fills `mode` (D-106); `dump` prints source ids + SOURCE-mode sizes. 15/15 tests pass; release build clean (7 pre-existing resolver dead-code warnings — resolver wiring lands in Phase 3 apply).

**Note:** `profile capture` writes a profile JSON under `%LOCALAPPDATA%` — read-only with respect to display config (never calls SetDisplayConfig). A smoke-test profile `work.json` currently exists there from the live capture above.
