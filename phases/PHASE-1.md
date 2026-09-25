# Phase 1 — Identity & Resolver

## Objective
Turn Phase 0 evidence into a pure-Rust identity model + resolver that, given a `binding_policy` (`Auto`/`Physical`/`Connector`) per entry, returns the correct candidate. No Windows calls in this phase's logic (pure functions over captured state).

## Scope
- In: `DisplayEntry` model with `binding_policy`; resolver mapping policy → candidate; unit tests over recorded Phase 0 fixtures.
- Out: persistence, apply, UI (later phases).

## Tasks
| # | Task | Output |
|---|---|---|
| T1.1 | `model/candidate.rs` — DisplayCandidate + DisplayEntry with binding_policy | pure Rust types |
| T1.2 | `core/resolver.rs` — policy → candidate resolution | pure fn, unit-tested |
| T1.3 | Unit tests over Phase 0 captured fixtures (E1–E4 data) | passing tests |

## Gate
- [x] Resolver returns correct candidate for each binding_policy on recorded HW state. **OBSERVED** (unit tests over fixtures transcribed from Phase 0 snapshots; `cargo test` run + passed on this host)
- [x] Unit tests pass; no Windows calls in resolver logic. **DOCUMENTED** (code review: `core/resolver.rs` imports only `model::candidate::*`, pure over `&[DisplayCandidate]` + `&DisplayEntry`; no `windows` crate use)

## Potential Blockers
- ~~Depends on D-P1/D-P2 being FINAL (Phase 0 gate).~~ **RESOLVED** — Phase 0 gate complete; both now FINAL. No blockers remain for Phase 1 execution.

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-P1 | `BindingPolicy { Auto, Physical, Connector }` on `DisplayEntry`, default `Auto`. E4 answered (distinguishable by EDID + path prefix; connector_instance volatile). | **FINAL** (Phase 0 gate complete) |
| D-P2 | Stable per-unit key = **EDID fields (`edid_manufacture_id` + `edid_product_code_id`) + `monitor_device_path` PREFIX**. OBSERVED stable across reboots + DP moves on target HW. raw_target_id/connector_instance NOT keys (volatile). | **FINAL** (OBSERVED) |
| D-101 | `DisplayEntry` minimal shape = `{ key_evidence: IdentityEvidence, binding_policy }`. Remaining fields (`role`, `desired_mode`, `primary`, `enabled`) deferred to Phase 2 with persistence. Rationale: keep Phase 1 scope to resolution; schema finalization is Phase 2's job (plan §10 "provisional schema"). | **FINAL** |
| D-102 | `IdentityEvidence` = `{ path_prefix: Option<String>, edid_manufacture_id: Option<u32>, edid_product_code_id: Option<u32> }`. All fields optional; matching requires equality on all present fields. Rationale: D-P2 stable key set (OBSERVED). | **FINAL** |
| D-103 | Resolution semantics per policy — PHYSICAL match = all present `key_evidence` fields equal candidate's values → UNIQUE/UNKNOWN/AMBIGUOUS; CONNECTOR on distinguishable HW = same candidates as PHYSICAL but honored=CONNECTOR (collapse principle); identical units (>1 match) → AMBIGUOUS with slot disambiguation needed (D-101 deferral). Auto: distinct units → honored=PHYSICAL; identical units → honored=CONNECTOR. | **FINAL** |
| D-104 | Resolution contract = `Unique(Match{candidate, honored})` / `Ambiguous(Ambiguity{candidates, honored})` / `Unknown`. Honored carried in ALL outcomes (finding doc L57: "resolver output must carry a per-entry honored binding so any swap/degradation is visible"). Refines prior sketch (`Ambiguous(Vec<DisplayCandidate>)`) to satisfy that requirement. | **FINAL** |

## Actual Results
- T1.1 done: `model/candidate.rs` extended with `BindingPolicy` (serde default=Auto), `IdentityEvidence`, `DisplayEntry`, + `path_prefix()` helper on `DisplayCandidate` (encodes D-P2 stable-key rule: split on '#', keep first two segments + trailing '#').
- T1.2 done: `core/resolver.rs` created — pure `resolve(candidates, entry) -> Resolution` with `HonoredBinding`, `Match`, `Ambiguity`, `Resolution`. No Windows calls (imports only `model::candidate::*`).
- T1.3 done: 7 unit tests over fixtures transcribed from Phase 0 snapshots (VIE2701=9561/9985, SAM0D20=11596/3360, TCL9653=27728/38483 — OBSERVED) + synthetic identical-unit divergence case. All pass (`cargo test` run on this host).
- `mod core;` wired into `main.rs`; `core/mod.rs` declares `pub mod resolver`.

**Note (expected, not a defect):** `cargo build --release` emits dead-code warnings for `core::resolver::*` + the new model types because nothing in `main()` reads them yet — wiring lands with apply/verification commands in later phases. Tests exercise everything (so `cargo test` is clean). This is honest for Phase 1 scope: the resolver is a pure module, not yet part of a user-facing flow.

## Status
**COMPLETE.** Both gate items satisfied with OBSERVED + DOCUMENTED citations. Ready to advance to Phase 2 (Persistence & Profile Schema).
