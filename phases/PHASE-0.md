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
- [ ] Identity mapping table captured on real HW (E1). **OBSERVED**
- [ ] Stability verdict: `monitorDevicePath` / instance ID stable across reboot (E2) and driver update (E3). **OBSERVED**
- [ ] Identical-monitor distinguishability answer (E4): by connector/role or only physical position. **OBSERVED**
- [ ] Primary = path-priority confirmed in practice (E6). **OBSERVED**
- [ ] SetDisplayConfig return codes observed for at least one apply + one validate. **OBSERVED**

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

_(Target-HW experiments E1–E6 below remain pending — do not mark complete until gate is met)_

- [ ] Identity table: _pending_
- [ ] Stability verdict: _pending_
- [ ] Identical-monitor answer: _pending_
- [ ] Primary/path-priority observed: _pending_
- [ ] SetDisplayConfig return codes: _pending_

## Follow-up Changes Required (to V2 docs, after evidence lands)
- Update `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` with OBSERVED values.
- If E4 shows connector/role is NOT a stable key → revise binding model in V2 plan §(identity).
- If E6 return codes differ from documented set → annotate findings §8 `[SUPERSEDED by <observed>]`.

## Status
**CLI COMPILES CLEAN + RUNS on this host (non-target HW) — target-HW stability validation PENDING.** Rust toolchain now available; `cargo build --release` succeeds and read-only commands execute (**OBSERVED**). QueryDisplayConfig returns rc=0x57 / empty topology here (**OBSERVED**, non-target host); the meaning of rc=0x57 is **UNKNOWN** pending target-HW interpretation. Gate remains OPEN — no stability OBSERVED yet; none may be invented. Do not advance to Phase 1 until every gate item has an OBSERVED or DOCUMENTED citation from target HW.
