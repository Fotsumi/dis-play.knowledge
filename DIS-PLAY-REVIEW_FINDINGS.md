# DIS-PLAY Master Plan — Review Findings & Corrected Design

Review of `DIS-PLAY-MASTER_PLAN.md` (the baseline plan). This document is the critical review: it states what is correct, what is questionable, and what must change, then gives the corrected design. The clean standalone result lives in `DIS-PLAY-MASTER_PLAN_REVISION.md`.

Method note: I evaluated the plan against how Windows actually exposes display configuration and identity. Where a specific API detail (exact prototype/flags, EDID read path, "primary" selection) cannot be stated with confidence from public documentation alone, it is marked **SPIKE** rather than asserted — per the review's own rule not to invent Windows behavior.

---

## A. Executive Assessment

### What is correct
- The core problem framing is right: transient identifiers (`\\.\DISPLAY1`, `DISPLAY2`, …) must NOT be used as persistent identity, and profiles must be re-resolved against current hardware at apply time.
- Using the **Display Config API** (`QueryDisplayConfig` / `SetDisplayConfig`) as the apply/query path is the right family — it is the modern, authoritative surface for topology + mode changes.
- The "capture before manually defining" workflow and profile-as-desired-complete-configuration model are sound.
- Mandatory post-apply verification (desired vs actual) is correct and should stay.
- Keeping V1 scope tight (no game detection, no audio, no HDR, no cross-platform) is right.

### What is questionable
- **EDID as the *primary* identity mechanism.** This is inverted from what Windows reliably exposes. EDID serials are frequently absent (TVs especially), there is no clean public API to read raw EDID bytes for an arbitrary display, and two physically identical monitors share one EDID — so EDID cannot be the primary key. It should be a *secondary* disambiguator.
- **`EnumDisplayDevices` / `EnumDisplaySettingsEx` listed as core APIs.** These are legacy GDI surfaces; they enumerate transient logical names and per-name modes. They are not authoritative for topology changes and are largely redundant with the Display Config API. Their role should be reduced to optional cross-validation, not identity or capture.
- **No named mechanism for stable physical identity.** The plan's API list contains no way to obtain a *persistent* hardware identity (PnP instance path / device registry properties). That is the single most important missing piece.
- **"Primary display" as if it were directly settable.** How "primary" is selected/changed through `SetDisplayConfig` is not established; it needs a spike, and may be derived from enumeration order rather than a flag.

### What must change
1. **Invert the identity layering:** PnP device instance path (documented, stable) becomes primary; EDID-derived fields become secondary disambiguation; topology/port position becomes an explicit last-resort with ambiguity handling — not "EDID first."
2. **Add the missing identity APIs** to the plan: `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces` (or WMI `Win32_PnPEntity`) for persistent monitor instance paths, plus a spike to confirm where Windows stores parsed EDID data.
3. **Reframe application as best-effort + verify**, not atomic: a full topology change is a sequence of operations that can partially fail; the app must detect partial application and report PARTIAL/FAILED honestly.
4. **Add an explicit display state model** (known / connected / active) to handle powered-off TVs and hotplug, rather than assuming a TV is always visible.
5. **Reorder phases so identity + capture are proven before any UI**, and add the missing technical spikes (EDID read, PnP-path stability, attach/detach via `SetDisplayConfig`, primary selection, off-TV visibility).

---

## B. Critical Findings

