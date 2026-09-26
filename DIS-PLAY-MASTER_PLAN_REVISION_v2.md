# Native Windows Display Profile Manager — Master Plan (V2)

This document stands alone. It is the V2 master plan for a native Windows display-profile manager written in Rust. It supersedes `DIS-PLAY-MASTER_PLAN_REVISION.md` and does not require reading any earlier version.

Target environment: Windows PC, AMD Radeon RX 7800 XT, two desktop monitors + one Sony TV on the GPU. Profiles such as **Work** (Monitor A ON, Monitor B ON, TV OFF) and **Gaming** (Monitors OFF, TV ON).

Confidence labels used below — **DOCUMENTED** (Microsoft/SDK docs consulted during review), **OBSERVED** (expected on this machine, unconfirmed here), **INFERRED** (reasoned, plausible), **UNKNOWN** (needs an experiment). Where a detail is not yet established it is routed into the Phase 0 CLI spike rather than asserted.

## 1. Project Overview
A lightweight native Windows application in Rust that identifies physical displays robustly, saves named display profiles, restores them, verifies the result, and eventually provides a tray UI and global hotkeys. It must NOT rely on volatile identifiers (`\\.\DISPLAYn`, MultiMonitorTool IDs) that change after driver updates, hotplug, sleep/wake, or topology events.

## 2. Goals
1. Discover all displays currently visible to Windows.
2. Identify physical displays robustly via an **evidence-based identity model** (no single identifier assumed authoritative).
3. Capture the current Windows display configuration.
4. Save configurations as named profiles.
5. Restore profiles reliably, re-resolved against current hardware.
6. Detect when Windows has changed enumeration / topology.
7. Resolve a profile entry to a currently detected display and answer: *"Is this currently detected Windows display the same display represented by this profile entry?"* with **UNIQUE / AMBIGUOUS / UNKNOWN**.
8. Verify that a requested configuration was actually applied.
9. Provide fast profile switching through a system tray application.
10. Support global keyboard shortcuts.
11. Remain lightweight and native to Windows.

## 3. Non-Goals for V1
Game detection, per-game automatic profiles, cloud/multi-PC sync, remote control, GPU-vendor-specific APIs, display calibration, color management, HDR management, audio-device switching, fancy UI, Windows service architecture, cross-platform support. These may be evaluated after the core is stable.

## 4. Design Principles
1. **Evidence over assumption.** Do not decide what the persistent identity *is* before investigating how Windows connects DisplayConfig targets to PnP devices, connector information, and EDID-derived information. The architecture emerges from Phase 0 evidence.
2. **No single magical identifier.** Build a resolver that weighs available signals and reports UNIQUE / AMBIGUOUS / UNKNOWN; it must be able to *refuse* an unsafe ambiguous match.
3. **Profiles are desired complete configurations**, re-resolved at apply time — not raw runtime handles or transient names.
4. **Capture before manually defining.** Configure in Windows → capture → save as a named profile.
5. **Best-effort application + mandatory verification.** Never claim atomicity; report the true outcome.

## 5. Technical Architecture
Three layers with a crisp boundary so identity/resolver/profile logic is unit-testable on any OS without live Windows calls:

```
UI Layer            tray / menu / notifications   (thin Win32, late in build order)
                        │
Application Core    profile manager · display resolver · capture/apply orchestration
                        │        pure Rust: operates on a DiscoveredDisplay model, no FFI
                        ▼
Windows Integration  display_config.rs (Query/Set DisplayConfig + GetDeviceInfo)
                      identity_source.rs (SetupDi*/CfgMgr32 → PnP instance ID + Hardware IDs; EDID fields if cheaply available)
                      hotkeys.rs    (RegisterHotKey)
                      tray.rs       (Shell_NotifyIcon / message loop)
```

Rules:
- **Pure-Rust core** (`model/`, `core/`) takes a *discovered display model* as input and emits identity evidence, resolution decisions, and profile I/O. No Win32 calls inside — testable with fixtures on any OS.
- **Thin FFI layer** (`windows/`) is the only place touching `winuser.h` (Query/Set DisplayConfig), `wingdi.h` (DISPLAYCONFIG_* structs), `setupapi`/CfgMgr32, `user32`. It produces the discovered model and applies results; it does not own policy.

