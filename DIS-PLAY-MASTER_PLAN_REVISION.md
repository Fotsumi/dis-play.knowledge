# Native Windows Display Profile Manager — Master Plan (Revised)

This document stands alone. It is the corrected V1 master plan for a native Windows display-profile manager written in Rust. It supersedes the baseline plan; it does not require reading the original.

## 1. Project Overview

Build a lightweight native Windows application in Rust for managing and switching between saved display configurations on a PC with multiple displays.

Primary use case:
- **Work:** Monitor 1 ON, Monitor 2 ON, TV OFF
- **Gaming:** Monitor 1 OFF, Monitor 2 OFF, TV ON

The application must NOT rely on volatile Windows display identifiers such as `\\.\DISPLAY1`, `DISPLAY2`, `DISPLAY3` (or equivalent transient identifiers from third-party tools). It identifies physical displays using stable hardware characteristics and applies complete Windows display configurations through the native Display Config API.

## 2. Primary Objectives

1. Discover all displays currently visible to Windows.
2. Identify physical displays reliably via a persistent, layered identity.
3. Capture the current Windows display configuration.
4. Save configurations as named profiles.
5. Restore profiles reliably (re-resolved against current hardware).
6. Detect when Windows has changed display enumeration / topology.
7. Resolve profiles against currently detected physical displays.
8. Verify that a requested configuration was actually applied.
9. Provide fast profile switching through a system tray application.
10. Support global keyboard shortcuts.
11. Remain lightweight and native to Windows.

## 3. Non-Goals for V1

V1 does NOT implement: game detection, per-game automatic profiles, cloud/multi-PC sync, remote control, GPU-vendor-specific APIs, display calibration, color management, HDR management, audio-device switching, fancy UI, Windows service architecture, or cross-platform support. These may be evaluated after the core display-profile system is stable.

## 4. Core Design Principles

### 4.1 Persistent physical identity over Windows enumeration
Do not use `\\.\DISPLAYn`, MultiMonitorTool monitor IDs, or transient enumeration indexes as persistent identity. Use a layered identity strategy with defined precedence:

1. **Primary — PnP device instance path / hardware ID** (stable per physical port; changes only on genuine rewiring).
2. **Secondary — EDID-derived identity** (manufacturer + product code + serial *when present*) to disambiguate identical monitors and cross-check.
3. **Tertiary — topology position** (which GPU output / physical port), used explicitly for identical devices or missing EDID, always with an ambiguity flag when it is the only distinguishing signal.

Do NOT assume every display provides a useful serial number, and do NOT make EDID the primary key: serials are frequently absent (TVs especially), there is no clean public API to read raw EDID bytes for an arbitrary display, and two identical monitors share one EDID. The application must tolerate Windows changing enumeration order.

### 4.2 Profiles represent desired complete configurations
The abstraction is `Apply "Gaming"`, not individual enable/disable commands. A profile represents the desired display topology and relevant display modes.

### 4.3 Capture before manually defining
Preferred workflow: configure displays normally in Windows → open the app → capture current configuration → save as a named profile.

## 5. Technology

- **Language:** Rust, target `x86_64-pc-windows-msvc` (ARM64 later).
- **Bindings:** `windows-rs` for Win32 FFI.
- **Authoritative display APIs (dxva2.h):** `QueryDisplayConfig` (read source/target/mode), `SetDisplayConfig` (apply path+mode; attach/detach targets to change topology). These are the modern, authoritative surfaces — not legacy GDI.
- **Identity APIs:** `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces` (or WMI `Win32_PnPEntity`) for persistent PnP instance paths and hardware IDs; EDID fields via a confirmed read path (**SPIKE**).
- **Change detection:** `RegisterDeviceNotification` / `WM_DEVICECHANGE`, or lazy re-resolution on apply.
- **Supplementary only (legacy GDI, do NOT build identity/capture on):** `EnumDisplayDevices`, `EnumDisplaySettingsEx`, `DisplayConfigGetDeviceInfo`.
- **UI/UX:** `RegisterHotKey` for global shortcuts; `Shell_NotifyIcon` + a Win32 message loop for the tray.

The exact API surface and flags must be validated during the Phase 0 spike before implementation depends on them.

## 6. Architecture

