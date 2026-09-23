# DIS-PLAY Master Plan — V2 Review Findings & Corrected Design

V2 review of `DIS-PLAY-MASTER_PLAN_REVISION.md` (the V1 revision). It validates the technical assumptions V1 introduced, corrects what is still inaccurate or over-confident, and produces a more conservative, evidence-driven design. The clean standalone result lives in `DIS-PLAY-MASTER_PLAN_REVISION_v2.md`.

## Confidence legend (used throughout)
- **DOCUMENTED** — stated by Microsoft/Windows SDK documentation; safe to rely on.
- **OBSERVED** — expected real behavior on the target machine, not yet confirmed here; must be verified in Phase 0.
- **INFERRED** — reasoned from how Windows works; plausible but unconfirmed.
- **UNKNOWN** — cannot be established without an experiment on the actual hardware.

I have no live access to a Windows machine in this session, so every *empirical* claim (stability, uniqueness, TV behavior) is labeled OBSERVED/INFERRED/UNKNOWN and routed into the Phase 0 CLI spike rather than asserted as fact. Web/SDK documentation WAS consulted for validation (see §15); where docs settle a question it is marked DOCUMENTED, but permanence/uniqueness still require Phase 0 observation on real hardware. That is the whole point of V2: **do not decide what the persistent identity is before the evidence exists.**

---

## 1. What V1 got right (keep)
- Transient `\\.\DISPLAYn` must NOT be identity; profiles re-resolve against current hardware at apply time.
- `QueryDisplayConfig` / `SetDisplayConfig` are the authoritative read/apply surfaces (not legacy GDI).
- Application is best-effort + mandatory verification, not atomic.
- known / connected / active state model for hotplug and powered-off TVs.
- Pure-Rust core separated from Windows FFI so resolver logic is testable on any OS.
- WMI demoted; `EnumDisplayDevices`/`EnumDisplaySettingsEx` reduced to cross-validation only.

## 2. What V1 got wrong or left uncertain (correct in V2)
- **V1 asserted PnP instance path = primary identity and "stable across reboots, driver updates, enumeration-order changes."** That is INFERRED, not established. V2 does NOT commit to it as THE identity; it becomes one *evidence signal* validated empirically (see §3).
- **V1 used a fixed hierarchy `PnP > EDID > topology`.** A hardcoded precedence assumes one field is always present and authoritative. V2 replaces it with an **identity evidence model**: each candidate carries multiple optional signals; the resolver reports UNIQUE / AMBIGUOUS / UNKNOWN from what is actually available (see §3, §13).
- **V1 named `DisplayConfigGetDeviceInfo` as "supplementary cross-check only."** It is actually a primary *source* of identity evidence (`monitorDevicePath`, friendly name) — V2 reclassifies it.
- **V1 listed WMI as an identity source option.** If SetupAPI + DisplayConfig suffice, WMI adds no value; V2 marks it NOT REQUIRED (optional cross-check only).
- **V1 profile schema was effectively locked** (`identity` + `desired_mode` + `topology_role`). V2 defers finalization until Phase 0 shows which signals are actually stable.

---

## 3. PnP identity assumption — explicit address

V1 §9 stated as fact: *"its instance path encodes physical port/topology and is stable across reboots, driver updates, and enumeration-order changes; it only changes on genuine rewiring."* **That is INFERRED, not established.** V2 corrects this.