## 6. Display Identity Architecture (evidence model)
Do NOT use a fixed hierarchy (`PnP > EDID > topology`). Use an **identity evidence model**: each detected display is a candidate carrying multiple *optional* signals, and the resolver determines uniqueness from what is actually available.

```rust
// provisional — fields finalized after Phase 0 confirms which are stable/available
struct DisplayCandidate {
    // DisplayConfig target side (per-session; NOT persisted as identity)
    target_id: Option<TargetId>,        // per-session handle/id — never an identity key
    adapter_id: String,                 // GPU output/source identity
    connector_instance: Option<String>,// physical port / connector instance

    // Persistent PnP evidence (the promising candidates; stability = Phase 0)
    monitor_device_path: Option<String>,// DISPLAYCONFIG_TARGET_DEVICE_NAME.monitorDevicePath
    pnp_instance_id: Option<String>,   // resolved via SetupDi*/CfgMgr32
    hardware_ids: Vec<String>,         // type/model — shared by identical units, NOT unique

    // EDID-derived (optional disambiguation; do not assume present)
    edid_manufacturer: Option<String>,
    edid_product_code: Option<String>,
    edid_serial: Option<String>,       // frequently absent (TVs especially)

    friendly_name: String,             // e.g. "Generic PnP Monitor" — NOT unique
}
```

The resolver answers per profile entry: **UNIQUE** (exactly one candidate matches all available distinguishing signals), **AMBIGUOUS** (more than one candidate matches the available signals and none distinguishes them), **UNKNOWN** (no candidate can be matched). It must refuse an unsafe ambiguous match rather than silently assign.

Identity concepts kept distinct (do not collapse):
- **logical Windows display** = `\\.\DISPLAYn` — transient, changes with enumeration; never identity.
- **DisplayConfig target** = per-session `targetId`/handle — not persistent across reboot.
- **physical monitor** = the actual panel/unit.
- **physical connector** = DP1/HDMI1/etc. on the GPU.
- **PnP device** = enumerated "Monitor" class device with an instance path.
- **device model** = identified by Hardware ID (type/model; shared by identical units).
- **persistent identifier** = candidate: `monitorDevicePath` / PnP instance path — *validated in Phase 0, not assumed*.

## 7. Display Discovery
Discovery produces one `DisplayCandidate` per currently detected display, populated from the Windows FFI layer:
- Enumerate sources/targets via `QueryDisplayConfig`.
- For each target, call `DisplayConfigGetDeviceInfo` → `DISPLAYCONFIG_TARGET_DEVICE_NAME` (`monitorDevicePath`, friendly name).
- Resolve `monitorDevicePath` through SetupAPI/CM (`SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces`) → PnP instance ID + Hardware IDs.
- Read EDID-derived fields (manufacturer/product/serial) only if cheaply available; do not add raw EDID parsing.

The discovered model also carries runtime state: `connected` (currently enumerated), `active` (has an applied mode / attached to a source), and the current mode when active.

## 8. DisplayConfig Integration
- **Read:** `QueryDisplayConfig` is the authoritative read of source/target/mode sets per adapter — used for capture and verification.
- **Apply:** `SetDisplayConfig` applies a source→target path + mode; attach/detach targets to change topology. It is **best-effort, not atomic** (no documented transaction guarantee). The flag set is now DOCUMENTED (`SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG` to apply supplied config; `SDC_VALIDATE | SDC_USE_SUPPLIED_DISPLAY_CONFIG` to test without applying; add `SDC_SAVE_TO_DATABASE` to persist); return codes include `ERROR_ACCESS_DENIED` (console-session access). Only the exact "detach target for off" sequence remains **SPIKE** — do not assert it as fact.
- **Identity source:** `DisplayConfigGetDeviceInfo` provides `monitorDevicePath` + friendly name for a target — this is a primary identity source, not merely cross-check.