Keep three layers with a crisp boundary between *pure logic* and *Windows FFI*, so identity/resolver/profile logic is unit-testable on any OS without live Windows calls:

```
UI Layer            tray / menu / notifications   (thin Win32, late in build order)
                        │
Application Core    profile manager · display resolver · capture/apply orchestration
                        │        pure Rust: operates on a DiscoveredDisplay model, no FFI
                        ▼
Windows Integration  display_config.rs (Query/Set DisplayConfig)
                      identity.rs   (PnP instance path + EDID fields via SetupDi*/WMI)
                      hotkeys.rs    (RegisterHotKey)
                      tray.rs       (Shell_NotifyIcon / message loop)
```

Rules:
- **Pure-Rust core** (`display/`, `profile/`) takes a *discovered display model* as input and emits identity, resolution decisions, and profile I/O. No Win32 calls inside — testable with fixtures/mocks on any OS.
- **Thin FFI layer** (`windows/`) is the only place touching `dxva2.h`, `setupapi`, `user32`. It produces the discovered model and applies results; it does not own policy.

## 7. Repository Structure

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
│   │   ├── display.rs    # Display / DiscoveredDisplay model
│   │   └── profile.rs    # DisplayProfile + per-display entry (identity+mode)
│   ├── core/            # pure Rust policy: identity, resolution, capture/apply orchestration
│   │   ├── mod.rs
│   │   ├── identity.rs   # layered identity + ambiguity handling
│   │   ├── resolver.rs   # profile → current displays mapping
│   │   └── verify.rs     # desired-vs-actual comparison
│   ├── windows/         # thin FFI only (the sole place touching Win32)
│   │   ├── mod.rs
│   │   ├── display_config.rs  # Query/Set DisplayConfig, mode sets
│   │   ├── identity_source.rs # SetupDi*/WMI PnP paths + EDID fields
│   │   ├── hotkeys.rs         # RegisterHotKey
│   │   └── tray.rs            # Shell_NotifyIcon / message loop
│   └── ui/
│       ├── mod.rs
│       └── tray_menu.rs
└── tests/               # pure-logic unit tests (any OS) + Windows integration harness
    ├── identity.rs
    ├── resolver.rs
    └── verify.rs
```

The structure is provisional; adjust if implementation evidence suggests a simpler split. The invariant: **`core/` and `model/` never call Win32**, so the critical subsystems are testable in CI without hardware.

## 8. Display Discovery Model

Internal model (fields derived from what Windows reliably exposes):

```rust
struct Display {
    identity: DisplayIdentity,   // layered key (see §9) — NOT a transient name
    pnp_instance_path: String,  // primary stable key
    edid: Option<EdidInfo>,      // manufacturer/product/serial when present
    topology_position: TopologyPosition, // GPU output / port; last-resort signal
    connected: bool,             // currently enumerated
    active: bool,                // has an applied mode (attached to a source)
    mode: Option<DisplayMode>,   // resolution/refresh/orientation when active
    primary: bool,
}

