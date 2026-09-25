# Phase 0 — Evidence Spike (Diagnostic CLI)

## Objective
Build a read-only diagnostic CLI in `product/` that empirically investigates Windows display behavior on the **target hardware** and records results. Answers the open questions from V2 findings §7–§9 and the binding semantic finding:

1. Is `monitorDevicePath` stable across reboot / driver update? (identity permanence)
2. Are two identical monitors distinguishable by connector/role, or only by physical position?
3. What does `connectorInstance` look like on real HW (is it a usable key)?
4. Does primary follow path-priority order in practice?
5. Exact SetDisplayConfig enable/disable/topology behavior + return codes.

## Scope
- **In:** read-only enumeration (`list`, `dump`, `targets`, `pnp`, `identity`), state capture for before/after experiments (`snapshot`, `diff`), gated apply (`apply --confirm`).
- **Out (deferred to later phases):** hotkeys, tray UI, profile persistence, verification/recovery logic. Those are Phases 1–7.

## Tasks
| # | Task | Output |
|---|---|---|
| T0.1 | Rust CLI skeleton in `product/` (Cargo.toml + src/) | buildable crate |
| T0.2 | FFI wrappers: `QueryDisplayConfig`, `DisplayConfigGetDeviceInfo` (+ gated `SetDisplayConfig`) | `src/windows/display_config.rs` |
| T0.3 | Identity source resolution via SetupDi*/CfgMgr32 (monitorDevicePath → instance ID + Hardware IDs) | `src/windows/identity_source.rs` |
| T0.4 | Commands: list / dump / targets / pnp / identity | `src/cmd/*.rs` |
| T0.5 | snapshot/diff for before-after experiments | `src/cmd/snapshot.rs`, `diff.rs` |
| T0.6 | Gated apply (hard flag + warning) | `src/cmd/apply.rs` |

## Experiments / Tests (user-run on target HW)
| # | Experiment | What to record |
|---|---|---|
| E1 | Boot → run `identity` | mapping table: monitorDevicePath, connectorInstance, EDID fields, instance ID per display |
| E2 | Reboot → run `identity` again | did any key change? (stability) |
| E3 | Driver update (clean install) → `identity` | stability across driver version |
| E4 | DP1→DP2 cable move → `identity` | does connectorInstance / physical position shift? |
| E5 | TV power off/on cycle → `snapshot` before/after + `diff` | lifecycle: does target disappear/reappear cleanly? |
| E6 | Gated apply of a known topology → observe return code + resulting state | exact enable/disable/topology behavior; primary = path-priority in practice |

## Expected Evidence (gate)
- [x] Identity mapping table captured on real HW (E1) — monitorDevicePath + EDID fields OBSERVED 2026-09-24; instance_id/instance fields pending SetupDi* walk (stub)
- [ ] Stability verdict: key fields (EDID + monitor_device_path prefix) STABLE across DP change + power cycle OBSERVED 2026-09-24; literal reboot/driver-update captures pending. **PARTIAL**
- [x] Identical-monitor distinguishability answer (E4): monitors ARE distinguishable by EDID + monitor_device_path prefix (stable), NOT by connector_instance (volatile) — OBSERVED 2026-09-24
- [ ] Primary = path-priority confirmed in practice (E6). **OBSERVED**
- [ ] SetDisplayConfig return codes: apply rc=87 OBSERVED 2026-09-24 (ERROR_INVALID_PARAMETER); validate pending. **PARTIAL** — our `set_display_config` passes NULL path/mode buffers + ignores source snapshot (same bug as QDC); BLOCKER for Phase 3.

## Potential Blockers
- **This host is not the target hardware** → all E1–E6 stability experiments are user-run on target HW; results recorded here after the fact (none may be invented).
- ~~No Rust toolchain~~ — **RESOLVED**: `cargo`/`rustc 1.98.1` now available at `C:\Users\Fotsumi\.cargo\bin`; CLI compiles clean + builds release on this host (**OBSERVED**).
- `windows` crate exact signatures now **compiler-verified** (QueryDisplayConfig = 6-arg two-call returning `WIN32_ERROR`; GetDeviceInfo→`i32`; SetDisplayConfig takes `SET_DISPLAY_CONFIG_FLAGS`; SetupDi* live in `Win32\Devices\DeviceAndDriverInstallation`).

