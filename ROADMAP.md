# ROADMAP — DIS-PLAY

_Last updated: 2026-09-26_

A forward-looking plan for DIS-PLAY beyond the completed **Phases 0–8** (final verification +
release preparation). Each feature is a design **proposal** (status `PROPOSED` unless noted), and
every Windows-API dependency is flagged with its evidence status so a validation spike is scheduled
before it gates a phase. This document does **not** assert facts as verified that have not been
`OBSERVED`/`DOCUMENTED` — see the **Status legend** and **Phase execution rules** below.

---

## 1. Where we are (baseline, verified)

**Evidence status: OBSERVED unless marked otherwise.**

- **Phases 0–8 COMPLETE** (see `STATUS.md`, `phases/INDEX.md`):
  - Read-only enumeration + identity (`list`, `dump`, `dump-all`, `targets`, `pnp`, `identity`).
  - Evidence-based identity resolver → `UNIQUE / AMBIGUOUS / UNKNOWN` (D-P2, D-103, D-104).
  - Profile capture + JSON persistence (`profile capture|list|show`, schema v1, additive `#[serde(default)]` fields).
  - Gated apply/validate (`apply`/`validate` on profiles; `SDC_APPLY|SDC_USE_SUPPLIED_DISPLAY_CONFIG` + `SDC_SAVE_TO_DATABASE` for apply — D-108, D-130).
  - Verification + recovery (`verify`, last-known-good, gated `recover` — D-113, D-114, D-116).
  - System-tray app (`dis-play tray`): menu applies profiles, `Verify`, `Recover`, `Refresh`, `Exit`.
  - Global hotkey **Ctrl+Alt+D** = 2-profile toggle (`hotkeys.json`, D-122).
  - Taskbar icon (GDI+ PNG → HICON, D-123); structured file logging (T7.1); single-instance guard (T7.2); autostart (T7.3); NSIS installer (T7.4).
  - Mode & position preservation (T8.1–T8.8, D-128/D-129/D-130): re-enable restores captured res/refresh/orientation/position; reboot persistence confirmed.
- **CLI surface** (see `product/src/main.rs`, `product/README.md`):
  `list dump dump-all targets pnp identity snapshot diff profile{capture|list|show} validate verify apply recover tray autostart{register|unregister|status}`.
