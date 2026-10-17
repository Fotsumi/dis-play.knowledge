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
| T13.1 | **CI matrix:** Win10 + Win11, debug + release, `cargo test`, `cargo clippy -- -D warnings`, `cargo fmt --check` | CI workflow (extends T9.4) | **COMPLETE** |
| T13.2 | **Property-based tests** (`proptest`) for the resolver: reorder, identical units, missing serial, connector change, ambiguity refusal | proptest suite | **COMPLETE** |
| T13.3 | **Fuzz testing** (`cargo-fuzz`) of the profile JSON parser (schema drift, malformed bytes, huge arrays) | fuzz suite + N-iteration report | **COMPLETE** |
| T13.4 | **Integration tests** against recorded fixtures (no live HW needed): capture → save → load → re-resolve round-trip, apply-plan ordering | integration tests | **COMPLETE** |
| T13.5 | **Benchmarks** (`criterion`) for the resolver on large topologies (many sources × targets, e.g. 3-way cross-product) | benchmark report | **COMPLETE** |

**API / feasibility notes (from `ROADMAP.md` §4):** T13.1 GitHub Actions `windows-latest` — **DOCUMENTED**; pure core runs without hardware. T13.2 `proptest` — **DOCUMENTED**. T13.3 `cargo-fuzz` — **DOCUMENTED**; inputs = profile bytes (format OBSERVED). T13.4 reuses fixture data from Phases 0–4 (OBSERVED). T13.5 `criterion` — **DOCUMENTED**.

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [x] CI green across the full matrix (OBSERVED).
- [x] Resolver property tests pass across the acceptance-test scenarios A1, A4, A5, A9 (OBSERVED).
- [x] Profile parser fuzzed for N iterations with 0 crashes / no panics on malformed input (OBSERVED).
- [x] All existing tests still pass (no regression); release build still zero warnings (OBSERVED).

## Potential Blockers / Open Questions

- **CI without a display (R6):** rely on the pure core being hardware-free by design (plan §5); only the `windows/` FFI layer is skipped in CI. **RESOLVED** — the matrix runs the full suite (149 unit + 12 new) on all cells.
- **Parallelism:** largely parallel-safe — can run alongside Phase 10/11 implementation.
- Win10 + Win11 matrix runners — verify image availability/permissions (CI infrastructure). **RESOLVED with a mapping note:** GitHub-hosted runners are Windows *Server* images (no Win10/Win11 client runner). `windows-2022` (Server 2022, kernel 10.0.20348) stands in for the Win10 generation and `windows-2025` (Server 2025, kernel 10.0.26100) for the Win11 generation; both are available and green.

## Decisions Produced

None new for this phase. The only recorded design choice is the **CI runner mapping** (documented above and in a comment in `.github/workflows/ci.yml`): GitHub-hosted infrastructure offers no Win10/Win11 client runners, so the closest Server images (`windows-2022` / `windows-2025`) are used. No `D-XXX` is warranted (no product behavior, schema, or API decision is involved).

## Actual Results

All five tasks implemented + verified (2026-10-17). Product repo commits: **T13.1** `0b6a58e`, **T13.2** `4c6a84b`, **T13.3** `33b8109`, **T13.4** `bcfa616`, **T13.5** `9375d5a`, CHANGELOG `a16fa19`.