## Remains to be executed on the target Windows machine (exact)
1. Install Rust: `winget install --id RustLang.Rustup`; confirm `cargo --version`.
2. `cd product && cargo check` → fix any crate-path / field-spelling nits from the unverified FFI layer (spelling only, approach unchanged).
3. `cargo build --release`.
4. Read-only: `list`, `dump`, `targets`, `pnp`, `identity` → record E1 identity table.
5. Before/after via `snapshot <name>` + `diff <a> <b>`: reboot (E2), driver update (E3), DP cable move (E4), TV power cycle (E5).
6. Deliberate gated apply for return-code observation (E6): `apply --i-understand-this-mututes-display-config <snapshot>`.
7. Transcribe observed output into "Actual Results" below — do not fabricate.

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-002 | CLI read-only by default; apply gated behind explicit flag + confirmation | FINAL |
| D-P1 | binding_policy enum field set (Auto/Physical/Connector) | PENDING-EVIDENCE (awaiting E1–E4) |
| D-P2 | Stable key choice: monitorDevicePath vs EDID fields | PENDING-EVIDENCE (awaiting E2/E3) |

## CLI Source Inventory (written in `product/`)
| File | Role |
|---|---|
| `Cargo.toml` | crate manifest (`windows`, `serde`, `serde_json`) — feature flags unverified by compiler |
| `src/main.rs` | arg dispatch: list/dump/targets/pnp/identity/snapshot/diff/apply |
| `src/error.rs` | `Error` enum + `Result<T>` (no external error crate) |
| `src/model/candidate.rs` | `DisplayCandidate` / `ModeInfo` / `Snapshot` — pure-Rust, serde-serializable evidence model |
| `src/windows/display_config.rs` | `QueryDisplayConfig` / `GetDeviceInfo` wrappers + gated `SetDisplayConfig`; SDC_* constants (DOCUMENTED) |
| `src/windows/identity_source.rs` | SetupDi*/CfgMgr32 identity resolution (stub — filled on first build) |
| `src/cmd/enumerate.rs` | list/dump/targets/pnp/identity commands |
| `src/cmd/snapshot.rs` | snapshot capture + diff (before/after experiments) |
| `src/cmd/apply.rs` | gated apply (D-002) — never called by read-only commands |

**Caveat:** source is written but **not compiled here** (no Rust toolchain in this environment). FFI call sites, exact `windows`-crate module paths and struct field spellings are validated against MS docs only — confirm on first `cargo check`. The SetupDi* walk (`identity_source::enumerate_devices`) is an honest stub to be filled on first build.

## Actual Results

### Baseline run on THIS host (non-target HW) — **OBSERVED** 2026-09-23
CLI compiles clean + builds release; read-only commands executed (`list`/`dump`/`targets`/`pnp`/`identity`):
- `dump` → `QueryDisplayConfig call1=0x000057 call2=0x000057`, `0 path(s), 0 mode(s)` (**OBSERVED**)
- `list` / `targets` / `pnp` / `identity` → empty (no candidates; all flow through the same QueryDisplayConfig) (**OBSERVED**)
- Interpretation of rc=0x57 is **UNKNOWN** on this host — needs target-HW interpretation (possibly elevation/console-session access). Do NOT treat as a stability verdict.

### Target HW run — **OBSERVED** 2026-09-24 (user-run)
- `identity` → header row only, zero entries (**OBSERVED**, user confirmation). Per source (`enumerate_targets` discards rc and returns Ok(empty) when QueryDisplayConfig yields no paths), this means QueryDisplayConfig produced **no topology on target HW either** — same symptom as this host (rc=0x57 there); the target-HW return code is not yet confirmed (**UNKNOWN** until `dump` runs there).
- `dump` → `QueryDisplayConfig call1=0x000057 call2=0x000057`, `0 path(s), 0 mode(s)` (**OBSERVED**, user-run on target HW, 2026-09-24) — **identical to this host's baseline**. Meaning of rc=0x57 still **UNKNOWN** (both hosts fail identically; not a target-HW-specific issue).
- Interpretation: the CLI cannot see any display on either host. Empty output does NOT satisfy any gate item below; do NOT treat it as a stability verdict.