| ID | Severity | Finding |
|----|-----------|---------|
| F1 | **HIGH** | EDID is named the *primary* identity mechanism, but Windows does not reliably expose EDID serials (absent on many TVs), has no clean public API to read raw EDID bytes for an arbitrary display, and identical monitors share one EDID. Primary identity must be a persistent PnP device instance path; EDID demoted to secondary disambiguation. |
| F2 | **HIGH** | The plan's API list contains **no mechanism to obtain a persistent physical identity**. `EnumDisplayDevices` yields only transient logical names (`\\.\DISPLAYn`). Missing: `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces` (or WMI) for stable monitor instance paths. Without this, the whole "survive enumeration changes" goal is unmet. |
| F3 | **HIGH** | `SetDisplayConfig` is treated as if applying a profile were atomic/transactional. It is not guaranteed atomic across multiple displays / multi-adapter; a topology change is a sequence of operations that can partially fail. Must be best-effort + mandatory verification, with honest PARTIAL/FAILED reporting. |
| F4 | **MEDIUM** | `EnumDisplayDevices` / `EnumDisplaySettingsEx` are listed as core APIs but are legacy GDI and redundant with the Display Config API for capture. Reduce to optional cross-validation only; do not build identity or capture on them. |
| F5 | **MEDIUM** | No mechanism named for objective 6 ("detect when Windows changed display enumeration"). Needs device-change notification (`RegisterDeviceNotification` / `WM_DEVICECHANGE`) or at minimum lazy re-resolution on apply. |
| F6 | **MEDIUM** | "Primary display" is treated as directly settable via the API. The selection mechanism (flag vs enumeration order) is not established — mark SPIKE; do not assume a simple flag exists. |
| F7 | **MEDIUM** | No explicit state model for powered-off TVs / hotplug. A powered-off HDMI TV may be absent from enumeration entirely. Must distinguish known / connected / active and never claim full restore when a display is missing. |
| F8 | **LOW** | Tray UI effort underestimated: a native Win32 tray + menu in Rust requires a real message loop (`WNDPROC`, `Shell_NotifyIcon`), not a one-liner. Risk of scope creep; keep it minimal and late in the sequence. |
| F9 | **LOW** | Raw captured Display Config structures are implied to be reusable after system changes. They go stale across driver updates / reboots / topology change; profiles must persist a logical model (identity + mode params) that is *re-resolved* against current hardware, not raw blob reuse. |
| F10 | **LOW** | Failure taxonomy lacks an AMBIGUOUS state for "identity cannot be uniquely resolved" (e.g., two identical monitors with no distinguishing signal). Add it and define non-silent behavior. |

---

## C. Corrected Architecture

Keep the three-layer shape but make the boundary between *Windows FFI* and *pure logic* crisp, because that is what makes identity/resolver/profile logic unit-testable on any OS (CI) without live Windows calls.

```
UI Layer            tray.rs / menu / notifications   (thin Win32, late in build order)
                        │
Application Core    profile manager · display resolver · capture/apply orchestration
                        │        (pure Rust: operates on a DiscoveredDisplay model, no FFI)
                        ▼
Windows Integration  display_config.rs (Query/Set DisplayConfig)
                      identity.rs   (PnP instance path + EDID fields via SetupDi*/WMI)
                      hotkeys.rs    (RegisterHotKey)
                      tray.rs       (Shell_NotifyIcon / message loop)
```

Rules:
- **Pure-Rust core** (`display/`, `profile/`) takes a *discovered display model* as input and emits identity, resolution decisions, and profile I/O. No Win32 calls inside — so it is testable with fixtures/mocks on any OS.
- **Thin FFI layer** (`windows/`) is the only place that touches `dxva2.h`, `setupapi`, `user32`. It produces the discovered model and applies results; it does not own policy.
- This inverts the baseline's implicit "Windows details leak into profile logic" risk and makes the resolver (the critical subsystem) directly testable.

---

## D. Corrected Identity Strategy

Layered, with a defined precedence and explicit ambiguity handling. Do **not** assume EDID serials are present or unique.

1. **Primary — PnP device instance path / hardware ID.** Each monitor is a PnP "Monitor" class device (child of the GPU adapter node). Its instance path encodes the physical port/topology and is stable across reboots, driver updates, and enumeration-order changes; it only changes on genuine physical rewiring. Obtain via `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces`, or WMI `Win32_PnPEntity`. *(SPIKE: confirm exact instance-path format and that it is stable across a GPU driver update on the target hardware.)*
2. **Secondary — EDID-derived identity** (manufacturer + product code + serial *when present*). Used to disambiguate two identical monitors and as a cross-check. Read path for parsed EDID data must be confirmed; do not assume it is always populated. *(SPIKE: confirm where Windows stores the parsed EDID block per monitor device — registry location / WMI — before relying on any field.)*
3. **Tertiary — topology position** (which GPU output / physical port). First-class, used explicitly for identical devices or missing EDID, and always with an explicit ambiguity flag when it is the only distinguishing signal.

Resolution outcome per display: `UNIQUE` / `AMBIGUOUS` / `UNKNOWN`. Ambiguity is surfaced, never silently resolved.

