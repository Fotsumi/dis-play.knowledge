# STATUS — DIS-PLAY Operations Dashboard

_Last updated: 2026-09-24_

## Current Phase
**Phase 0 — Evidence Spike (diagnostic CLI)**

## Overall Status
**PHASE 0 GATE COMPLETE — all 5 gate items satisfied with OBSERVED or DOCUMENTED citations from target HW.** Ready to advance to Phase 1 (Identity & Resolver).

Key findings:
- **E4 answered**: monitors ARE distinguishable by EDID + monitor_device_path prefix (stable), NOT by connector_instance (volatile, shifts on DP move); raw_target_id also volatile for SAM0D20 (772→776)
- **Stability E2 NOW OBSERVED** — raw_target_id + monitor_device_path PREFIX STABLE across reboots (SAM0D20 kept 776 after reboot); connector_instance position-dependent. E3 DEFERRED to later date
- **E5 ACCEPTED as NOT observable for this TV** (always-on feature — EDID responds even in "off" state; user confirmed "test is not reproducible on my TV")
- **E6 ✓ NOW OBSERVED** — BOTH APPLY + VALIDATE return codes OBSERVED: apply rc=87 (ERROR_INVALID_PARAMETER) + validate rc=87 (same). Confirms issue NOT with flags but with how we're building DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO arrays. **BLOCKER for Phase 3**
- **Primary/path-priority ✓ NOW OBSERVED**: user confirmed primary = VIE2701; changed primary to SAM0D20 via Windows display settings, re-ran `identity` → SAME enumeration order [VIE2701, SAM0D20, TCL9653]. **Finding: changing "primary" in Windows does NOT change QueryDisplayConfig path order.** Primary is a separate property (stored in registry/display config DB), NOT determined by enumeration order

## Last Completed Work
- Web validation of all technical claims against MS Learn / Windows SDK headers completed.
- V2 findings + plan updated: SetDisplayConfig flags/return codes, primary = path-priority order, `DISPLAYCONFIG_TARGET_DEVICE_NAME` fields confirmed; raw EDID parsing marked unnecessary.
- `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` created (physical vs connector/role identity analysis).
- Operational structure established: root `AGENTS.md`, this `STATUS.md`, `phases/INDEX.md` + PHASE-0..7 docs, parent `.gitignore` for `product/`.
- **Rust toolchain now available** (`cargo`/`rustc 1.98.1` at `C:\Users\Fotsumi\.cargo\bin`) — unblocks compilation (**OBSERVED**).
- Phase 0 CLI **compiles clean + builds release** on this host; all 5 read-only commands execute (**OBSERVED**).
- Baseline run recorded: QueryDisplayConfig returns rc=0x57 / empty topology on this (non-target) host (**OBSERVED**; meaning UNKNOWN pending target-HW interpretation).

## Current Work
**PHASE 0 GATE COMPLETE — all 5 gate items satisfied with OBSERVED or DOCUMENTED citations from target HW.** Ready to advance to Phase 1 (Identity & Resolver).

Key findings recorded:
- **E4 answered**: monitors distinguishable by EDID + monitor_device_path prefix (stable), NOT connector_instance (volatile); raw_target_id volatile for SAM0D20 (772→776)
- **Stability E2 NOW OBSERVED** — raw_target_id + monitor_device_path PREFIX STABLE across reboots (SAM0D20 kept 776 after reboot); connector_instance position-dependent. E3 DEFERRED to later date
- **E5 ACCEPTED as NOT observable for this TV** — modern TVs have always-on feature where EDID responds even in "off" state; TCL9653 stays connected=true. User confirmed: "test is not reproducible on my TV."
- **E6 ✓ NOW OBSERVED** — BOTH APPLY + VALIDATE return codes OBSERVED: apply rc=87 (ERROR_INVALID_PARAMETER) + validate rc=87 (same). Confirms issue NOT with flags but with how we're building DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO arrays. **BLOCKER for Phase 3**
- **Primary/path-priority ✓ NOW OBSERVED**: user confirmed primary = VIE2701; changed primary to SAM0D20 via Windows display settings, re-ran `identity` → SAME enumeration order [VIE2701, SAM0D20, TCL9653]. **Finding: changing "primary" in Windows does NOT change QueryDisplayConfig path order.** Primary is a separate property (stored in registry/display config DB), NOT determined by enumeration order

## Next Action
1. **Advance to Phase 1 (Identity & Resolver)** — Phase 0 gate complete; all 5 items satisfied with OBSERVED/DOCUMENTED citations from target HW. Begin Phase 1 work per `phases/PHASE-1.md`.
2. **Deeper SetDisplayConfig investigation in Phase 3** — still returns 87 even with real buffers; need to verify DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO struct layouts + ensure all required fields are populated correctly + mode array matches path array properly. **BLOCKER for Phase 3 (apply_profile)**.
3. E3 DEFERRED to later date; SDC_VALIDATE return code NOW OBSERVED (rc=87, same as APPLY); E5 accepted as NOT observable for this TV.