struct DisplayIdentity { /* layered key with precedence + ambiguity flag */ }
```

## 9. Display Identity Strategy

Layered identity with defined precedence and explicit ambiguity handling (do NOT assume EDID serials are present or unique):

1. **Primary — PnP device instance path / hardware ID.** Each monitor is a PnP "Monitor" class device (child of the GPU adapter node); its instance path encodes physical port/topology and is stable across reboots, driver updates, and enumeration-order changes; it only changes on genuine rewiring. Obtain via `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces`, or WMI `Win32_PnPEntity`. *(SPIKE: confirm exact instance-path format and stability across a GPU driver update on target hardware.)*
2. **Secondary — EDID-derived identity** (manufacturer + product code + serial *when present*). Disambiguates two identical monitors; cross-checks primary. Read path for parsed EDID data must be confirmed before use. *(SPIKE: confirm where Windows stores the parsed EDID block per monitor device — registry location / WMI.)*
3. **Tertiary — topology position** (which GPU output / physical port). First-class, used explicitly for identical devices or missing EDID; always flagged ambiguous when it is the only distinguishing signal.

Resolution outcome per display: `UNIQUE` / `AMBIGUOUS` / `UNKNOWN`. Ambiguity is surfaced, never silently resolved. The identity resolver is a critical subsystem and has dedicated tests (reorder, identical monitors, missing serial).

## 10. Display Modes & Profile Persistence

A display configuration may contain: enabled/disabled state, resolution, refresh rate, position/offset, primary flag, orientation, and the topology/path information Windows requires to restore it.

Persist a **logical model** (hybrid), re-resolved at apply time — NOT raw `DISPLAYCONFIG` blob reuse:
- Per display entry: `identity` (PnP instance path + EDID fields when available) + `desired_mode` (resolution, refresh, orientation, primary flag, position/offset) + `topology_role` (active vs disabled; a "disabled" display is one whose target is not attached to an active source path).
- **Never** persist transient names (`\\.\DISPLAYn`) as identity. A last-seen DisplayConfig target name/handle may be cached for fast-path matching only, and must be re-derived from stable identity before use.
- Re-resolution against current hardware is mandatory so profiles survive driver updates / reboots / topology change.

The persisted schema is designed after the Phase 0 spike confirms which fields Windows reliably exposes; do not invent an abstraction that cannot faithfully restore the configuration.

## 11. Profiles

Conceptually:

```rust
struct DisplayProfile {
    name: String,
    displays: Vec<DisplayConfiguration>, // each keyed by stable identity + desired mode + topology_role
}
```

A profile identifies displays by stable physical identity (see §9). The concrete schema is finalized after the Windows API spike.

## 12. Capture Workflow — `capture_current()`

```text
Windows current configuration
          ↓ QueryDisplayConfig (authoritative read)
Resolve physical displays (layered identity, §9)
Build application model (§8/§10)
Serialize profile (JSON)
```

## 13. Profile Application — `apply_profile()`

Application is **best-effort + mandatory verification**, not atomic: a full topology change spans multiple displays/adapters and can partially fail.

```text
Load profile
      ↓
Discover current displays
      ↓
Resolve physical identities (UNIQUE/AMBIGUOUS/UNKNOWN)
Map profile → current Windows displays
Validate (no silent assignment of AMBIGUOUS; unsupported mode → FAILED)
Construct Windows display configuration (path+mode per display; detach target for "off")
SetDisplayConfig()          # best-effort, not transactional
Query resulting configuration
Verify (desired vs actual)  # mandatory
```

## 14. Partial / Missing Displays & State Model

A profile may reference a display that is currently unavailable. Distinguish:
- **known** — referenced by the profile
- **connected** — currently enumerated
- **active** — has an applied mode (attached to a source)

A powered-off HDMI TV may be absent from enumeration entirely; do not assume it is visible. For V1 use best-effort where practical: apply the available configuration, report missing displays, and never silently claim full restoration.

## 15. Verification & Recovery

After applying a profile, query the resulting configuration again and compare desired vs actual. Outcome states:
- **SUCCESS** — requested topology achieved
- **PARTIAL** — subset applied; some displays missing/unresolved
- **FAILED** — could not apply (e.g., unsupported mode, driver rejection)
- **AMBIGUOUS** — identity cannot be uniquely resolved

Behavior rules: no auto-retry loops in V1; report clearly; never claim full restore when a display is missing. Define retry/fallback/abort for: missing displays, ambiguous identity, unsupported mode, invalid topology, `SetDisplayConfig` failure, driver rejection, display becoming unavailable during application, and Windows changing configuration afterward.

## 16. System Tray UI

Keep minimal (native Win32; real message-loop work — budget accordingly):

```text
Display Profiles

● Work
  Gaming

──────────────

Save Current Configuration...
Manage Profiles...

──────────────