## 9. PnP / EDID Integration
- **PnP (primary evidence path):** resolve `monitorDevicePath` via SetupAPI/CM to obtain the PnP instance ID and Hardware IDs. Do NOT treat Hardware IDs as a unique physical identity — they identify type/model and are shared by identical units.
- **EDID:** do not add raw EDID parsing. Use EDID-derived fields (manufacturer/product/serial when present) only as optional disambiguation if cheaply available. The minimum identity required is: a persistent per-unit signal (`monitorDevicePath`/PnP instance path, validated) + disambiguation for identical units via connector/instance — NOT raw EDID bytes.
- **WMI:** NOT REQUIRED (optional cross-check only). Do not add it just because it overlaps SetupAPI/DisplayConfig.

## 10. Profile Model
Derive the persisted schema from the identity and SetDisplayConfig investigations; do NOT finalize it before Phase 0 shows which signals are actually stable. The profile must answer: *"What information do we need to persist so that we can reconstruct this user's desired configuration after reboot, enumeration changes, driver updates, hotplug, or a changed topology?"*

Provisional shape (finalize post-spike):
```rust
struct DisplayProfile {
    name: String,
    displays: Vec<DisplayEntry>,
}

struct DisplayEntry {
    // identity evidence used to re-resolve (NOT runtime handles / NOT \\.\DISPLAYn)
    key_evidence: IdentityEvidence,   // monitor_device_path / pnp_instance_id when stable; connector binding; EDID fields when present
    role: Option<DisplayRole>,        // "the display occupying this position/connector" — needed for identical units
    desired_mode: DesiredMode,        // resolution, refresh, orientation, position/offset
    primary: bool,                    // desired primary state (verified post-apply); set via path-priority order in SetDisplayConfig
    enabled: bool,                    // active vs disabled (disabled = target not attached to an active source path)
}
```

Rules:
- **Never** persist transient names (`\\.\DISPLAYn`) or per-session `targetId`/handles as identity. A last-seen DisplayConfig target name/handle may be cached for fast-path matching only, and must be re-derived from stable evidence before use.
- Re-resolution against current hardware is mandatory so profiles survive driver updates / reboots / topology change.
- Persist both **physical identity** (the unit) and **display role / connector binding**, because identical units can only be distinguished by connector/instance; represent ambiguity when they conflict.

## 11. Apply / Restore Strategy — `apply_profile()`
Application is **best-effort + mandatory verification**, not atomic: a full topology change spans multiple displays/adapters and can partially fail.

```text
Load profile
      ↓
Discover current displays (DisplayCandidate list)
      ↓
Resolve each profile entry → UNIQUE / AMBIGUOUS / UNKNOWN
Map profile → current Windows displays
Validate (refuse unsafe AMBIGUOUS; unsupported mode → FAILED)
Construct desired configuration (path+mode per display; disabled = target not attached to an active source path — exact mechanism SPIKE)
SetDisplayConfig(SDC_APPLY|SDC_USE_SUPPLIED_DISPLAY_CONFIG)   # best-effort, NOT transactional; exact detach sequence SPIKE
Query resulting configuration
Verify (desired vs actual)  # mandatory
```

Do not assert a specific enable/disable/topology/primary mechanism. The *shape* is: build the desired path+mode per display and apply via `SetDisplayConfig`, then re-query and compare. All specifics that are not yet validated are Phase 0 experiments.

## 12. Verification
After applying, query the resulting configuration again and compare desired vs actual. Outcome states:
- **SUCCESS** — requested topology achieved
- **PARTIAL** — subset applied; some displays missing/unresolved
- **FAILED** — could not apply (unsupported mode, driver rejection)
- **AMBIGUOUS** — identity cannot be uniquely resolved

Behavior rules: no auto-retry loops in V1; report clearly; never claim full restore when a display is missing. Define retry/fallback/abort for: missing displays, ambiguous identity, unsupported mode, invalid topology, `SetDisplayConfig` failure, driver rejection, display becoming unavailable during application, and Windows changing configuration afterward.