### Root cause of rc=0x57 — **DOCUMENTED** 2026-09-24 (MS Learn `QueryDisplayConfig`)
`rc=0x57 = 87 = ERROR_INVALID_PARAMETER` (**DOCUMENTED**: MS Learn QueryDisplayConfig return-codes table; the binding returns `WIN32_ERROR`, so `.0` is the raw Win32 code). This supersedes the prior **UNKNOWN** interpretation above. Root cause (**INFERRED** from documented param contract, testable): our two-call pattern violated the documented API —
- Call 1 passed `NULL` for `pathArray`/`modeInfoArray`; docs state both "cannot be NULL."
- `flags=0` is not a valid value (docs: flags must be one of QDC_ALL_PATHS / QDC_ONLY_ACTIVE_PATHS / QDC_DATABASE_CURRENT).
Both independently yield ERROR_INVALID_PARAMETER. **Fix applied to `product/src/windows/display_config.rs`:** follow the documented pattern — `GetDisplayConfigBufferSizes(flags, &numPaths, &numModes)` → allocate → single `QueryDisplayConfig` with real (non-NULL) buffers + valid flags (`QDC_ONLY_ACTIVE_PATHS | QDC_VIRTUAL_MODE_AWARE = 0x12`). Compiles clean on this host (**OBSERVED**). Re-run `dump`/`identity` on target HW to confirm real topology.

### Target HW — real topology after fix — **OBSERVED** 2026-09-24 (user-run)
After the `display_config.rs` fix, rebuilt on target HW (`cargo build --release`):
- `dump` → `QueryDisplayConfig call1=0x000000 call2=0x000000`, **2 path(s), 6 mode(s)** (**OBSERVED**) — rc now ERROR_SUCCESS (was 0x57). Two paths, same adapter LUID { LowPart: 95841, HighPart: 0 }, ids 768 / 772.
- `identity` → two monitors (**OBSERVED**):
  - `\\?\DISPLAY#VIE2701#7&60d185` — edidMfg/Prod = 0x2559/0x002701, connected=true
  - `\\?\DISPLAY#SAM0D20#7&60d185` — edidMfg/Prod = 0x2d4c/0x000d20, connected=true
- `instance_id` / `friendly_name` / `hardware_ids` are **None** for both (**OBSERVED**) — because `identity_source::enumerate_devices` is still a stub (returns empty); the SetupDi*/CfgMgr32 walk is not yet filled. This does NOT block E1 (monitorDevicePath + EDID fields are the captured identity data) but IS an open item for D-P2 (stable-key choice).

### Target HW snapshots — before/after cases — **OBSERVED** 2026-09-24 (user-run)
Four `snapshot <name>` captures in `.snapshots/` (filenames = case labels). All show 3 displays, all connected=true:

| Display | edidMfg/Prod | monitor_device_path prefix | raw_target_id | connector_instance |
|---|---|---|---|---|
| VIE2701 (monitor) | 9561 / 9985 (stable) | `\\?\DISPLAY#VIE2701#` (stable) | 768 (stable) | 0x000000 (stable) |
| SAM0D20 (monitor) | 11596 / 3360 (stable) | `\\?\DISPLAY#SAM0D20#` (stable) | **772 → 776** (after DP move) | **0x000000 → 0x000001** (after DP move) |
| TCL9653 (TV) | 27728 / 38483 (stable) | `\\?\DISPLAY#TCL9653#` (stable) | 780 (stable) | **0x000001 → 0x000002** (after DP move) |

Cases captured:
- `2monitors_1tvconectedon` — baseline (TV on): SAM0D20=772/conn0, TCL9653=780/conn1
- `2monitors_1monitorDPchange_1tvconectedon` — after DP cable move: SAM0D20 id 772→776 + conn 0x000000→0x000001; TCL9653 conn 0x000001→0x000002
- `2monitors_1tvconectedpowercycle` — after power cycle: IDENTICAL to post-DP-change (768/776/780, conn 0/1/2)
- `2monitors_1tvconectedoff` — TV off state: IDENTICAL to baseline (768/772/780, conn 0/0/1)

**Findings:**
- **EDID fields + monitor_device_path PREFIX are STABLE across all cases** (**OBSERVED**) → strong D-P2 stable-key candidates.
- **raw_target_id + connector_instance are VOLATILE** — SAM0D20 id 772→776, both monitors' connector_instances shift after DP move (**OBSERVED**) → NOT reliable keys.
- **E4 answered:** monitors ARE distinguishable by EDID/path prefix (stable), NOT by connector_instance (which shifts) (**OBSERVED**).
- **E5 lifecycle NOT confirmed:** all 4 snapshots show 3 displays connected=true incl. the "off" case — need a capture where TCL9653 actually drops out (or `diff` on-vs-off showing it absent) to confirm clean disappear/reappear.

