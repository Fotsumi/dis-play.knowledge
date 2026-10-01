# Phase 13 — Quality Automation (testing, CI matrix, property/fuzz)

## Objective

Make the codebase maintainable and catch regressions **without a live display**.

**User value:** fewer bugs reach users; the identity resolver (the hardest part) is exhaustively property-tested.

**Release it maps to:** v1.3 / ongoing.

## Origin (why this phase exists)

Gap analysis (`ROADMAP.md` §3, row 11): the project currently has 56/56 unit tests; it needs a CI matrix, property/fuzz, integration, and benchmark coverage. The distinguishing property of this phase: it **needs no live display** — the pure core (`model/`, `core/`) is hardware-free by design (master plan §5, §17); only `main.rs`/`windows/` touch Win32. It is the **only** roadmap phase that can proceed without the target hardware, and is parallel-safe with Phases 9–12.

## Scope

- **In:** CI matrix (T13.1); resolver property tests (T13.2); profile-parser fuzz (T13.3); fixture integration tests (T13.4); resolver benchmarks (T13.5).
- **Out:** live-HW gate items (Phases 9–12); release process (Phase 9); extensibility (Phase 14).

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T13.1 | **CI matrix:** Win10 + Win11, debug + release, `cargo test`, `cargo clippy -- -D warnings`, `cargo fmt --check` | CI workflow (extends T9.4) | **PLANNED** |
| T13.2 | **Property-based tests** (`proptest`) for the resolver: reorder, identical units, missing serial, connector change, ambiguity refusal | proptest suite | **PLANNED** |
| T13.3 | **Fuzz testing** (`cargo-fuzz`) of the profile JSON parser (schema drift, malformed bytes, huge arrays) | fuzz suite + N-iteration report | **PLANNED** |
| T13.4 | **Integration tests** against recorded fixtures (no live HW needed): capture → save → load → re-resolve round-trip, apply-plan ordering | integration tests | **PLANNED** |
| T13.5 | **Benchmarks** (`criterion`) for the resolver on large topologies (many sources × targets, e.g. 3-way cross-product) | benchmark report | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):** T13.1 GitHub Actions `windows-latest` — **DOCUMENTED**; pure core runs without hardware. T13.2 `proptest` — **DOCUMENTED**. T13.3 `cargo-fuzz` — **DOCUMENTED**; inputs = profile bytes (format OBSERVED). T13.4 reuses fixture data from Phases 0–4 (OBSERVED). T13.5 `criterion` — **DOCUMENTED**.

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [ ] CI green across the full matrix (OBSERVED).
- [ ] Resolver property tests pass across the acceptance-test scenarios A1, A4, A5, A9 (OBSERVED).
- [ ] Profile parser fuzzed for N iterations with 0 crashes / no panics on malformed input (OBSERVED).
- [ ] All existing tests still pass (no regression); release build still zero warnings (OBSERVED).

## Potential Blockers / Open Questions

- **CI without a display (R6):** rely on the pure core being hardware-free by design (plan §5); only the `windows/` FFI layer is skipped in CI.
- **Parallelism:** largely parallel-safe — can run alongside Phase 10/11 implementation.
- Win10 + Win11 matrix runners — verify image availability/permissions (CI infrastructure).

## Decisions Produced

None reserved for this phase (`ROADMAP.md` §5.2 reserves D-131–D-136 for Phases 9–12 + the tray decision). New decisions get recorded here as tasks execute.

## Actual Results

None — no tasks executed yet. Per user instruction (2026-09-26), documentation only: no new task or phase was executed.

## Status

**PLANNED (not started, 2026-09-26)** — tasks T13.1–T13.5 detailed from `ROADMAP.md` §4. The only phase that can proceed without the target HW; parallel-safe with Phase 9. No code executed.
