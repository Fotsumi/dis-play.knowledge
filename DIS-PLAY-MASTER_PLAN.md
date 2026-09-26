# Native Windows Display Profile Manager — Master Plan

## 1. Project Overview

Build a lightweight native Windows application in Rust for managing and switching between saved display configurations.

The primary use case is a PC with multiple displays:

### Work
- Monitor 1: ON
- Monitor 2: ON
- TV: OFF

### Gaming
- Monitor 1: OFF
- Monitor 2: OFF
- TV: ON

The application must avoid relying on volatile Windows display identifiers such as `DISPLAY1`, `DISPLAY2`, `DISPLAY3`, or equivalent transient identifiers exposed by third-party utilities.

Instead, it should identify physical displays using stable hardware characteristics, preferably EDID-derived identity, and apply complete Windows display configurations through the native Windows Display Configuration API.

## 2. Primary Objectives

1. Discover all displays currently visible to Windows.
2. Identify physical displays reliably.
3. Capture the current Windows display configuration.
4. Save configurations as named profiles.
5. Restore profiles reliably.
6. Detect when Windows has changed display enumeration.
7. Resolve profiles against currently detected physical displays.
8. Verify that a requested configuration was actually applied.
9. Provide fast profile switching through a system tray application.
10. Support global keyboard shortcuts.
11. Remain lightweight and native to Windows.

## 3. Non-Goals for V1

The first version should NOT attempt to implement:

- Game detection
- Per-game automatic profiles
- Cloud synchronization
- Multi-PC synchronization
- Remote control
- GPU-vendor-specific APIs
- Display calibration
- Color management
- HDR management
- Audio-device switching
- Fancy UI
- Windows service architecture
- Cross-platform support

These can be evaluated after the core display-profile system is stable.

## 4. Core Design Principles

### 4.1 Physical identity over Windows enumeration

Do not use `DISPLAY1`, `DISPLAY2`, `DISPLAY3`, MultiMonitorTool monitor IDs, or other transient enumeration indexes as persistent display identity.

Instead use a layered identity strategy based on information such as:

- EDID
- Manufacturer
- Product code
- Serial number
- Device instance/path
- Other stable Windows device information

The application should tolerate Windows changing display enumeration order.

### 4.2 Profiles represent desired complete configurations

The primary abstraction is:

`Apply "Gaming"`

rather than individual enable/disable commands.

A profile represents the desired display topology and relevant display modes.

### 4.3 Capture before manually defining

Preferred workflow:

1. Configure displays normally using Windows.
2. Open the application.
3. Capture the current configuration.
4. Save it as a profile.

## 5. Technology

### Language

Rust.

Target:

`x86_64-pc-windows-msvc`

ARM64 may be considered later.

### Windows bindings

Use `windows-rs`.

Relevant APIs should include, where appropriate:

- `QueryDisplayConfig()`
- `SetDisplayConfig()`
- `DisplayConfigGetDeviceInfo()`
- `EnumDisplayDevices()`
- `EnumDisplaySettingsEx()`
- `RegisterHotKey()`
- `Shell_NotifyIcon()`

The exact API surface must be validated during the Windows API spike.

## 6. Architecture

```text
┌──────────────────────────────────────────────┐
│                  UI Layer                    │
│                                              │
│ Tray │ Profiles │ Settings │ Notifications  │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│              Application Core                │
│                                              │
│ Profile Manager                              │
│ Display Resolver                             │
│ Configuration Manager                        │
│ Validation / Recovery                        │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│            Windows Integration               │
│                                              │
│ Display Configuration API                    │
│ EDID / Device Identification                 │
│ Global Hotkeys                               │
│ System Tray                                  │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
                  Windows GPU
                       │
              ┌────────┼────────┐
              ▼        ▼        ▼
           Monitor 1 Monitor 2  TV
```

Windows-specific implementation details should remain isolated from application/profile logic.

## 7. Proposed Repository Structure

```text
display-switcher/
├── Cargo.toml
├── Cargo.lock
├── README.md
├── LICENSE
├── docs/
│   ├── architecture.md
│   ├── display-identification.md
│   ├── windows-api.md
│   └── profiles.md
├── src/
│   ├── main.rs
│   ├── app.rs
│   ├── error.rs
│   ├── display/
│   │   ├── mod.rs
│   │   ├── model.rs
│   │   ├── identity.rs
│   │   ├── discovery.rs
│   │   └── resolver.rs
│   ├── profile/
│   │   ├── mod.rs
│   │   ├── model.rs
│   │   ├── manager.rs
│   │   ├── storage.rs
│   │   └── validator.rs
│   ├── windows/
│   │   ├── mod.rs
│   │   ├── display_config.rs
│   │   ├── edid.rs
│   │   ├── hotkeys.rs
│   │   └── tray.rs
│   └── ui/
│       ├── mod.rs
│       ├── tray.rs
│       └── settings.rs
└── tests/
    ├── identity.rs
    ├── profiles.rs
    └── resolver.rs
```

The structure is provisional and should be adjusted if implementation evidence suggests a simpler architecture.

## 8. Display Discovery

The application should expose an internal display model similar to:

```rust
struct Display {
    id: DisplayId,
    identity: DisplayIdentity,
    name: String,
    connected: bool,
    active: bool,
    mode: Option<DisplayMode>,
    position: Position,
    primary: bool,
}
```

The actual fields must be derived from what Windows reliably exposes.

## 9. Display Identity

Use a layered identity strategy.

Preferred information:

1. EDID + serial
2. EDID + manufacturer/product information
3. Windows device instance/path
4. Other reliable fallback information

Do not assume every display provides a useful serial number.

The identity system must handle:

- Missing serial numbers
- Duplicate model names
- Multiple identical monitors
- Displays being disconnected
- Displays being reconnected
- Enumeration order changing