## 13. Failure Handling
Map each failure to an explicit outcome and user-visible message; never silently claim full restoration. In particular: a profile entry that is AMBIGUOUS (e.g., two identical units with no distinguishing signal) must be refused or reported, not silently assigned. An unsupported requested mode fails cleanly without corrupting the current configuration.

## 14. Hotplug Handling
Handle late/absent detection: do not assume a display present at startup stays present; re-resolve on apply and (optionally) on device-change notification (`RegisterDeviceNotification` / `WM_DEVICECHANGE`, or lazy re-resolution as fallback). A display that disappears and returns is matched by its evidence, not by a stale binding.

## 15. TV Handling
A powered-off HDMI TV may be absent from enumeration entirely; do not assume it is visible. Behavior across the Sony TV's states (on / off / sleeping / disconnected / connected-but-unavailable / on-after-PC / off-while-active) is **OBSERVED/UNKNOWN until tested** — the state model reflects observed behavior, and a profile expecting an absent TV reports PARTIAL/AMBIGUOUS honestly. Whether the TV re-registers with a stable `monitorDevicePath` after power-on is a Phase 0 experiment.

## 16. Identical-Display Handling
Two physically identical monitors (same manufacturer/model/product code, missing serial, identical EDID) can only be distinguished by connector/instance — NOT by EDID/model. The resolver must support both physical-identity matching and role/connector matching, and represent ambiguity when they conflict (e.g., the user swapped which unit is on DP1 vs DP2). Whether two Dells get distinct `monitorDevicePath`/PnP instance paths is **UNKNOWN until Phase 0 confirms**; if not, only role/connector works and physical identity is impossible.

## 17. Rust Architecture
Keep the V1 principle (FFI → discovered model → pure-Rust logic → apply adapter) with corrected interfaces:
- The FFI→core interface is a **`DisplayCandidate`** carrying *evidence fields* (not just an "identity"), so the evidence model is testable via fixtures.
- Pure-Rust core operates against fixtures representing: normal displays, identical displays, missing serials, missing TV, reordered enumeration, changed connector, ambiguous identity.
- Windows-specific code stays isolated in `windows/`; no policy there.

## 18. Repository Structure
```text
display-switcher/
├── Cargo.toml
├── README.md
├── docs/
│   ├── architecture.md
│   ├── display-identity.md
│   └── windows-api.md
├── src/
│   ├── main.rs
│   ├── app.rs
│   ├── error.rs
│   ├── model/            # pure Rust, no FFI — testable on any OS
│   │   ├── mod.rs
│   │   ├── candidate.rs  # DisplayCandidate (evidence fields) + runtime state
│   │   └── profile.rs    # DisplayProfile / DisplayEntry (provisional schema)
│   ├── core/            # pure Rust policy: evidence resolution, capture/apply orchestration
│   │   ├── mod.rs
│   │   ├── resolver.rs   # candidate → UNIQUE/AMBIGUOUS/UNKNOWN; refuses unsafe matches
│   │   └── verify.rs     # desired-vs-actual comparison
│   ├── windows/         # thin FFI only (the sole place touching Win32)
│   │   ├── mod.rs
│   │   ├── display_config.rs  # Query/Set DisplayConfig + GetDeviceInfo, mode sets
│   │   ├── identity_source.rs # SetupDi*/CfgMgr32 → PnP instance ID + Hardware IDs; EDID fields if available
│   │   ├── hotkeys.rs         # RegisterHotKey
│   │   └── tray.rs            # Shell_NotifyIcon / message loop
│   └── ui/
│       ├── mod.rs
│       └── tray_menu.rs
└── tests/               # pure-logic unit tests (any OS) + Windows integration harness
    ├── resolver.rs        # fixtures: normal, identical, missing serial, missing TV, reorder, connector change, ambiguous
    └── verify.rs
```

Invariant: **`core/` and `model/` never call Win32**, so the critical subsystems are testable in CI without hardware.