- **T13.1 — CI quality matrix (OBSERVED).** `.github/workflows/ci.yml` replaced with a matrix job `quality` over `os ∈ {windows-2022, windows-2025}` × `profile ∈ {debug, release}` (5 jobs total incl. a separate `package` job that still builds the NSIS installer + uploads artifacts), each cell running `cargo fmt --all -- --check`, `cargo build`, `cargo test`, and `cargo clippy --all-targets --all-features $flags -- -D warnings` (toolchain pinned 1.98.1 + `clippy, rustfmt`). To satisfy `fmt --check` the whole source tree was rustfmt-normalized (`cargo fmt --all`, 30 files; formatting-only). **OBSERVED:** the full matrix is green — CI run `38979760983` (T13.1) and `38984784843` (final, all tasks): `windows-2022 · debug`, `windows-2022 · release`, `windows-2025 · debug`, `windows-2025 · release`, `Installer (windows-latest)` all `success`.
- **T13.2 — resolver property tests (OBSERVED).** `[dev-dependencies] proptest = "1"` + new `product/tests/resolver_props.rs` (7 properties, 256 cases each) with an **independent match oracle** (not a re-call of `resolve`): `resolve_matches_manual_expectation` (core 0/1/>1-match contract + honored labels), `a1_reorder_does_not_change_outcome`, `a4_identical_units_are_always_ambiguous`, `a5_edid_only_evidence_resolves_unique_when_edid_pair_unique`, `a5_all_absent_evidence_is_unknown`, `a9_physical_unit_follows_across_connector_change`, `a9_stale_path_prefix_is_unknown`. **OBSERVED:** `cargo test --release --test resolver_props` → 7 passed; full suite 156; no counterexamples (the resolver's documented semantics — D-103/D-104 — held).
- **T13.3 — parser fuzzing (OBSERVED).** New `product/fuzz/` cargo-fuzz crate (own `[workspace]`, gitignored `target/corpus/artifacts/coverage`): `fuzz_targets/profile_parse.rs` feeds arbitrary bytes to `serde_json::from_slice::<DisplayProfile>`; `.gitignore` + seed corpus (valid/truncated/wrong-type JSON). cargo-fuzz **0.13.2**. **OBSERVED:** `cargo +nightly fuzz run profile_parse -- -runs=100000 -max_len=8192` → `Done 100000 runs`, **0 crashes / 0 panics** (`fuzz/artifacts/profile_parse/` empty), coverage `1086` counters / `2348` features. Windows note: the default ASan build links but needs the MSVC ASan runtime DLL on `PATH` (`...\VC\Tools\MSVC\*\bin\Hostx64\x64`); `--sanitizer none` does **not** link here (unresolved `__start___sancov_*`).
- **T13.4 — fixture integration tests (OBSERVED).** New `product/tests/fixtures/{work,work-notv,samtv}.json` (recorded Phase 0/2/4 data: VIE2701 9561/9985, SAM0D20 11596/3360, TCL9653 27728/38483, with the captured modes incl. SAM portrait `rot=270` `pos=[-1080,0]`) + `product/tests/fixture_roundtrip.rs` (5 tests): `recorded_fixture_files_load_and_re_resolve`, `capture_save_load_re_resolve_round_trip` (`build_profile` → `save_profile` → `load_profile` equality + resolve), `apply_plan_preserves_recorded_profile_order`, `disabled_tv_entry_is_skipped_in_plan` (A3 subset), `legacy_fixture_without_optional_fields_parses` (schema-drift tolerance). **OBSERVED:** `cargo test --release --test fixture_roundtrip` → 5 passed.
- **T13.5 — resolver benchmarks (OBSERVED).** `[dev-dependencies] criterion = "0.5"` (0.5.1) + `[[bench]] name = "resolver" harness = false` + `product/benches/resolver.rs` (`resolve_unique_large`, `resolve_all_large`, `resolve_ambiguous`, `resolve_unknown`, `plan_from_profile_large` over a 256-display cross-product) + committed `product/benches/RESULTS.md` report. **OBSERVED (this host):** `cargo bench --bench resolver` completed; e.g. `resolve_unique_large` ≈ 794 ns, `resolve_unknown` ≈ 534 ns, `resolve_ambiguous` ≈ 20.3 µs, `resolve_all_large` ≈ 48.9 µs, `plan_from_profile_large` ≈ 51.6 µs.
- **Regression check (OBSERVED, CI).** Every matrix cell reports **161 passed / 0 failed** (149 lib + 5 fixture_roundtrip + 7 resolver_props); `cargo build --release` zero warnings; clippy `-D warnings` clean; `cargo fmt --all -- --check` clean.

## Status

**COMPLETE (2026-10-17).** All five tasks (T13.1–T13.5) implemented and verified; all four gate criteria satisfied with OBSERVED evidence (CI run `38984784843` green across the full matrix; property tests A1/A4/A5/A9 pass; 100 000-run parser fuzz with 0 crashes; 161/161 tests + zero-warning release build). No new decisions. Parallel-safe phase closed; Phase 9 remains open only for T9.2 signing (blocked on R5) and Phase 11's gate remains user-run on live HW.