Why not EDID-primary (answers the review's direct question): PnP instance path is documented, present for every enumerated monitor, and stable; EDID serials are frequently absent and non-unique. So **EDID should NOT be the primary identity mechanism** — it is a secondary disambiguator.

---

## E. Corrected Profile Model

Persist a **logical model**, re-resolved at apply time (hybrid), not raw `DISPLAYCONFIG` blob reuse:

Per display entry:
- `identity`: PnP instance path + EDID fields when available (the stable key).
- `desired_mode`: resolution, refresh rate, orientation, primary flag, position/offset.
- `topology_role`: active vs disabled (a "disabled" display is one whose target is not attached to an active source path).

Rules:
- **Never** persist transient names (`\\.\DISPLAYn`) as identity. A last-seen DisplayConfig target name/handle may be cached for fast-path matching only, and must be re-derived from stable identity before use.
- Re-resolution against current hardware is mandatory so profiles survive driver updates / reboots / topology change (F9).
- Persisted schema is designed *after* the Phase 0 spike confirms which fields Windows reliably exposes; do not invent an abstraction that cannot faithfully restore.

---

## F. Corrected Windows API Strategy

| API | Role | Notes |
|-----|------|-------|
| `QueryDisplayConfig` (dxva2.h) | **Authoritative read** of current source/target/mode sets per adapter | Core query path for capture + verification |
| `SetDisplayConfig` (dxva2.h) | **Authoritative apply** of a source→target path + mode; attach/detach targets to change topology | Best-effort, not atomic; verify after every apply. Exact flags/sequence = SPIKE |
| `DisplayConfigGetDeviceInfo` | Device name/description for a target/source | Supplementary identity cross-check only |
| `SetupDiGetDeviceRegistryProperty` / `CM_Get_Device_Interfaces` (or WMI) | **Persistent physical identity** (PnP instance path, hardware ID) | The real identity source — was missing from the plan |
| EDID read (registry/WMI) | Secondary disambiguation fields | SPIKE: confirm location before use |
| `RegisterDeviceNotification` / `WM_DEVICECHANGE` | Detect topology/enumeration change (objective 6) | Or lazy re-resolution on apply as fallback |
| `EnumDisplayDevices` / `EnumDisplaySettingsEx` | Optional cross-validation only | Legacy GDI; do NOT build identity/capture on these |
| `RegisterHotKey` | Global profile-switch shortcuts | Fine as listed |
| `Shell_NotifyIcon` (+ message loop) | System tray | Real Win32 work, not a one-liner (F8) |

Interaction: query current state → resolve stable identities → build desired path+mode per display (detach target for "off") → apply via `SetDisplayConfig` → re-query → compare desired vs actual.

---

## G. Corrected Implementation Phases

Prove the Windows core before any UI. Add the missing spikes.

- **Phase 0 — API spike (CLI).** Prove Windows exposes enough to: enumerate displays, read modes, and obtain a *persistent* identity per display. Sub-spikes: PnP instance-path stability across driver update; EDID field availability/location; `SetDisplayConfig` attach/detach + exact flags/sequence; "primary" selection mechanism; powered-off-TV visibility. **Gate:** every physical display can be distinguished by a stable key, and modes are readable.
- **Phase 1 — Identity & resolver (pure Rust).** Implement `DisplayIdentity`, layered resolution, ambiguity handling. Dedicated tests (reorder, identical monitors, missing serial). **Gate:** enumeration changes do not change physical identity; ambiguous cases surface as AMBIGUOUS.
- **Phase 2 — Capture + persistence.** `capture_current()` → logical profile model → JSON round-trip. **Gate:** captured config serializes and re-resolves equivalently against current hardware.
- **Phase 3 — Apply (`apply_profile`).** Build path+mode, detach for disabled, apply via `SetDisplayConfig`, then verify. Tests: Work→Gaming→Work; TV disconnected; monitor disconnected; TV powered off; display order changed; resolution manually changed. **Gate:** profiles reliably switch topology and verification reports the true outcome.
- **Phase 4 — Verification & recovery.** Desired-vs-actual comparison → SUCCESS / PARTIAL / FAILED (+ AMBIGUOUS). Define retry/fallback/abort behavior (no silent full-restore claims). **Gate:** app can state whether the requested profile was achieved.
- **Phase 5 — Tray application.** Minimal tray, profiles list, capture action, notifications, optional startup. Keep thin; no fancy UI.
- **Phase 6 — Hotkeys.** Configurable global shortcuts (`Ctrl+Alt+W` / `Ctrl+Alt+G`).
- **Phase 7 — Hardening.** Reboot, sleep/wake, HDMI/DP hotplug, TV power off/on, driver updates, Windows updates, refresh/resolution changes, multiple identical monitors, missing displays, reordered displays.

---

## H. V1 Acceptance Criteria (measurable)

Given `DISPLAY1→Monitor A`, `DISPLAY2→Monitor B`, `DISPLAY3→TV`, and later `DISPLAY1→TV`, `DISPLAY2→Monitor B`, `DISPLAY3→Monitor A`:
- **A1 — Reorder:** resolver still identifies the same three physical displays (same stable keys), independent of enumeration order.
- **A2 — Round-trip:** Work → Gaming → Work restores exact topology each time; verification returns SUCCESS with no missing displays.
- **A3 — TV unavailable:** applying a profile that references an absent TV reports PARTIAL (or AMBIGUOUS if identity can't be resolved), never claims full restore, and applies the available subset correctly.
- **A4 — Identical monitors:** two physically identical monitors are distinguished by topology position; ambiguity is surfaced when no signal distinguishes them.
- **A5 — Ambiguous identity:** a display with no distinguishing signal yields AMBIGUOUS and is not silently assigned.
- **A6 — Unsupported mode:** requesting an unsupported resolution/refresh fails cleanly (FAILED) without corrupting the current config.
- **A7 — Sleep/wake & hotplug:** after wake or plug/unplug, re-resolution still maps stable identities to correct physical displays; no stale `DISPLAYn` binding survives.

---

## I. Questionable Assumptions (from baseline plan)

**ASSUMPTION 1 — EDID is the primary identity mechanism.**
Why it may be wrong: serials are frequently absent (TVs), there is no clean public API to read raw EDID bytes for an arbitrary display, and identical monitors share one EDID.
Evidence / Windows behavior: persistent PnP device instance paths *are* exposed (`SetupDiGetDeviceRegistryProperty` / WMI) and are stable across reboot/driver updates; EDID data exposure is not guaranteed.
Corrected approach: PnP instance path primary; EDID secondary disambiguation; topology last-resort with ambiguity handling (see D).

**ASSUMPTION 2 — `EnumDisplayDevices`/`EnumDisplaySettingsEx` are core capture/identity APIs.**
Why it may be wrong: they enumerate transient logical names and per-name modes; not authoritative for topology changes.
Evidence / Windows behavior: the Display Config API (`QueryDisplayConfig`) already yields source/target/mode authoritatively; `\\.\DISPLAYn` names change with enumeration — exactly what we must avoid.
Corrected approach: keep them optional cross-validation only (see F).

**ASSUMPTION 3 — Applying a profile via `SetDisplayConfig` is atomic.**
Why it may be wrong: a full topology change spans multiple displays/adapters and is a sequence of operations; partial failure is possible.
Evidence / Windows behavior: no documented transaction guarantee across the operation set.
Corrected approach: treat as best-effort + mandatory verification; report PARTIAL/FAILED honestly (see F3).

**ASSUMPTION 4 — Raw captured Display Config structures can be reused after system changes.**
Why it may be wrong: source/target handles and mode sets go stale across driver updates / reboots / topology change.
Evidence / Windows behavior: handles are per-session; enumeration is not persistent.
Corrected approach: persist a logical model (identity + mode params) that is re-resolved against current hardware (see E).

**ASSUMPTION 5 — Every monitor has a unique serial number.**
Why it may be wrong: TVs and many monitors expose no serial; identical units share EDID.
Evidence / Windows behavior: EDID completeness varies by panel/manufacturer.
Corrected approach: layered identity with ambiguity handling; never assume uniqueness (see D).

**ASSUMPTION 6 — "Primary display" is directly settable via the API.**
Why it may be wrong: primary may be derived from enumeration order rather than a flag, and the mechanism is not established.
Evidence / Windows behavior: not documented as a simple `SetDisplayConfig` flag.
Corrected approach: mark SPIKE; confirm before designing around it (see F6).

**ASSUMPTION 7 — A powered-off TV is always visible to Windows.**
Why it may be wrong: an off HDMI TV may report no EDID and drop out of enumeration.
Evidence / Windows behavior: visibility depends on whether the device reports when powered down.
Corrected approach: explicit known/connected/active state model; never claim full restore when a display is missing (see F7).

**ASSUMPTION 8 — The tray UI is trivial to build.**
Why it may be wrong: native Win32 tray + menu needs a real message loop (`WNDPROC`, `Shell_NotifyIcon`).
Evidence / Windows behavior: standard Win32 shell-notification plumbing.
Corrected approach: keep minimal and late in the sequence; budget real effort (see F8).