Distinguish the identifiers (do NOT collapse them):
- **PnP device instance ID** — per-device-instance path (e.g., a `PCIROOT(...)`/GUID-style instance string). Candidate for *per-unit* identity. Uniqueness/stability = OBSERVED, must test.
- **Hardware ID (`HARDWAREID`)** — identifies the device *type/model*, NOT an individual unit. Two identical monitors share it. **NOT a unique physical identity.** (V1's "PnP ... / hardware ID" phrasing conflated these.)
- **Device interface path** — only for devices that expose interfaces; may not apply to monitors. UNKNOWN here.
- **`monitorDevicePath`** — the DisplayConfig field documented as the monitor's PnP device path (see §4).
- **DisplayConfig target ID / handle** — per-session, NOT persistent across reboot. Never an identity key.

Answering the 9 questions honestly:
1. *Which identifier is actually available for a monitor?* `monitorDevicePath` / PnP instance path (DOCUMENTED field); Hardware IDs also present but not unique.
2. *Is it unique?* **UNKNOWN until tested.** Likely per-instance; identical monitors may or may not get distinct paths — must verify.
3. *Survives reboot?* INFERRED yes for the PnP instance path; OBSERVED confirmation needed.
4. *Survives GPU driver update?* INFERRED yes (monitor PnP enumeration is driven by the OS monitor class, somewhat independent of the AMD vendor driver); OBSERVED confirmation needed.
5. *Changes when moved to another connector?* **UNKNOWN** — depends on whether the instance path encodes connector position. This decides "same physical display with changed connection" vs "different binding."
6. *Changes when same physical display reconnected?* INFERRED no (same port); OBSERVED needed.
7. *Different for two identical monitors?* **UNKNOWN — THE key test.** If Windows enumerates a PnP device per connector, likely distinct; if EDID-derived and they're identical, maybe not. Must test empirically.
8. *Available for TVs?* **UNKNOWN** — the Sony TV may or may not enumerate as a standard PnP "Monitor" class device with an instance path. Must test.
9. *Remains available when TV powered off?* **UNKNOWN** — likely the PnP device disappears when the TV stops reporting; must test.

**Correction:** V2 treats `monitorDevicePath` / PnP instance path as a *candidate evidence signal*, not established identity. The resolver must degrade gracefully and report AMBIGUOUS/UNKNOWN when it cannot uniquely match. No assertion of permanence without Phase 0 evidence.

## 4. `monitorDevicePath` — explicit address
- **What it is (DOCUMENTED, wingdi.h):** `WCHAR monitorDevicePath[128]` in `DISPLAYCONFIG_TARGET_DEVICE_NAME`, documented as "the path to the device name for the monitor," usable with SetupAPI; obtained via `DisplayConfigGetDeviceInfo(targetHandle)`. It is a *path string*, resolvable through SetupAPI/CM. The same struct also exposes `connectorInstance` (UINT32, one-based instance number unique within an adapter, 0 when it is the only target of its type) — a first-class disambiguation signal for identical units on one GPU.
- **Stable across reboot / driver update:** INFERRED yes; OBSERVED needed (do not assume).
- **Changes when monitor moves connector:** UNKNOWN — this is exactly the DP1→DP2 experiment (§6 of the prompt). If it encodes the connector, a move changes it.
- **Identifies monitor vs monitor/connector combo:** UNKNOWN until tested. This distinction drives whether "physical identity" and "display role" are separable (see §5).
- **Resolvable through SetupAPI:** yes — that is its purpose; resolve to instance ID + Hardware IDs.
- **Usable as profile identity:** *conditionally* — only if Phase 0 confirms it is stable AND per-unit; otherwise combine with connector/EDID signals and surface ambiguity.

**Correction:** V1 treated `monitorDevicePath` as a given primary key. V2 treats it as the most promising candidate but requires OBSERVED confirmation of stability + uniqueness before any profile depends on it alone.

## 5. Identical monitors — explicit address (first-class)
Example: two Dell U2723QE, same manufacturer/model/product code, missing serial, identical EDID. How Windows distinguishes them is **UNKNOWN until tested**, but the likely mechanism is: Windows enumerates a monitor PnP device *per connected display*, so two identical units on DP1/DP2 become two PnP devices with (likely) distinct instance paths / `monitorDevicePath`. That is INFERRED; Phase 0 must confirm whether the two Dells get distinct values.

Two semantic concepts that V2 keeps separate:
- **Physical identity** — "this exact physical monitor" (the unit).
- **Display role / connector role** — "the display currently occupying this position/connector."

For identical units you CANNOT distinguish by EDID/model — only by connector/instance. So a profile entry like "Monitor A ON, Monitor B OFF" where A/B are *roles* must be resolved against physical units via the current connector binding. The design must support BOTH physical-identity matching and role/connector matching, and represent ambiguity when they conflict (e.g., user swapped which unit is on DP1 vs DP2). **Correction:** V1 only gestured at this ("topology last-resort"); V2 makes it a first-class resolver requirement with explicit ambiguity representation.

## 6. Connector identity — explicit address
V1 treated topology position as a mere fallback. V2 elevates it: **connector is likely a stronger, more stable signal than V1 credited**, because PnP monitor devices are enumerated per connector and `monitorDevicePath`/instance path may encode or be tied to the connector. So `GPU + connector` may be *the* operative identity for a display relationship — especially as the only thing that distinguishes identical units.

Consequence of moving DP1→DP2: V2 says treat it as **a changed binding** (the profile entry bound to "DP1" no longer matches the unit now on DP2 if keyed by connector), OR the same physical display with a changed connection (if keyed by physical unit). The model must pick and represent this explicitly. Given identical units can't be keyed by EDID, **connector is likely the operative identity**, so a move = different binding → resolver reports not-matching-by-physical-unit but matching-by-role/connector. This needs to be explicit in the profile model (see §12 of prompt / plan §profile).

## 7. EDID — explicit address
- **What Windows exposes through DisplayConfig (DOCUMENTED):** `DISPLAYCONFIG_TARGET_DEVICE_NAME` directly carries `edidManufactureId` + `edidProductCodeId` (UINT16 each, set when the `edidIdsValid` bit is in `flags`) plus `monitorFriendlyDeviceName[64]`. Manufacturer + product code are therefore available *without* raw EDID parsing; only a serial number is not exposed here. **Raw EDID parsing is NOT necessary** for this app.
- **Where else EDID appears:** Windows may cache parsed EDID per monitor device in a registry location used by the OS "EDID" feature; exact path unconfirmed → **SPIKE/experiment** only if we ever need more than manufacturer/product code. Do not assert.
- **SetupAPI / WMI for EDID:** SetupAPI gives PnP properties (instance ID, Hardware IDs), not raw EDID; WMI is NOT REQUIRED if SetupAPI + DisplayConfig suffice.
- **Minimum identity actually required:** NOT raw EDID. It is: a persistent per-unit signal (`monitorDevicePath`/PnP instance path, validated) + disambiguation for identical units (connector/instance). Raw EDID parsing is added only if the spike shows we cannot distinguish otherwise.

**Correction:** V1 kept "EDID secondary" but still implied an EDID read path might be needed. V2 states plainly: do not add raw EDID parsing; use `monitorDevicePath` + connector as primary evidence, EDID fields (manufacturer/product/serial when present) only as optional disambiguation if cheaply available.

## 8. SetDisplayConfig — explicit address (now DOCUMENTED)
V1 said "detach target for 'off'" and listed exact flags as SPIKE but still implied the mechanism. V2 is stricter, and web/SDK validation now settles most of it. `SetDisplayConfig` (winuser.h / User32.dll; structures in wingdi.h) takes a path array + mode array + flags:
- **Apply:** `SDC_APPLY | SDC_USE_SUPPLIED_DISPLAY_CONFIG` sets the supplied topology/source/target modes (add `SDC_SAVE_TO_DATABASE` to persist). DOCUMENTED.
- **Verify without applying:** `SDC_VALIDATE | SDC_USE_SUPPLIED_DISPLAY_CONFIG` tests whether a requested topology can be set — this is the concrete pre-apply check, plus post-apply re-query via `QueryDisplayConfig`. DOCUMENTED.
- **Return codes (DOCUMENTED):** `ERROR_SUCCESS`, `ERROR_INVALID_PARAMETER`, `ERROR_NOT_SUPPORTED` (needs WDDM driver), `ERROR_ACCESS_DENIED` (no console-session access — e.g., remote session; not simply "admin"), `ERROR_GEN_FAILURE`, `ERROR_BAD_CONFIGURATION`.
- **Disable a display ("off"):** detach its target from an active source path. The flag vocabulary is now documented, but the exact call/sequence for a clean detach is still **SPIKE** (do not state it as fact).
- **Change position / topology:** attach/detach paths + reorder sources — **SPIKE for exact sequence.**
- **Select primary → see §9 (now DOCUMENTED via path priority order).**
- **Restore captured config:** reconstruct path+mode per display and apply; **NOT atomic** (no documented transaction guarantee); failure semantics = best-effort + verify.

V2 keeps the *shape* of the operation, now grounded in the documented flag set, and routes only the unvalidated specifics (exact detach sequence) into Phase 0 experiments. This directly answers "Do not simply state 'detach target for disabled' unless technically validated."

## 9. Primary display — explicit address (now DOCUMENTED)
- **How Windows represents primary:** the "primary" logical display is `\\.\DISPLAY1` (the first); it is tied to path priority / source ordering, not a stored per-display flag. INFERRED for the storage form.
- **Does SetDisplayConfig control it? YES — via path priority order (DOCUMENTED).** "The order in which active paths appear in the path array determines path priority" and `QueryDisplayConfig` always returns paths in priority order; lower array index = higher priority, and the highest-priority path is where flips are scheduled. So primary is set by controlling the *order* of active paths supplied to `SetDisplayConfig`, not by a single boolean flag.
- **Another API required?** No — it derives from path ordering (the same call that applies topology).
- **Should the app persist "primary"?** YES, persist *desired* primary (which display should be primary) and verify post-apply; the mechanism is now documented as path-priority ordering (exact index placement still confirmed in Phase 0), so it is no longer a blind SPIKE.

## 10. Powered-off TVs — explicit address
Per-scenario behavior of the Sony TV over HDMI (all OBSERVED/UNKNOWN until tested on this exact TV):
1. **Powered on** → enumerated normally; `monitorDevicePath` + PnP present.
2. **Powered off** → likely disappears from enumeration (no EDID reported when off) — but some TVs stay electrically "connected" and may still enumerate with a basic EDID. **UNKNOWN per-TV.**
3. **Sleeping** → similar to powered off; depends on TV behavior.
4. **HDMI disconnected** → absent from enumeration (no signal).
5. **Connected but unavailable** → enumerated as a target with no active mode, or absent — OBSERVED/needs test.
6. **Turned on after PC** → appears late; app must handle late detection (re-resolve; do not assume present at startup).
7. **Turned off while profile active** → the "Gaming" profile expecting TV ON finds it missing → PARTIAL / AMBIGUOUS, reported honestly.

Can a previously known display be recognized after disappearing and returning? **Depends on whether `monitorDevicePath`/PnP instance path is stable across disappear/reappear.** If the PnP device re-registers with the same path when the TV powers back on → yes (re-recognizable). If it gets a new path each time → no. **OBSERVED/needs test** — key Phase 0 experiment.

The state model stays known / connected / active, but V2 ties its handling to *observed* Sony-TV behavior rather than assuming the TV is always visible or always absent-when-off.

## 11. Re-evaluated API table (classifications)
| API | Class | Justification |
|-----|-------|----------------|
| `QueryDisplayConfig` | **CORE** | Authoritative read of source/target/mode sets; capture + verification path |
| `SetDisplayConfig` | **CORE** | Apply path+mode / topology change (flags DOCUMENTED; exact detach sequence = SPIKE); best-effort + verify |
| `DisplayConfigGetDeviceInfo` | **SUPPORTING (identity source)** | Source of `monitorDevicePath` + friendly name — central to identity, not just cross-check |
| `SetupDi*` / CfgMgr32 (`SetupDiGetDeviceRegistryProperty`, `CM_Get_Device_Interfaces`) | **SUPPORTING** | Resolve `monitorDevicePath` → PnP instance ID + Hardware IDs; the persistent-identity path |
| WMI (`Win32_PnPEntity`) | **NOT REQUIRED** | Optional cross-check only; do not add just because it overlaps SetupAPI/DisplayConfig |
| `EnumDisplayDevices` | **LEGACY / OPTIONAL** | Cross-validation of logical names only; never identity/capture |
| `EnumDisplaySettingsEx` | **NOT REQUIRED** | Redundant with `QueryDisplayConfig` for modes |
| `RegisterDeviceNotification` / `WM_DEVICECHANGE` | **OPTIONAL** | Change detection (objective 6); fallback = lazy re-resolution on apply |
| `RegisterHotKey` | **CORE** | Global profile-switch shortcuts (V1 requirement) |
| `Shell_NotifyIcon` (+ message loop) | **CORE** | System tray (real Win32 work, budgeted late) |

Net: drop WMI and `EnumDisplaySettingsEx` from the core; keep `EnumDisplayDevices` optional cross-check only.

## 12. Remaining blockers
- **B1 — Identity permanence unproven.** No evidence yet that `monitorDevicePath`/PnP instance path is stable across reboot/driver update, or unique per unit (esp. identical monitors). Blocks committing to any identity key. → Phase 0 CLI must produce the mapping table before design locks.
- **B2 — Identical-monitor distinguishability unproven.** Whether two Dells get distinct `monitorDevicePath`/instance paths is unknown; if not, physical identity is impossible and only role/connector works (with ambiguity). Blocks the profile model's keying strategy.
- **B3 — SetDisplayConfig apply semantics unvalidated.** Exact enable/disable/topology/primary mechanisms + failure semantics are SPIKEs. Blocks `apply_profile` implementation detail (not its existence).
- **B4 — Sony TV lifecycle behavior unknown.** Whether it stays enumerated when off, and whether it re-registers with a stable path on power-on, is unobserved. Blocks the hotplug/TV handling specifics (not their existence).

None of these block *starting* Phase 0; they are exactly what Phase 0 resolves. They remain blockers to *locking* identity/profile/apply design until evidenced.

## 13. Documented facts vs experiments/inference — ledger
| Claim | Status | Disposition |
|-------|---------|--------------|
| `QueryDisplayConfig`/`SetDisplayConfig` are the authoritative read/apply APIs (winuser.h / User32.dll; structs in wingdi.h) | DOCUMENTED | rely on |
| `DISPLAYCONFIG_TARGET_DEVICE_NAME.monitorDevicePath` exists and is documented as the monitor PnP device path | DOCUMENTED | rely on field existence; NOT its permanence |
| `monitorDevicePath` stable across reboot / driver update | INFERRED → OBSERVED | Phase 0 confirm |
| `monitorDevicePath` unique per physical unit (incl. identical monitors) | UNKNOWN | Phase 0 test (two Dells) |
| PnP instance path survives GPU driver update unchanged | INFERRED → OBSERVED | Phase 0 confirm |
| Two identical monitors get distinct instance paths / `monitorDevicePath` | UNKNOWN | Phase 0 test |
| Sony TV enumerates as a standard PnP Monitor device with an instance path | UNKNOWN | Phase 0 test |
| Sony TV stays enumerated when powered off | UNKNOWN (per-TV) | Phase 0 test |
| Sony TV re-registers with same path after power-on | UNKNOWN | Phase 0 test |
| `SetDisplayConfig` flags: `SDC_APPLY`, `SDC_VALIDATE`, `SDC_USE_SUPPLIED_DISPLAY_CONFIG`, `SDC_SAVE_TO_DATABASE`; return codes incl. `ERROR_ACCESS_DENIED` (console-session access) | DOCUMENTED | rely on; exact detach sequence still SPIKE |
| "Primary" controlled by path priority order (lower array index = higher priority); `QueryDisplayConfig` returns paths in priority order | DOCUMENTED | set primary via supplied path order; confirm index placement Phase 0 |
| Hardware ID identifies type/model, not individual unit | DOCUMENTED | do NOT use as unique key |
| `\\.\DISPLAYn` transient / changes with enumeration | DOCUMENTED/OBSERVED | never an identity key |

## 14. What changed V1 → V2 (summary)
- **Identity:** from a committed fixed hierarchy (`PnP > EDID > topology`) to an **evidence model** — no single field assumed authoritative; resolver reports UNIQUE/AMBIGUOUS/UNKNOWN from available signals. P permanence is now OBSERVED-pending, not asserted.
- **`monitorDevicePath`:** from "the primary key" to "most promising candidate, validated in Phase 0."
- **Hardware ID:** explicitly separated from instance ID and demoted (type/model, shared by identical units).
- **Connector:** elevated from fallback to first-class signal / likely operative identity for identical units.
- **EDID:** raw EDID parsing dropped as unnecessary; optional disambiguation only.
- **SetDisplayConfig:** now DOCUMENTED — exact flag set (`SDC_APPLY`/`SDC_VALIDATE`/`SDC_USE_SUPPLIED_DISPLAY_CONFIG`/`SDC_SAVE_TO_DATABASE`) + return codes; only the exact detach sequence remains SPIKE.
- **Primary:** persisted as desired state + verified; mechanism now DOCUMENTED as path-priority ordering (not a blind SPIKE).
- **API table:** `DisplayConfigGetDeviceInfo` reclassified to identity source; WMI → NOT REQUIRED; `EnumDisplaySettingsEx` → NOT REQUIRED.
- **Profile schema:** deferred until Phase 0 evidence; not locked.

## 15. Web/SDK validation (sources)
Validated against Microsoft Learn / Windows SDK docs during this review (no live hardware; empirical claims still OBSERVED/UNKNOWN):
- `SetDisplayConfig` function reference — winuser.h, User32.dll; exact flags (`SDC_APPLY`, `SDC_VALIDATE`, `SDC_USE_SUPPLIED_DISPLAY_CONFIG`, `SDC_SAVE_TO_DATABASE`), return codes incl. `ERROR_ACCESS_DENIED`. https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setdisplayconfig
- `SetDisplayConfig` summary & scenarios — sets topology/layout/orientation/aspect ratio/bit depth; applies resolution/layout/orientation/scaling/**primary**/bit depth/refresh rate. https://learn.microsoft.com/en-us/windows-hardware/drivers/display/setdisplayconfig-summary-and-scenarios
- Path Priority Order — "order of active paths determines path priority"; `QueryDisplayConfig` returns paths in priority order (this is how primary works). https://learn.microsoft.com/en-us/windows-hardware/drivers/display/path-priority-order
- `DISPLAYCONFIG_TARGET_DEVICE_NAME` struct — wingdi.h; fields incl. `monitorDevicePath[128]`, `connectorInstance`, `edidManufactureId`, `edidProductCodeId`. https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name

## Severity findings (V2)
| ID | Severity | Finding |
|----|-----------|---------|
| V1-F1 | **HIGH** | PnP instance path asserted as established primary identity ("stable across reboots/driver updates"). INFERRED, not proven. Corrected to candidate evidence signal validated in Phase 0; no permanence assumed. |
| V1-F2 | **HIGH** | Fixed hierarchy `PnP > EDID > topology` assumes one field is always present/authoritative. Replaced by an identity evidence model that degrades gracefully and reports AMBIGUOUS/UNKNOWN. |
| V1-F3 | **MEDIUM** | "detach target for 'off'" stated as the disable mechanism without validation. Corrected to SPIKE; no enable/disable/topology/primary mechanism asserted. |
| V1-F4 | **MEDIUM** | `DisplayConfigGetDeviceInfo` mislabeled "supplementary cross-check only"; it is a primary identity source (`monitorDevicePath`, friendly name). Reclassified SUPPORTING (identity source). |
| V1-F5 | **LOW** | WMI listed as an identity source option. Reclassified NOT REQUIRED (optional cross-check only) to minimize dependencies. |
| V1-F6 | **MEDIUM** | Profile schema effectively locked (`identity`+`desired_mode`+`topology_role`). Corrected: defer finalization until Phase 0 shows which signals are stable; derive from identity + SetDisplayConfig evidence. |

## Adversarial quality gate (section 23 of the prompt) — confirmed handled
1. Logical vs physical identity? Separated: `\\.\DISPLAYn` = logical/transient; resolver keys on evidence, never logical names. ✓
2. Connector vs monitor? Connector is first-class; DP1→DP2 move semantics explicit (§6). ✓
3. Hardware ID vs instance ID? Explicitly separated; Hardware ID demoted (type/model). ✓
4. Assuming EDID serials exist? No — optional evidence, degrades gracefully. ✓
5. Identical displays always distinguishable? No — only via connector/instance (needs validation); AMBIGUOUS otherwise. ✓
6. `monitorDevicePath` permanent without evidence? No — INFERRED/OBSERVED, Phase 0 validated. ✓
7. SetDisplayConfig transactional? No — best-effort + verify; no atomicity claim. ✓
8. Primary = simple flag? No single boolean; DOCUMENTED as path-priority ordering (lower array index = higher priority). ✓
9. Powered-off HDMI stays enumerated? No — per-TV OBSERVED; model handles absence. ✓
10. Persisting stale runtime identifiers? No — profile persists evidence keys + mode params, not targetId/handles/`\\.\DISPLAYn`. ✓
11. Profile reconstructable after reboot? By design (evidence re-resolved); validated Phase 0. ✓
12. Resolver can refuse unsafe ambiguous match? Yes — AMBIGUOUS state + no silent assignment. ✓
13. V1 still small enough to implement? Yes — evidence model kept minimal, WMI dropped, scope tight. ✓
14. Any API/subsystem not necessary? Dropped WMI (NOT REQUIRED), `EnumDisplaySettingsEx` (NOT REQUIRED); `EnumDisplayDevices` optional cross-check only. ✓
