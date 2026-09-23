# Master Plan Review Prompt

You are reviewing a proposed technical master plan for a native Windows display-profile manager written in Rust.

The baseline plan is provided in:

`MASTER_PLAN.md`

Your task is NOT to blindly expand the document.

Your job is to critically evaluate it, identify incorrect assumptions, missing technical requirements, unnecessary complexity, architectural weaknesses, and implementation risks, then produce an improved V1 master plan.

## Project Context

The application is intended for a Windows desktop PC with multiple physical displays.

Initial use case:

WORK:
- Monitor 1: ON
- Monitor 2: ON
- TV: OFF

GAMING:
- Monitor 1: OFF
- Monitor 2: OFF
- TV: ON

The motivation is that tools such as MultiMonitorTool can work for this use case but may rely on monitor identifiers that can change after Windows, GPU driver, hotplug, sleep/wake, or other display-topology events.

The desired solution is a native Rust Windows application that:

1. Discovers physical displays.
2. Identifies them robustly.
3. Captures Windows display configurations.
4. Saves named profiles.
5. Restores profiles.
6. Resolves physical displays even when Windows enumeration changes.
7. Verifies that the requested configuration was actually applied.
8. Provides a lightweight tray UI and hotkeys.

The first version should remain focused and should not become an unnecessarily large desktop-management application.

## Critical Review Requirements

### 1. Validate the Windows API assumptions

Investigate whether the proposed APIs are actually sufficient and appropriate:

- QueryDisplayConfig
- SetDisplayConfig
- DisplayConfigGetDeviceInfo
- EnumDisplayDevices
- EnumDisplaySettingsEx
- RegisterHotKey
- Shell_NotifyIcon

Determine:

- Which APIs are authoritative for modern Windows display configuration.
- Which are legacy.
- Which APIs are actually necessary.
- Whether the proposed combination can reliably capture and restore topology.
- Whether important Windows APIs are missing.
- Whether any proposed API should be removed.

Do not assume the baseline plan is technically correct.

### 2. Investigate display identity deeply

Determine the most reliable way to identify a physical display on Windows.

Analyze:

- EDID
- EDID-derived identifiers
- Manufacturer
- Product code
- Serial number
- DisplayConfig target identifiers
- Adapter identifiers
- Device instance paths
- Windows monitor device names
- PnP identifiers
- DisplayPort/HDMI topology
- Identical monitors
- TVs with incomplete EDID
- Missing serial numbers
- Duplicate model/serial information

Determine whether EDID should actually be the primary identity mechanism.

If there is a better Windows-native identity mechanism, explain it and modify the architecture.

The system must handle two physically identical monitors. Do not assume every monitor has a unique serial number.

### 3. Validate profile persistence

Determine what should actually be persisted in a profile.

Evaluate:

- Logical application-level representation
- Raw Windows DISPLAYCONFIG structures
- Hybrid representation

Consider:

- Windows updates
- GPU driver updates
- Display replacement
- Resolution changes
- Refresh-rate changes
- HDR
- Orientation
- Scaling
- Primary display
- Topology
- Disconnected displays
- Identical monitors

The persisted format must remain useful after routine system changes.

### 4. Validate SetDisplayConfig usage

Analyze how a robust implementation should construct and apply configurations using SetDisplayConfig.

Determine:

- Whether profiles should reconstruct paths and modes.
- Whether raw captured configuration can be reused.
- Which identifiers are safe to persist.
- How disabled displays should be represented.
- How topology should be represented.
- What flags should be used.
- How validation should occur.
- What failure modes exist.
- Whether partial application is possible.
- Whether fallback strategies are necessary.

Provide a technically realistic application flow.

### 5. Investigate hotplug and powered-off TVs

Analyze behavior when:

- TV is on
- TV is off
- HDMI is connected
- HDMI is disconnected
- PC wakes from sleep
- TV wakes after PC
- TV is detected late
- GPU driver restarts

Determine how the application should represent:

- Known display
- Connected display
- Active display
- Available display

### 6. Analyze failure and recovery

Critically evaluate:

- SUCCESS
- PARTIAL
- FAILED

Design behavior for:

- Missing displays
- Ambiguous display identity
- Unsupported mode
- Invalid topology
- SetDisplayConfig failure
- Driver rejection
- Display becoming unavailable during application
- Windows changing configuration afterward