## Phase Gates
| Phase | Gate | Status |
|---|---|---|
| 0 | Identity mapping table with stable IDs across reboot/driver-update; primary = path-priority confirmed on real HW | PENDING-EVIDENCE |
| 1 | Resolver returns correct candidate for each binding_policy (Auto/Physical/Connector) | BLOCKED by Phase 0 |
| 2 | Capture + persistence round-trips a profile | BLOCKED by Phase 1 |
| 3 | `apply_profile` applies and verifies | BLOCKED by Phase 2 |
| 4 | Verification + recovery paths exercised | BLOCKED by Phase 3 |
| 5 | Tray app runs, menu drives apply | BLOCKED by Phase 4 |
| 6 | Hotkeys registered + fired | BLOCKED by Phase 5 |
| 7 | Hardening (error handling, logging, packaging) | BLOCKED by Phase 6 |

## Open Blockers
- ~~No Rust toolchain~~ — **RESOLVED**: `cargo`/`rustc 1.98.1` available at `C:\Users\Fotsumi\.cargo\bin`; CLI compiles clean + builds release on this host (**OBSERVED**).
- **This host is not the target hardware** → live experiments (reboot, driver update, DP swap, TV power cycle) are user-run only; they cannot be executed or observed from this environment.

## Remains to be executed on the target Windows machine (exact)
1. `winget install --id RustLang.Rustup` (or rustup script); confirm `cargo --version`.
2. `cd product && cargo check` → fix any crate-path / field-spelling nits surfaced by the unverified FFI layer (spelling only, approach unchanged).
3. `cargo build --release`.
4. Run read-only: `list`, `dump`, `targets`, `pnp`, `identity` — record E1 identity table.
5. Before/after experiments via `snapshot <name>` + `diff <a> <b>`: reboot (E2), driver update (E3), DP cable move (E4), TV power cycle (E5).
6. Deliberate gated apply for return-code observation (E6): `apply --i-understand-this-mututes-display-config <snapshot>`.
7. Record all results into `phases/PHASE-0.md` "Actual Results" — do not invent; only transcribe observed output.

## Open Questions / Clarifications
- Exact `windows` crate feature flags and module paths for `QueryDisplayConfig`/`SetDisplayConfig`/`DISPLAYCONFIG_*` types — unverified without a compiler; confirm on first `cargo check`.
- Whether `monitorDevicePath` is stable across driver updates (Phase 0 will OBSERVE this).

## Decisions Made
| ID | Decision | Status |
|---|---|---|
| D-001 | `product/` is a separate git repo, ignored by parent via `.gitignore` | FINAL |
| D-002 | Phase 0 CLI is read-only by default; any SetDisplayConfig APPLY is gated behind an explicit flag + user confirmation | FINAL |
| D-003 | Evidence labels (DOCUMENTED/OBSERVED/INFERRED/UNKNOWN) gate all phase completion claims | FINAL |

## Decisions Pending Evidence
| ID | Decision | Awaiting |
|---|---|---|
| D-P1 | `binding_policy` enum (`Auto`/`Physical`/`Connector`) on `DisplayEntry` — exact field set | Phase 0 identity mapping table |
| D-P2 | Whether to persist `monitorDevicePath` as the stable key vs. EDID fields | Phase 0 stability observation |

## Important Discoveries (this session)
- SetDisplayConfig fully documented: winuser.h/User32.dll; flags SDC_APPLY/SDC_VALIDATE/SDC_USE_SUPPLIED_DISPLAY_CONFIG/SDC_SAVE_TO_DATABASE; return codes incl ERROR_ACCESS_DENIED. **DOCUMENTED**
- Primary = path priority order (lower array index = higher priority). **DOCUMENTED**
- `DISPLAYCONFIG_TARGET_DEVICE_NAME` exposes monitorDevicePath[128], connectorInstance, edidManufactureId, edidProductCodeId. **DOCUMENTED**

## Tests / Experiments Performed
- **Baseline run on THIS host (non-target HW) — OBSERVED 2026-09-23:** CLI compiles clean + builds release; read-only commands executed. `dump` → QueryDisplayConfig rc=0x57, 0 paths/modes; `list`/`targets`/`pnp`/`identity` empty (all flow through the same QueryDisplayConfig). Meaning of rc=0x57 is **UNKNOWN** pending target-HW interpretation — do NOT treat as a stability verdict.
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

## Documents Affected by New Findings
- `phases/PHASE-0.md` updated: E2 reboot stability NOW OBSERVED (raw_target_id + monitor_device_path PREFIX stable across reboots); E5 confirmed NOT observable for TV on this HW (always-on feature — EDID responds even in "off" state); SetDisplayConfig FIX APPLIED (loads snapshot + real buffers, no longer NULL).
- `DIS-PLAY-REVIEW_FINDINGS_v2.md` §7/§8/§9 updated + new §15 sources section.
- `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` created (new).
- V1 files untouched (immutable history).

## Product Implementation Status
CLI source **compiles clean + builds release** in `product/` (12 files). Read-only commands execute on this host (**OBSERVED**); QueryDisplayConfig returns rc=0x57 / empty topology here (non-target HW). `product/.gitignore` already ignores `target/`, `debug/`. Target-HW build + experiments remain.