- **Tray menu surface**: apply each profile, `Verify live topology`, `Recover last-known-good`, `Refresh profiles`, `Exit`.
- **Not yet implemented** (this roadmap's scope): tray profile *management* (rename/delete/duplicate/save-current), toast *notifications*, per-profile hotkeys, settings UI, sleep/wake & hotplug handling, `diagnose`, `--help`/`--version`, CI/code-signing.

**Known deferrals** (from `STATUS.md`):
- **E3** (driver-update identity stability) — DEFERRED (user has latest AMD drivers).
- **E5** (TV power-cycle lifecycle) — ACCEPTED NOT OBSERVABLE for this TV (always-on EDID; `connected=true` even "off").
- **VIE2701** physically absent (in repair) — `work`/`work-notv` resolve with a skipped VIE entry until it returns.

---

## 2. Status & evidence legend

**Feature status** (in the feature tables):

| Label | Meaning |
|---|---|
| **DONE** | Implemented and OBSERVED (cite `STATUS.md` decision/task). |
| **PROPOSED** | On this roadmap; not implemented. |
| **PLANNED** | In a near-term phase; implementation not yet started. |

**Windows-API feasibility** (where a feature depends on an OS API):

| Label | Meaning |
|---|---|
| **DOCUMENTED** | Microsoft/SDK documented; safe to rely on for *existence*. Exact page pinned during the phase's validation spike. |
| **INFERRED** | Reasoned from how Windows works; plausible, must confirm on target HW before the phase gate. |
| **SPIKE** | Not yet validated; route to a dedicated validation task before it gates the phase. |

**Rule (from `AGENTS.md`):** no phase is complete on inference alone — at least one `OBSERVED`/`DOCUMENTED` item must satisfy each gate criterion. The gates below are written so they can be met that way.

---

## 3. Gap analysis (what's missing vs. user value)

| # | Area | V1 plan ref | Current state | Gap | User value (priority) |
|---|---|---|---|---|---|
| 1 | Profile management in tray | §16 "Save Current… / Manage Profiles…" | CLI `capture` only; tray = apply only | No `save-current`, rename, delete, duplicate in tray or CLI | **HIGH** — core V1 promise |
| 2 | Notifications | §18 "clear notifications" | Tray tooltip + status line only | No toast/success/partial/failure surfacing | **HIGH** — fast feedback |
| 3 | Per-profile hotkeys | §17 "Ctrl+Alt+W / Ctrl+Alt+G" | Single Ctrl+Alt+D 2-profile toggle | Per-profile, configurable shortcuts | **HIGH** — core V1 promise |
| 4 | Settings surface | §19 "Start with Windows" | CLI autostart only, no UI | Settings UI (hotkeys, default, autostart, log level) | **MED-HIGH** |
| 5 | Sleep/wake handling | Phase 7 acceptance A7 | None | Detect resume; re-verify/notify active profile | **MED** |
| 6 | Hotplug / device change | §14, acceptance A8 | Lazy re-resolve on apply | `WM_DEVICECHANGE` → live status update | **MED** |
| 7 | Recovery depth | §4, §13 | Single last-known-good snapshot | Multiple checkpoints; configurable auto-recover on startup | **MED** |
| 8 | Diagnostics | — | none | `diagnose` health check; `--help`/`--version`; verbose verify | **MED** |
| 9 | Logging ops | T7.1 (file only) | Dated append log | Viewer command; rotation/size cap; level config | **LOW-MED** |
| 10 | Release process | — | Manual NSIS, unsigned | Code-signing, CI/CD, changelog, auto-update (opt.) | **HIGH for trust** |
| 11 | Testing automation | — | 56/56 unit tests | CI matrix, property/fuzz, integration, benchmarks | **MED** |
| 12 | Extensibility | §22, non-goals | — | Automation API, scheduling; audio/sync only if re-opened | **LOW (future)** |

> **Note on the tray profile gap.** The *capability* to capture a profile exists (`core/persistence.rs::save_profile`, `profile capture`). What is missing is the **tray/CLI management surface** (save-current action, rename, delete, duplicate) and **notifications** — not the underlying storage. `persistence.rs` currently offers only `save_profile`/`load_profile`/`list_profiles` (`OBSERVED`, file reviewed), so rename/delete/duplicate are new operations.

---

## 4. Phased roadmap

### Phase 9 — Release v1.0 (finish the current state)

**Goal:** Ship a trustworthy v1.0 — verified, signed, reproducible, documented.
**User value:** Users can install, run, and *trust* the app (no SmartScreen blocks, clear version, stable installer).
**Release it maps to:** v1.0.0.

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T9.1 | Complete final verification: full test suite on target HW (56/56), `validate work`/`work-notv` rc=0, install→run→uninstall on a **clean** Win10/11 machine | — | PROPOSED |
| T9.2 | **Authenticode code-signing** the release binary + installer (`signtool`) with a published cert; verify signature | **DOCUMENTED** (Authenticode, signtool, Win SDK); cert provisioning = SPIKE for *our* cert | PROPOSED |
| T9.3 | **Versioning**: bump `Cargo.toml` `version`, surface via `--version`, stamp in installer metadata, keep a CHANGELOG | — | PROPOSED |
| T9.4 | **CI/CD** (GitHub Actions): build, test, `cargo clippy -- -D warnings`, build installer on `windows-latest` (Win10/11) | **DOCUMENTED** (GitHub Actions `windows-latest`); no live-display work in CI (core is pure Rust) | PROPOSED |
| T9.5 | **README refresh**: all commands, install, troubleshooting, known deferrals (E3, E5), uninstall behavior | — | PROPOSED |
| T9.6 | Installer polish: uninstall removes autostart Run key, start-menu shortcut, (optional) user config dir; add file size + version to release notes | — | PROPOSED |

**Gate (complete only when all are OBSERVED/DOCUMENTED):**
- [ ] Signed binary + installer verified by `signtool verify` / Windows SmartScreen (OBSERVED on clean Win11).
- [ ] Clean-machine install → tray runs → one gated profile apply → uninstall removes autostart (OBSERVED).
- [ ] CI pipeline green: build + test + clippy + installer on `windows-latest` (OBSERVED).
- [ ] `--version` prints a real semver; CHANGELOG present (OBSERVED).

**Prereqs / notes:**
- Code-signing requires the user to **procure a certificate** (personal code-sign cert, or a cloud signing service). This is the main external dependency — flag early.
- Do **not** block release on CI if a machine is unavailable; T9.2 signing is the gating item, CI is parallel.

---

### Phase 10 — User Experience (tray profile management, notifications, per-profile hotkeys, settings)

**Goal:** Complete the three V1 promises the current build lacks: tray profile management, toast notifications, per-profile hotkeys — plus a thin settings surface.
**User value:** The tray becomes a real manager (not just an apply button); every switch gives visible feedback; each profile has its own shortcut; settings are tweakable without CLI.
**Release it maps to:** v1.1.

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T10.1 | **Tray "Save Current Configuration…"** (capture live topology into a prompted name) | Reuses existing `profile capture` path (OBSERVED) — no new API | PROPOSED |
| T10.2 | **Toast notifications** for success / PARTIAL / failure (dismissable, non-intrusive; opt-out in config) | **DOCUMENTED** (WinRT `Windows.UI.Notifications`, Win10+); Rust crate + target-HW behavior = SPIKE | PROPOSED |
| T10.3 | **Profile management in tray** (rename, delete, duplicate) and CLI (`profile rename/delete/dup`) | File ops on the same `%LOCALAPPDATA%\dis-play\profiles` dir; schema-safe (OBSERVED dir layout); rename = save-as + delete + update refs (SPIKE: update any hotkey/auto-refs to the new name) | PROPOSED |
| T10.4 | **Active-profile indicator** in tray menu + tooltip (which profile is currently applied / last-known-good) | Reads existing lkg + apply state (OBSERVED state already tracked) | PROPOSED |
| T10.5 | **Per-profile hotkeys**: `Ctrl+Alt+W`, `Ctrl+Alt+G`, … — configurable per profile, replacing/extending the 2-profile toggle | **DOCUMENTED** (`RegisterHotKey`, already used in T6.3); multi-hotkey registration + conflict detection = extend existing code (SPIKE: >2 simultaneous hotkeys + `ERROR_HOTKEY_ALREADY_REGISTERED` per-key) | PROPOSED |
| T10.6 | **Hotkey config UI / "learn by press"**: capture key combos into config; detect & report conflicts | `RegisterHotKey` + `WM_KEYDOWN` in tray window (DOCUMENTED); UI = small native window or extended menu | PROPOSED |
| T10.7 | **Settings surface** (tray menu → small settings window or JSON): hotkeys, default profile, autostart toggle, log level, toast on/off | Registry autostart already done (T7.3); new keys added to `%LOCALAPPDATA%\dis-play\config` (OBSERVED config dir) | PROPOSED |
| T10.8 | **Recent switches + Undo**: last-N applied profiles in tray; "Undo" re-applies the previous profile | Pure in-memory + profile store (OBSERVED); undo = apply previous (reuses apply path) | PROPOSED |

**Gate:**
- [ ] User can Save Current / rename / delete / duplicate profiles entirely from the tray; state persists across restarts (OBSERVED).
- [ ] Every switch (success / PARTIAL / failure) shows a dismissable toast; opt-out respected (OBSERVED on target HW).
- [ ] Each profile can bind its own hotkey; conflicts are detected and surfaced; `ERROR_HOTKEY_ALREADY_REGISTERED` per-key handled (OBSERVED).
- [ ] Settings (autostart, default profile, log level, toast on/off) persist and take effect on restart (OBSERVED).

**Prereqs / notes:**
- T10.2 (toasts) needs the WinRT Rust bindings (e.g., the `winrt` crate) — add to `Cargo.toml` in a spike first.
- Toast opt-in/out + "do not disturb" behavior must be validated on the **user's** OS (some apps/enterprise policies suppress toasts).
- This phase is the highest value; sequence T10.1 → T10.5 → T10.2 → T10.6 → T10.7.

---

### Phase 11 — Robustness (sleep/wake, hotplug, deeper recovery)

**Goal:** The app stays correct across power and hotplug events and recovers itself without manual intervention (configurable).
**User value:** Wake the PC or unplug/replug a display and dis-play knows — it re-verifies, notifies, and (optionally) re-applies the intended profile.
**Release it maps to:** v1.2.

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T11.1 | **Sleep/resume detection** → on resume, re-verify the active profile; if PARTIAL/FAILED, toast + offer re-apply | **DOCUMENTED** (`WM_POWERBROADCAST` + `SetPowerBroadcastStatus`); behavior on target HW = OBSERVED needed | PROPOSED |
| T11.2 | **Device-change notifications** (monitor attach/detach) → update tray status, re-resolve, never go stale | **DOCUMENTED** (`WM_DEVICECHANGE` via `RegisterDeviceNotification`, already cited as OPTIONAL in the plan); filter to display class = SPIKE | PROPOSED |
| T11.3 | **Configurable auto-recovery on startup** (re-apply active profile on tray start, gated + verified) | Reuses existing `recover`/`verify` + lkg (OBSERVED); auto-on-startup = new policy (SPIKE: only when user opted in) | PROPOSED |
| T11.4 | **Multiple recovery checkpoints** (not just single lkg): keep last-N verified profiles; `recover <profile>` | Extends `state/` dir (OBSERVED single lkg file) with a history file; schema additive | PROPOSED |
| T11.5 | **Deferred-identity re-validation**: on resume/hotplug, re-run the identity resolver and flag any entry that has become AMBIGUOUS/UNKNOWN | Pure `core/resolver` (OBSERVED, hardware-free); already exists, just wire into new events | PROPOSED |

**Gate:**
- [ ] Sleep → wake: active profile re-verified, correct verdict, user notified if degraded (OBSERVED).
- [ ] Unplug/replug a monitor: tray status updates without a manual Refresh; re-resolve still maps correctly (OBSERVED).
- [ ] Auto-recovery-on-startup, when enabled, re-applies the active profile only after verification OK and never claims full restore when a display is missing (OBSERVED).
- [ ] Acceptance tests **A7** (sleep/wake) and **A8** (hotplug) from the master plan pass (OBSERVED).

**Prereqs / notes:**
- TV lifecycle (E5) is **not observable** on this TV (always-on EDID); T11.2 must be validated on a display that *does* disconnect (a monitor) as the primary proof, with the TV treated as the always-enumerated edge case.
- E3 (driver update) is DEFERRED; T11.5 (re-run resolver on events) is the mitigation that keeps profiles usable after a driver update **even if** the specific E3 evidence is never recorded.

---

### Phase 12 — Diagnostics, observability & CLI polish

**Goal:** Make the app easy to diagnose when something goes wrong and easy to use.
**User value:** When a switch misbehaves, the user (or support) can run one command and get a clear answer, plus readable logs and detailed verification diffs.
**Release it maps to:** v1.3.

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T12.1 | **`--help` / `-h`** (all commands) and **`--version`** (semver) | — (CLI) | PROPOSED |
| T12.2 | **Actionable error messages**: map `Error::*` (e.g., `NoTargets`, `Ambiguous`, `ModeUnavailable`) to human hints ("display X missing — plug it in or remove it from the profile") | Pure mapping over existing `error.rs` (OBSERVED) | PROPOSED |
| T12.3 | **`diagnose` command** (health check, read-only): identity-evidence quality per display, hotkey registration state, autostart state, config sanity, log tail; exit 0/1 | Reads existing state (OBSERVED); no `SetDisplayConfig` (safe) | PROPOSED |
| T12.4 | **Verbose verification**: surface the per-display desired-vs-actual findings (already computed internally as the `finding(s)` count) | Reuses `core/verify` findings (OBSERVED); CLI formatting only | PROPOSED |
| T12.5 | **Log ops**: `logs` subcommand (tail/view), rotation/size cap, level config (`DEBUG/INFO/WARN`) | File ops (OBSERVED log dir); level = config key | PROPOSED |

**Gate:**
- [ ] `--help` lists every command with a one-line description (OBSERVED).
- [ ] `diagnose` exits 0 on a healthy machine, 1 with a specific reason on an unhealthy one; exit codes stable for scripting (OBSERVED).
- [ ] Every `Error` variant produces a distinct, actionable message (OBSERVED via test fixture).
- [ ] `verify --verbose` lists per-display mismatches (resolution/refresh/rotation/position) (OBSERVED).

**Prereqs / notes:**
- Keep `diagnose` **strictly read-only** (D-002 safety invariant): no `SetDisplayConfig` in any diagnostic path.
- Exit-code contract (0 healthy / 1 unhealthy / 2 usage) should be documented and frozen for automation.

---

### Phase 13 — Quality automation (testing, CI matrix, property/fuzz)

**Goal:** Make the codebase maintainable and catch regressions without a live display.
**User value:** Fewer bugs reach users; the identity resolver (the hardest part) is exhaustively property-tested.
**Release it maps to:** v1.3 / ongoing.

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T13.1 | **CI matrix**: Win10 + Win11, debug + release, `cargo test`, `cargo clippy -- -D warnings`, `cargo fmt --check` | **DOCUMENTED** (GitHub Actions `windows-latest`); pure core runs without hardware | PROPOSED |
| T13.2 | **Property-based tests** (`proptest`) for the resolver: reorder, identical units, missing serial, connector change, ambiguity refusal | Pure Rust (OBSERVED core is OS-free); crate `proptest` = **DOCUMENTED** | PROPOSED |
| T13.3 | **Fuzz testing** (`cargo-fuzz`) of the profile JSON parser (schema drift, malformed bytes, huge arrays) | Crate `cargo-fuzz` = **DOCUMENTED**; input = profile bytes (OBSERVED format) | PROPOSED |
| T13.4 | **Integration tests** against recorded fixtures (no live HW needed): capture→save→load→re-resolve round-trip, apply-plan ordering | Reuses existing fixture data from Phases 0–4 (OBSERVED) | PROPOSED |
| T13.5 | **Benchmarks** (`criterion`) for the resolver on large topologies (many sources × targets, e.g., 3-way cross-product) | Crate `criterion` = **DOCUMENTED** | PROPOSED |

**Gate:**
- [ ] CI green across the full matrix (OBSERVED).
- [ ] Resolver property tests pass across the acceptance-test scenarios A1, A4, A5, A9 (OBSERVED).
- [ ] Profile parser fuzzed for N iterations with 0 crashes / no panics on malformed input (OBSERVED).
- [ ] All existing tests still pass (no regression), release build still zero warnings (OBSERVED).

**Prereqs / notes:**
- CI must **not** require a live display: the pure core (`model/`, `core/`) is hardware-free by design (plan §5, §17); only `main.rs`/`windows/` touch Win32.
- This phase is largely **parallel-safe** and can run alongside Phase 10/11 implementation.

---

### Phase 14 — Extensibility & future (lower priority; each sub-feature is its own scope)

**Goal:** New capabilities beyond V1, each independently scoped with its own decision record; **none block release**.
**User value:** Automation, time-based switching, and (if the non-goals are re-opened) audio/multi-PC.
**Release it maps to:** v2.x (only items the user opts into).

| Task | Feature | API / feasibility | Status |
|---|---|---|---|
| T14.1 | **Automation / scripting API**: a small `dis-play api` mode (JSON-RPC over a local named pipe or loopback socket) to apply/verify/list from external tools | Named-pipe or loopback TCP (DOCUMENTED); auth = local-user check only (SPIKE: security review) | PROPOSED |
| T14.2 | **Profile scheduling**: time-based auto-switch (e.g., "Gaming" 18:00–22:00, weekends) | Timer + existing apply path (OBSERVED); persistence of schedule = new config schema (SPIKE) | PROPOSED |
| T14.3 | **Audio switching** (separate subsystem per non-goals): map profile → audio output device | **DOCUMENTED** (`MMDeviceAPI` / WinRT audio); *only if re-opened* as a goal | PROPOSED |
| T14.4 | **Multiple adapters / GPU awareness** (when two GPUs are present) | `QueryDisplayConfig` per adapter (DOCUMENTED); resolver already adapter-aware (OBSERVED) — needs UI to pick | PROPOSED |
| T14.5 | **Multi-PC sync** (per non-goals): only if user explicitly re-opens the non-goal | Network protocol — **UNKNOWN**; security model = SPIKE | PROPOSED |
| T14.6 | **Headless / service mode** (per non-goal): only if re-opened | Service architecture — **UNKNOWN**; would break the "no admin" principle | PROPOSED |

**Gate (per sub-feature, not phase-wide):**
- [ ] Each sub-feature ships only after its own decision record (D-XXX) + OBSERVED/DOCUMENTED gate.
- [ ] Re-opened **non-goals** (audio, sync, service) are explicitly re-approved in `STATUS.md` with a new decision ID before work starts.

**Notes:**
- T14.3 (audio), T14.5 (sync), T14.6 (service) are **non-goals in V1** (`DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3) — they are listed here only as *possible* future scope, not commitments.
- Keep this phase **explicitly deferred** until v1.0 + v1.3 are stable.

---

## 5. Cross-cutting risks & decisions

### 5.1 Risks

| ID | Risk | Mitigation (matches plan §22/§23) |
|---|---|---|
| R1 | Identity permanence (driver update) unproven — **E3 DEFERRED** | T11.5 re-runs the resolver on every power/hotplug event, so profiles stay usable even without E3 evidence; keep E3 on a to-do for when drivers change. |
| R2 | TV lifecycle not observable on this TV (E5) | Validate hotplug (T11.2) on a **monitor** that truly disconnects; treat the TV as the always-enumerated edge case. |
| R3 | Toast/WinRT integration unproven in Rust | T10.2 spike (add `winrt` crate, bind `Windows.UI.Notifications`) before committing to toast as the notification channel; fall back to tray tooltip + log if toasts are unreliable on the user's OS/policy. |
| R4 | Multiple simultaneous hotkeys (T10.5) — conflict/edge behavior unproven | Extend T6.3's conflict handling per-key; validate `ERROR_HOTKEY_ALREADY_REGISTERED` for each key on target HW. |
| R5 | Code-signing (T9.2) depends on an external certificate | Procure a code-sign cert early (external dependency); ship **unsigned** v1.0.0-rc if needed, sign before 1.0.0 final. |
| R6 | CI without a display (T13.x) | Rely on the pure-core being hardware-free by design (plan §5); only the `windows/` FFI layer is skipped in CI. |

### 5.2 Decision tracking

Every new design decision from these phases gets a **Decision ID** (D-131+) recorded in the relevant phase doc and linked from `STATUS.md`, per `AGENTS.md` §"Decision Tracking". Recommended first decisions to reserve:
- D-131: toast notification channel (WinRT vs. tray-only) + opt-out default.
- D-132: hotkey model — replace 2-profile toggle with per-profile hotkeys (schema migration for `hotkeys.json`).
- D-133: auto-recovery-on-startup default (off vs. on) and its verification gate.
- D-134: recovery checkpoint history size / retention.
- D-135: `diagnose` exit-code contract (0/1/2) and read-only guarantee.

### 5.3 What is *not* on this roadmap (explicit)

Per the non-goals (`DIS-PLAY-MASTER_PLAN_REVISION_v2.md` §3), **out of scope** unless re-approved as a new decision:
Game detection, per-game automatic profiles, cloud/multi-PC sync, remote control, GPU-vendor-specific APIs, display calibration, color management, HDR management, **fancy UI** (we stay tray + optional small settings window), Windows **service** architecture, cross-platform.

---

## 6. Suggested sequencing (default plan of action)

```
Now        Phase 9  Release v1.0  (sign + CI + docs)          ← gating: code-sign cert
         └── Phase 13 (CI matrix, property/fuzz)  — parallel, no HW needed
Next       Phase 10 UX (tray mgmt + toasts + hotkeys + settings)   ← highest value
Then       Phase 11 Robustness (sleep/wake + hotplug + recovery)
Then       Phase 12 Diagnostics / CLI polish
Later      Phase 14 Extensibility (opt-in, deferred)
```

**Why this order:**
1. **Ship v1.0 first** (Phase 9) — the current build is complete; getting it signed + documented + CI'd is the highest-leverage, lowest-risk step, and the code-sign cert is the only external dependency (start it now).
2. **Phase 13 in parallel** — it needs no live display (pure core), so it runs alongside Phase 9/10 without blocking them.
3. **Phase 10 is the highest user value** and completes the three missing V1 promises.
4. **Phase 11** makes the app robust to real-world power/hotplug events (the acceptance tests A7/A8).
5. **Phase 12** makes problems diagnosable.
6. **Phase 14** stays deferred until the above are stable.

---

## 7. Maintenance note

- Update this file's "Current state (baseline)" section when `STATUS.md` advances.
- Every feature that becomes `DONE` here should link to the `STATUS.md` decision/decision-id + the `phases/PHASE-N.md` task.
- Keep `PROPOSED` items honest: a feature moves to `PLANNED` only when a `phases/PHASE-N.md` exists with tasks; it moves to `DONE` only with OBSERVED/DOCUMENTED evidence.