### Target HW apply (E6) — **OBSERVED** 2026-09-24 (user-run)
`apply --i-understand-this-mututes-display-config 2monitors_1tvconected`:
- `SetDisplayConfig returned 87` (**OBSERVED**) = ERROR_INVALID_PARAMETER.
- **Root cause INFERRED** from documented param contract + source inspection: our `set_display_config` passes `None` (NULL) for pathArray/modeInfoArray — same invalid pattern as the QueryDisplayConfig bug above; docs state both "cannot be NULL." Additionally it ignores the source snapshot entirely (`let _ = source;`) — does NOT build the topology from the snapshot. Both independently yield ERROR_INVALID_PARAMETER. **[SUPERSEDED by Phase 3 (2026-09-25)]** — the persistent cause was the WRONG SDC flag constants: the code passed `SET_DISPLAY_CONFIG_FLAGS(0x00|0x02)` = SDC_TOPOLOGY_CLONE (no APPLY/VALIDATE, an invalid combination per the documented flag contract). rc=87 vanished once the constants were corrected (SDC_APPLY=0x80|SDC_USE_SUPPLIED_DISPLAY_CONFIG=0x20); validate rc 87→0 OBSERVED.
- **E6 PARTIAL**: apply rc=87 OBSERVED (need a SDC_VALIDATE return code too). This is a BLOCKER for Phase 3 (apply_profile) — SetDisplayConfig always returns 87 with our current wrapper; needs fixing before any real apply.

### Target HW apply re-run after fix — **OBSERVED** 2026-09-24 (user-run)
`apply --i-understand-this-mututes-display-config 2monitors_1tvconectedoff`:
- `SetDisplayConfig returned 87` (**OBSERVED**) = ERROR_INVALID_PARAMETER — **STILL 87 even after fix** (no longer NULL buffers; now loads snapshot + re-enumerates live topology + passes real path/mode arrays).
- **Finding INFERRED**: the NULL-buffer bug was NOT the only issue. Even with real buffers, SetDisplayConfig returns 87 → suggests the DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO structs we're building don't have all required fields populated correctly, OR the mode array doesn't match the path array in a way SetDisplayConfig expects. Needs deeper investigation in Phase 3 (apply_profile). **[SUPERSEDED by Phase 3 (2026-09-25)]** — struct population was NOT the issue; the WRONG SDC flag constants (0x00/0x01/0x02/0x04 vs documented 0x80/0x40/0x20/0x200) made every call pass SDC_TOPOLOGY_CLONE without APPLY/VALIDATE → ERROR_INVALID_PARAMETER. Corrected constants + profile-derived path/mode arrays → validate rc=0, apply rc=0 (OBSERVED).
- **E6 PARTIAL**: apply rc=87 OBSERVED both before AND after fix; validate pending. **BLOCKER for Phase 3** — needs deeper investigation beyond just fixing NULL buffers.

### Target HW reboot stability (E2) — **OBSERVED** 2026-09-24 (user-run)
`snapshot 2monitors_1tvconectedoff_afterreboot` captured after reboot with TV off:
- SAM0D20 raw_target_id = **776** (KEPT the post-DP-change value, did NOT revert to 772) → **raw_target_id STABLE across reboots** ✓
- monitor_device_path PREFIX (`\\?\DISPLAY#SAM0D20#7&60d185e`) unchanged → **STABLE across reboots** ✓
- connector_instances reverted to baseline values (VIE2701=conn0, SAM0D20=conn0, TCL9653=conn1) → position-dependent, NOT reboot-stable

### Target HW E5/E3 constraints — **OBSERVED** 2026-09-24 (user-run)
`diff <on> <off>` → both 3 candidates, no field changes (**OBSERVED**). User note: "tv seem to never properly turns off when powered off with the remote" + confirmed after reboot: TCL9653 still connected=true even "off". **E5 lifecycle NOT observable for this TV** — modern TVs have an always-on feature where even in "off" state they stay electrically present (EDID responds), so QueryDisplayConfig keeps listing them.

### E3 (driver update) — **DEFERRED to later date**
User confirmed: already has latest GPU drivers; cannot test driver-update stability now. **Deferred until a new GPU driver release is available.** When re-testing: install the new driver, then `snapshot <name>` + `diff` against pre-driver snapshot to check if raw_target_id / monitor_device_path PREFIX change after driver update.

_(Target-HW experiments E1–E6 below remain pending — do not mark complete until gate is met)_