Determine when the application should retry, fallback, partially apply, abort, or ask the user.

Keep V1 practical.

### 7. Analyze atomicity and user experience

Determine whether switching profiles can realistically be treated as atomic.

Consider:

- Screen flickering
- Window rearrangement
- Temporary black screens
- Resolution changes
- Refresh-rate changes
- Primary-display changes

Identify whether window-position management belongs in V1. Do not add it without strong technical justification.

### 8. Evaluate the Rust architecture

Review:

- `windows-rs`
- Tray integration
- GUI framework choice
- Native Win32 UI
- Error handling
- Serialization
- Logging
- Testing
- Windows-specific abstraction boundaries

Keep dependencies minimal.

### 9. Improve the repository structure

Simplify or expand the proposed repository structure where appropriate.

The architecture should make it easy to:

- Unit-test profile logic
- Test identity resolution
- Integration-test Windows display operations
- Isolate unsafe/FFI code
- Evolve later

Avoid premature abstraction.

### 10. Improve development phases

Review the phase ordering.

Do not start with UI.

Prove:

1. Windows display discovery
2. Physical identity
3. Configuration capture
4. Configuration restoration
5. Verification/recovery
6. Tray UI
7. Hotkeys

Identify missing technical spikes.

### 11. Define measurable acceptance tests

Add concrete tests.

Example:

Given:

```text
DISPLAY1 → Monitor A
DISPLAY2 → Monitor B
DISPLAY3 → TV
```

and later:

```text
DISPLAY1 → TV
DISPLAY2 → Monitor B
DISPLAY3 → Monitor A
```

the resolver must still identify the same physical displays.

Test:

- Work → Gaming → Work
- TV unavailable
- Identical monitors
- Ambiguous identity
- Unsupported display mode
- Sleep/wake
- Hotplug

### 12. Identify false assumptions

Explicitly list questionable assumptions using:

```text
ASSUMPTION
Why it may be wrong
Evidence / Windows behavior
Corrected approach
```

Do not preserve assumptions simply because they appear in the baseline plan.

### 13. Avoid unnecessary scope

Do not turn V1 into:

- A complete display-management suite
- A game launcher
- A window manager
- An audio manager
- An HDR manager
- A GPU control panel
- A cross-platform application

Only add functionality required for core reliability.

## Research Expectations

Use authoritative and technically reliable sources.

Prioritize:

1. Microsoft Windows documentation
2. Official Rust/windows-rs documentation
3. Windows SDK documentation
4. Relevant source code from established open-source Windows utilities
5. High-quality technical discussions where primary documentation is insufficient

Clearly distinguish:

- Documented behavior
- Observed behavior
- Implementation inference
- Uncertain behavior

If an important technical question cannot be established confidently, identify it as an implementation spike instead of inventing certainty.

## Deliverables

### A. Executive assessment

Briefly explain:

- What is correct.
- What is questionable.
- What must change.

### B. Critical findings

Categorize:

- BLOCKER
- HIGH
- MEDIUM
- LOW

Do not create findings artificially.

### C. Corrected architecture

Provide the revised architecture.

### D. Corrected identity strategy

Provide the recommended physical-display identity strategy and fallback behavior.

### E. Corrected profile model

Provide the recommended conceptual profile representation.

### F. Corrected Windows API strategy

Specify the APIs and how they interact.

### G. Corrected implementation phases

Provide implementation sequence with explicit gates.

### H. V1 acceptance criteria

Provide measurable acceptance tests.

### I. Updated MASTER_PLAN.md

Finally, produce a complete revised version of `MASTER_PLAN.md`.

The revised document must stand alone and must not require reading the original plan.

## Important Constraints

Do not assume the original plan is correct.

Do not optimize for document length.

Do not introduce unnecessary abstractions.

Do not build the UI before proving the Windows display-management core.

Do not use transient display numbering as physical identity.

Do not assume EDID serial numbers are always present or unique.

Do not claim SetDisplayConfig is atomic unless technically justified.

Do not invent Windows API behavior.

If an implementation detail is uncertain, mark it as an explicit spike or validation task.

The goal is a technically defensible V1 master plan that can be handed directly to an implementation agent.