## 19. Phase 0 CLI Spike (implementation-ready spec)
A diagnostic CLI whose purpose is to empirically establish, on the developer's actual machine, how Windows connects DisplayConfig targets to PnP devices / connectors / EDID-derived info. Commands:

```text
dis-play list        # enumerate detected displays with runtime state (connected/active/mode)
dis-play dump       # full QueryDisplayConfig source/target/mode dump per adapter
dis-play targets    # per target: DisplayConfigGetDeviceInfo → monitorDevicePath, friendly name
dis-play pnp        # resolve each monitorDevicePath via SetupDi*/CfgMgr32 → instance ID + Hardware IDs
dis-play identity   # join the above into one table (the mapping below)
dis-play experiment # run a specific spike (e.g., power TV off/on; move DP1→DP2; reboot/driver-update) and diff
```

`identity` output — the key diagnostic table:

```text
DisplayConfig Target          PnP Device
  Adapter                   Instance ID
  Target ID                 Hardware IDs
  Connector Instance        Device Interface
  Monitor Device Path       (cross-check vs monitorDevicePath)
  Friendly Name             EDID manufacturer / product / serial (if available)
```

Goal: fill this table for the two monitors + Sony TV and observe how it changes across reboot, driver update, DP1→DP2 move, and TV power off/on. **Gate:** every physical display can be distinguished by a stable key, modes are readable, and the identity mapping is empirically established before any profile/apply design locks.

## 20. Development Phases (with gates)
Prove the Windows core before any UI. Add the missing spikes.

- **Phase 0 — CLI spike.** Build `dis-play` above; run experiments: PnP-path stability across reboot + driver update; identical-monitor distinguishability (incl. whether two units get distinct `connectorInstance`); EDID field availability (`edidManufactureId`/`edidProductCodeId` present? serial absent?); `SetDisplayConfig` exact "detach target for off" sequence + confirm path-priority ordering sets primary; powered-off-TV visibility (incl. re-registration after power-on); privilege requirements (console-session access per `ERROR_ACCESS_DENIED`). **Gate:** the identity mapping table is filled and every physical display distinguished by a stable key.
- **Phase 1 — Identity & resolver (pure Rust).** Implement `DisplayCandidate` + evidence resolution → UNIQUE/AMBIGUOUS/UNKNOWN; refuse unsafe matches. Dedicated tests: reorder, identical monitors, missing serial, connector change, ambiguous. **Gate:** enumeration changes do not change physical identity; ambiguous cases surface as AMBIGUOUS and are refused, not silently assigned.
- **Phase 2 — Capture + persistence.** `capture_current()` → profile model (finalize schema from Phase 0 evidence) → JSON round-trip. **Gate:** captured config serializes and re-resolves equivalently against current hardware.
- **Phase 3 — Apply (`apply_profile`).** Build path+mode, disabled = target not attached to active source (exact mechanism SPIKE), apply via `SetDisplayConfig`, then verify. Tests: Work→Gaming→Work; TV disconnected; monitor disconnected; TV powered off; display order changed; resolution manually changed. **Gate:** profiles reliably switch topology and verification reports the true outcome.
- **Phase 4 — Verification & recovery.** Desired-vs-actual comparison → SUCCESS/PARTIAL/FAILED (+ AMBIGUOUS). Define retry/fallback/abort behavior (no silent full-restore claims). **Gate:** app can state whether the requested profile was achieved.
- **Phase 5 — Tray application.** Minimal tray, profiles list, capture action, notifications, optional startup. Keep thin; no fancy UI.
- **Phase 6 — Hotkeys.** Configurable global shortcuts (`Ctrl+Alt+W` / `Ctrl+Alt+G`).
- **Phase 7 — Hardening.** Reboot, sleep/wake, HDMI/DP hotplug, TV power off/on, GPU driver updates, Windows updates, refresh/resolution changes, HDR state changes, scaling changes, multiple identical monitors, missing displays, reordered displays.