Settings
Exit
```

No fancy UI in V1.

## 17. Hotkeys

Initial shortcuts (native `RegisterHotKey`):
- `Ctrl + Alt + W` → Work
- `Ctrl + Alt + G` → Gaming

Configurable per profile.

## 18. Notifications

Successful switch, partial switch, and failure produce clear notifications without being intrusive.

## 19. Startup & Privileges

Optional setting: `Start with Windows`. The application should preferably run without administrator privileges — this must be tested (some display operations may require elevation; confirm in the spike).

## 20. MVP Scope

V1 includes:
- Display discovery
- Stable physical display identification (PnP primary, EDID secondary, topology last-resort)
- Current configuration capture
- Profile persistence (JSON, logical model re-resolved at apply)
- Profile resolution
- Profile application via `SetDisplayConfig` (best-effort + verify)
- Configuration verification (SUCCESS/PARTIAL/FAILED/AMBIGUOUS)
- Basic missing-display handling with explicit state model
- System tray
- Global hotkeys
- JSON-based local storage
- Basic error reporting

V1 excludes: automatic game detection, per-game profiles, cloud/multi-PC sync, remote control, audio switching, HDR management, color management, display calibration, vendor-specific GPU APIs, cross-platform support.

## 21. Development Phases (with gates)

Prove the Windows core before any UI. Add the missing spikes.

**Phase 0 — Windows API spike (CLI).** Prove Windows exposes enough to enumerate displays, read modes, and obtain a *persistent* identity per display. Sub-spikes: PnP instance-path stability across driver update; EDID field availability/location; `SetDisplayConfig` attach/detach + exact flags/sequence; "primary" selection mechanism; powered-off-TV visibility; privilege requirements. **Gate:** every physical display can be distinguished by a stable key, and modes are readable.

**Phase 1 — Identity & resolver (pure Rust).** Implement `DisplayIdentity`, layered resolution, ambiguity handling. Dedicated tests: reorder, identical monitors, missing serial. **Gate:** enumeration changes do not change physical identity; ambiguous cases surface as AMBIGUOUS.

**Phase 2 — Capture + persistence.** `capture_current()` → logical profile model → JSON round-trip. **Gate:** captured config serializes and re-resolves equivalently against current hardware.

**Phase 3 — Apply (`apply_profile`).** Build path+mode, detach for disabled, apply via `SetDisplayConfig`, then verify. Tests: Work→Gaming→Work; TV disconnected; monitor disconnected; TV powered off; display order changed; resolution manually changed. **Gate:** profiles reliably switch topology and verification reports the true outcome.

**Phase 4 — Verification & recovery.** Desired-vs-actual comparison → SUCCESS/PARTIAL/FAILED (+ AMBIGUOUS). Define retry/fallback/abort behavior (no silent full-restore claims). **Gate:** app can state whether the requested profile was achieved.

**Phase 5 — Tray application.** Minimal tray, profiles list, capture action, notifications, optional startup. Keep thin; no fancy UI.

**Phase 6 — Hotkeys.** Configurable global shortcuts (`Ctrl+Alt+W` / `Ctrl+Alt+G`).

**Phase 7 — Hardening.** Reboot, sleep/wake, HDMI/DP hotplug, TV power off/on, GPU driver updates, Windows updates, refresh-rate changes, resolution changes, HDR state changes, scaling changes, multiple identical monitors, missing displays, reordered displays.

## 22. Future Extensions

Potential later functionality: automatic game detection, per-game profiles, multiple gaming configurations, audio switching (audio remains a separate subsystem).

## 23. Technical Risks

**R1 — EDID reliability.** Not all displays expose complete or unique EDID information. Mitigation: layered identity with PnP primary; multiple identity signals; explicit ambiguity handling. *(Do not rely on EDID as the sole key.)*

**R2 — `SetDisplayConfig` complexity / non-atomicity.** A topology change is a sequence of operations that can partially fail. Mitigation: isolate Windows implementation in a thin FFI layer; build the API spike first; avoid UI work until configuration switching works; treat application as best-effort + mandatory verification with honest PARTIAL/FAILED reporting.

**R3 — GPU driver differences.** Prefer Windows APIs; avoid vendor-specific APIs in V1; test primarily against AMD hardware initially.

**R4 — TV hotplug behavior.** A powered-off HDMI TV may disappear from Windows. Mitigation: explicit known/connected/active state model; distinguish known display, connected display, and active display.

## 24. V1 Definition of Done

Given Monitor A, Monitor B, Sony TV, the user can:
1. Configure Work in Windows.
2. Save it as `Work`.
3. Configure Gaming in Windows.
4. Save it as `Gaming`.
5. Press the Gaming hotkey → TV becomes active while monitors are disabled.
6. Press the Work hotkey → monitors become active while the TV is disabled.

This must continue to work when Windows changes transient display enumeration, because identity is persistent (PnP primary) and profiles are re-resolved against current hardware.

Primary success criterion: **reliable profile switching based on physical display identity rather than transient display IDs.**