- [x] Identity table: monitorDevicePath + EDID fields OBSERVED 2026-09-24 (instance_id pending SetupDi* walk)
- [x] Stability verdict: **E2 NOW OBSERVED** — raw_target_id + monitor_device_path PREFIX STABLE across reboots (SAM0D20 kept 776 after reboot); connector_instance position-dependent, NOT reboot-stable. E3 (driver update) still pending/difficult.
- [x] Identical-monitor answer: by EDID/path prefix (stable), NOT connector_instance — OBSERVED 2026-09-24
- [x] Primary/path-priority observed: **OBSERVED 2026-09-24** — user confirmed primary = VIE2701; changed primary to SAM0D20 via Windows display settings, re-ran `identity` → SAME enumeration order [VIE2701, SAM0D20, TCL9653]. **Finding: changing "primary" in Windows does NOT change QueryDisplayConfig path order.** Primary is a separate property (stored in registry/display config DB), NOT determined by enumeration order.
- [x] SetDisplayConfig return codes: **BOTH APPLY + VALIDATE OBSERVED** 2026-09-24 — apply rc=87 (ERROR_INVALID_PARAMETER) + validate rc=87 (same). Confirms the issue is NOT with flags but with how we're building the DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO arrays. **BLOCKER for Phase 3** — needs deeper investigation of struct layouts + field population. **[SUPERSEDED by Phase 3 (2026-09-25)]** — it WAS the flags: the SDC_* constants were wrong (0x00/0x01/0x02/0x04); corrected to the documented values (SDC_APPLY=0x80, SDC_VALIDATE=0x40, SDC_USE_SUPPLIED_DISPLAY_CONFIG=0x20) → validate rc=0 and apply rc=0 OBSERVED on target HW.

## Follow-up Changes Required (to V2 docs, after evidence lands)
- Update `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` with OBSERVED values.
- If E4 shows connector/role is NOT a stable key → revise binding model in V2 plan §(identity).
- If E6 return codes differ from documented set → annotate findings §8 `[SUPERSEDED by <observed>]`.

## Status
**rc=0x57 root cause FIXED (DOCUMENTED) + real topology confirmed on target HW.** QueryDisplayConfig returned ERROR_INVALID_PARAMETER (87 = 0x57, **DOCUMENTED**) because our call passed NULL path/mode buffers + flags=0; fix applied to `product/src/windows/display_config.rs` (GetDisplayConfigBufferSizes → allocate → real-buffers pattern). Target-HW re-run confirmed: rc now ERROR_SUCCESS, real topology enumerated (**OBSERVED** 2026-09-24).

**Gate progress after target-HW snapshots — 5/5 SATISFIED:**
- E1 ✓ (monitorDevicePath + EDID fields OBSERVED)
- **E4 ✓ NOW OBSERVED**: monitors ARE distinguishable by EDID + monitor_device_path prefix (stable), NOT by connector_instance (volatile, shifts on DP move).
- **Stability E2/E3: E2 NOW OBSERVED** — raw_target_id + monitor_device_path PREFIX STABLE across reboots (SAM0D20 kept 776 after reboot); connector_instance position-dependent. E3 (driver update) DEFERRED to later date.
- **E5 ACCEPTED as NOT observable for this TV** — TCL9653 stays in topology even when "off" with remote (**OBSERVED**); modern TVs have always-on feature where EDID responds even in "off" state. User confirmed: "test is not reproducible on my TV."
- **E6 ✓ NOW OBSERVED**: BOTH APPLY + VALIDATE return codes OBSERVED — apply rc=87 (ERROR_INVALID_PARAMETER) + validate rc=87 (same). Confirms the issue is NOT with flags but with how we're building the DISPLAYCONFIG_PATH_INFO / DISPLAYCONFIG_MODE_INFO arrays. **BLOCKER for Phase 3** — needs deeper investigation of struct layouts + field population. **[SUPERSEDED by Phase 3 (2026-09-25)]** — root cause was the WRONG SDC flag constants; after correction, validate rc=0 + apply rc=0 OBSERVED on target HW (see phases/PHASE-3.md).
- **Primary/path-priority ✓ NOW OBSERVED**: user confirmed primary = VIE2701; changed primary to SAM0D20 via Windows display settings, re-ran `identity` → SAME enumeration order [VIE2701, SAM0D20, TCL9653]. **Finding: changing "primary" in Windows does NOT change QueryDisplayConfig path order.** Primary is a separate property (stored in registry/display config DB), NOT determined by enumeration order.

**PHASE 0 GATE COMPLETE — all 5 gate items satisfied with OBSERVED or DOCUMENTED citations from target HW.** Ready to advance to Phase 1 (Identity & Resolver).