## 21. Acceptance Tests
- **A1 — Enumeration reorder:** enumeration order changes but physical displays are the same → resolver still identifies the same physical displays (same evidence), independent of `\\.\DISPLAYn` order.
- **A2 — Work/Gaming round trip:** Work → Gaming → Work restores exact topology each time; verification returns SUCCESS with no missing displays.
- **A3 — TV unavailable:** TV powered off or absent → applying a profile referencing it reports PARTIAL (or AMBIGUOUS if identity can't be resolved), never claims full restore, applies the available subset correctly.
- **A4 — Identical monitors:** two identical units exist → distinguished by connector/instance; ambiguity surfaced when no signal distinguishes them.
- **A5 — Missing serial:** a display has no EDID serial → identity still resolves via `monitorDevicePath`/connector (or AMBIGUOUS if truly indistinguishable); never assumes serial present.
- **A6 — Unsupported mode:** profile requests an unsupported resolution/refresh → fails cleanly (FAILED) without corrupting the current config.
- **A7 — Sleep/wake:** PC sleeps and wakes → re-resolution still maps evidence to correct physical displays; no stale `DISPLAYn` binding survives.
- **A8 — Hotplug:** display disconnected and reconnected → matched by evidence, not a stale binding; late/absent detection handled.
- **A9 — Connector change:** monitor moves DP1→DP2 → expected behavior per the identity model (changed binding vs same physical unit) is explicit and reported consistently.
- **A10 — GPU driver update:** after an AMD driver update, identity evidence and profiles remain usable (re-resolved); no stale handles.
- **A11 — Windows reboot:** profiles remain usable after reboot; re-resolution succeeds against current hardware.
- **A12 — Primary display:** if primary is part of V1, the chosen primary display is correctly restored and verified post-apply (set via path-priority order in `SetDisplayConfig`).
- **A13 — Partial application:** force/simulate a partial configuration failure → result reported as PARTIAL/FAILED correctly; no silent full-restore claim.

## 22. Risks
**R1 — Identity permanence unproven.** No evidence yet that `monitorDevicePath`/PnP instance path is stable across reboot/driver update or unique per unit (esp. identical monitors). Mitigation: Phase 0 CLI produces the mapping table before any identity key locks; resolver degrades gracefully and reports AMBIGUOUS/UNKNOWN.
**R2 — Identical-monitor distinguishability unproven.** Whether two Dells get distinct `monitorDevicePath`/instance paths is unknown; if not, physical identity is impossible and only role/connector works (with ambiguity). Mitigation: Phase 0 test; design supports both physical-identity and role/connector matching.
**R3 — SetDisplayConfig apply semantics partially unvalidated.** The flag set (`SDC_APPLY`/`SDC_VALIDATE`/`SDC_USE_SUPPLIED_DISPLAY_CONFIG`) and return codes are DOCUMENTED, but the exact "detach target for off" sequence + path-priority placement for primary remain SPIKEs. Mitigation: isolate in thin FFI; build the spike first; treat application as best-effort + mandatory verification with honest PARTIAL/FAILED reporting; do not assert atomicity.
**R4 — Sony TV lifecycle behavior unknown.** Whether it stays enumerated when off, and whether it re-registers with a stable path on power-on, is unobserved. Mitigation: known/connected/active state model tied to observed behavior; never claim full restore when a display is missing.
**R5 — GPU driver differences.** Prefer Windows APIs; avoid vendor-specific APIs in V1; test primarily against AMD hardware initially.

## 23. V1 Definition of Done
Given Monitor A, Monitor B, Sony TV, the user can:
1. Configure Work in Windows.
2. Save it as `Work`.
3. Configure Gaming in Windows.
4. Save it as `Gaming`.
5. Press the Gaming hotkey → TV becomes active while monitors are disabled.
6. Press the Work hotkey → monitors become active while the TV is disabled.

This must continue to work when Windows changes transient display enumeration, because identity is evidence-based (re-resolved against current hardware) and profiles persist stable evidence keys — not runtime handles or `\\.\DISPLAYn`.

Primary success criterion: **a resolver that answers "Is this currently detected Windows display the same display represented by this profile entry?" with UNIQUE / AMBIGUOUS / UNKNOWN, robust across normal Windows display lifecycle events.**
