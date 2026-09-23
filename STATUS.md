# STATUS — DIS-PLAY Operations Dashboard

_Last updated: 2026-09-23_

## Current Phase
**Phase 0 — Evidence Spike (diagnostic CLI)**

## Overall Status
**CLI COMPILES CLEAN + RUNS on this host (non-target HW) — target-HW stability validation PENDING.** Rust toolchain now available (`cargo`/`rustc 1.98.1`); `cargo build --release` succeeds and read-only commands execute (**OBSERVED**). QueryDisplayConfig returns rc=0x57 / empty topology here (**OBSERVED**, non-target host); meaning of rc=0x57 is **UNKNOWN** pending target-HW interpretation. Gate remains OPEN — no stability OBSERVED yet; none may be invented.

## Last Completed Work
- Web validation of all technical claims against MS Learn / Windows SDK headers completed.
- V2 findings + plan updated: SetDisplayConfig flags/return codes, primary = path-priority order, `DISPLAYCONFIG_TARGET_DEVICE_NAME` fields confirmed; raw EDID parsing marked unnecessary.
- `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` created (physical vs connector/role identity analysis).
- Operational structure established: root `AGENTS.md`, this `STATUS.md`, `phases/INDEX.md` + PHASE-0..7 docs, parent `.gitignore` for `product/`.
- **Rust toolchain now available** (`cargo`/`rustc 1.98.1` at `C:\Users\Fotsumi\.cargo\bin`) — unblocks compilation (**OBSERVED**).
- Phase 0 CLI **compiles clean + builds release** on this host; all 5 read-only commands execute (**OBSERVED**).
- Baseline run recorded: QueryDisplayConfig returns rc=0x57 / empty topology on this (non-target) host (**OBSERVED**; meaning UNKNOWN pending target-HW interpretation).

## Current Work
Phase 0 diagnostic CLI **compiles clean + runs** on this host. Read-only commands execute; `dump` shows QueryDisplayConfig rc=0x57 with 0 paths/modes here (**OBSERVED**, non-target HW). Target-HW stability experiments (E1–E6) still pending — user-run only.

## Next Action
1. User runs the SAME read-only commands (`list`/`dump`/`targets`/`pnp`/`identity`) + before/after experiments (reboot, driver update, DP swap, TV power cycle) **on target HW**; record results into PHASE-0.md "Actual Results".
2. Interpret QueryDisplayConfig rc=0x57 on target HW (possibly elevation/console-session access); confirm whether it returns a real topology there.

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
- **Target-HW experiments E1–E6: PENDING** — user-run only; transcribe observed output, do not fabricate.

## Documents Affected by New Findings
- `DIS-PLAY-REVIEW_FINDINGS_v2.md` §7/§8/§9 updated + new §15 sources section.
- `DIS-PLAY-BINDING_SEMANTIC_FINDING.md` created (new).
- V1 files untouched (immutable history).

## Product Implementation Status
CLI source **compiles clean + builds release** in `product/` (12 files). Read-only commands execute on this host (**OBSERVED**); QueryDisplayConfig returns rc=0x57 / empty topology here (non-target HW). `product/.gitignore` already ignores `target/`, `debug/`. Target-HW build + experiments remain.