The identity resolver is a critical subsystem and must have dedicated tests.

## 10. Display Modes

A display configuration may contain:

- Enabled/disabled state
- Resolution
- Refresh rate
- Position
- Primary state
- Orientation
- Relevant topology/path information
- Other properties required by Windows to restore the configuration

The exact persisted representation must be based on the Windows Display Configuration API rather than inventing an abstraction that cannot faithfully restore the configuration.

## 11. Profiles

Conceptually:

```rust
struct DisplayProfile {
    name: String,
    displays: Vec<DisplayConfiguration>,
}
```

A profile should identify displays by stable physical identity.

The actual schema should be designed after the Windows API spike.

## 12. Capture Workflow

Implement:

`capture_current()`

Workflow:

```text
Windows current configuration
          ↓
QueryDisplayConfig
          ↓
Resolve physical displays
          ↓
Build application model
          ↓
Serialize profile
```

## 13. Profile Application

Application flow:

```text
Load profile
      ↓
Discover current displays
      ↓
Resolve physical identities
      ↓
Map profile → current Windows displays
      ↓
Validate
      ↓
Construct Windows display configuration
      ↓
SetDisplayConfig()
      ↓
Query resulting configuration
      ↓
Verify
```

The verification step is mandatory.

## 14. Partial / Missing Displays

A profile may reference a display that is currently unavailable.

The application should distinguish:

- Exact match
- Partial match
- No match

For V1, use a best-effort approach where practical:

- Apply available configuration.
- Report missing displays.
- Never silently claim full restoration.

## 15. Verification

After applying a profile, query the resulting configuration again.

Compare desired versus actual configuration.

Possible result:

- SUCCESS
- PARTIAL
- FAILED

## 16. System Tray UI

Keep the initial UI minimal:

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

## 17. Hotkeys

Initial shortcuts:

- `Ctrl + Alt + W` → Work
- `Ctrl + Alt + G` → Gaming

Use native Windows global hotkey registration.

## 18. Notifications

Successful switch, partial switch, and failure should produce clear notifications without being intrusive.

## 19. Startup

Optional setting:

`Start with Windows`

The application should preferably run without administrator privileges. This must be tested.

## 20. MVP Scope

V1 must include:

- Display discovery
- Stable physical display identification
- EDID/device identity
- Current configuration capture
- Profile persistence
- Profile resolution
- Profile application
- Configuration verification
- Basic missing-display handling
- System tray
- Global hotkeys
- JSON-based local storage
- Basic error reporting

V1 should exclude:

- Automatic game detection
- Per-game profiles
- Cloud sync
- Multi-PC sync
- Remote control
- Audio switching
- HDR management
- Color management
- Display calibration
- Vendor-specific GPU APIs
- Cross-platform support

## 21. Development Phases

### Phase 0 — Windows API Spike

Build a CLI:

```text
dis-play list
dis-play identify
dis-play dump
```

Goal: prove Windows exposes enough information.

Gate: all physical displays can be reliably distinguished.

### Phase 1 — Display Discovery

Implement:

- `DisplayDiscovery`
- `DisplayIdentity`
- `DisplayResolver`

Gate: enumeration changes do not change physical identity.

### Phase 2 — Configuration Capture

Implement `capture_current()` and profile persistence.

Gate: captured configurations can be serialized and represented equivalently.

### Phase 3 — Configuration Application

Implement `apply_profile()`.

Test:

- Work → Gaming
- Gaming → Work
- Work → Gaming → Work
- TV disconnected
- Monitor disconnected
- TV powered off
- Display order changed
- Resolution manually changed

Gate: profiles reliably switch topology.

### Phase 4 — Verification and Recovery

Implement desired-vs-actual comparison and clear success/partial/failure states.

Gate: application can determine whether the requested profile was achieved.

### Phase 5 — Tray Application

Add tray, profiles, capture action, notifications, startup option.

### Phase 6 — Hotkeys

Add configurable global profile-switching shortcuts.

### Phase 7 — Hardening

Test:

- Reboot
- Sleep/wake
- HDMI hotplug
- DisplayPort hotplug
- TV powered off/on
- GPU driver updates
- Windows updates
- Refresh-rate changes
- Resolution changes
- HDR state changes
- Scaling changes
- Multiple identical monitors
- Missing displays
- Reordered displays

## 22. Future Extensions

Potential later functionality:

- Automatic game detection
- Per-game profiles
- Multiple gaming configurations
- Audio switching

Audio should remain a separate subsystem.

## 23. Technical Risks

### R1 — EDID reliability

Not all displays expose complete or unique EDID information.

Mitigation:

- Layered identity
- Multiple identity signals
- Explicit ambiguity handling

### R2 — SetDisplayConfig complexity

Mitigation:

- Isolate Windows implementation
- Build API spike first
- Avoid UI work until configuration switching works

### R3 — GPU driver differences

Mitigation:

- Prefer Windows APIs
- Avoid vendor-specific APIs in V1
- Test primarily against AMD hardware initially

### R4 — TV hotplug behavior

A powered-off HDMI TV may disappear from Windows.

Mitigation:

Distinguish:

- Known display
- Connected display
- Active display

## 24. V1 Definition of Done

Given:

- Monitor A
- Monitor B
- Sony TV

the user can:

1. Configure Work in Windows.
2. Save it as `Work`.
3. Configure Gaming in Windows.
4. Save it as `Gaming`.
5. Press the Gaming hotkey.
6. Have the TV become active while monitors are disabled.
7. Press the Work hotkey.
8. Have the monitors become active while the TV is disabled.

This must continue to work when Windows changes transient display enumeration.

Primary success criterion:

> Reliable profile switching based on physical display identity rather than transient display IDs.
