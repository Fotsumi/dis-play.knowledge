# Phase 2 — Capture + Persistence

## Objective
Capture the current display state into a serializable profile and round-trip it through save/load, so `apply_profile` (Phase 3) has something to apply. Finalizes the `DisplayEntry` schema deferred by D-101 (plan §10).

## Scope
- In: capture current topology → `DisplayProfile`; serialize/deserialize (serde JSON); store under `%LOCALAPPDATA%\dis-play\profiles`; round-trip tests.
- Out: applying the profile (Phase 3), verification (Phase 4).

## Tasks
| # | Task | Output |
|---|---|---|
| T2.1 | Capture current state → `DisplayProfile` (one `DisplayEntry` per live candidate, keyed on D-P2 evidence) | `core/capture.rs` |
| T2.2 | Serialize/deserialize (serde) + file I/O under `%LOCALAPPDATA%` | `core/persistence.rs` |
| T2.3 | Round-trip test: capture → save → load → equal | passing tests (`cargo test`) |

## Gate
- [x] Profile round-trips through save/load without loss. **OBSERVED** (unit tests: JSON round-trip + file round-trip + list; and live CLI round-trip on target HW: `profile capture work` → `profile show work` returned identical fields incl. `desired_mode` 2560x1440@320 / 1920x1080@60 / 3840x2160@59.94)
- [x] Schema stable across a reboot (no field drift). **OBSERVED** (target HW, 2026-09-25, user-run): `profile capture pre-reboot` → reboot → `profile capture post-reboot`. Both files parse under `schema_version=1`; `key_evidence` (path prefix + EDID) identical across reboot for all 3 displays; `desired_mode`/`enabled`/`primary` field sets identical. No field drift.

### Reboot procedure (target HW, user-run) — SATISFIED 2026-09-25
```powershell
cd product
cargo run --release -- profile capture pre-reboot     # before reboot
# reboot the machine
cargo run --release -- profile capture post-reboot    # after reboot
cargo run --release -- profile show pre-reboot        # parses cleanly, schema_version=1
cargo run --release -- profile show post-reboot       # parses cleanly, schema_version=1
```
Result (OBSERVED): both `profile show` outputs identical across reboot — VIE2701 2560x1440@320 (rot 0), SAM0D20 1920x1080@60 (rot 270), TCL9653 3840x2160@59.94 (rot 0); `key_evidence` unchanged; `schema_version=1` on both.

## Potential Blockers
- ~~Depends on Phase 1 resolver being correct.~~ **RESOLVED** — Phase 1 gate COMPLETE; capture entries re-resolve uniquely (test `captured_entries_re_resolve_uniquely`).
- `modeInfoIdx` bitfield is **unusable** on this HW (raw union value reads `0x1ffff`/`0x4ffff`/`0x7ffff` — OBSERVED 2026-09-25). Resolved by associating SOURCE modes via `mode.id == path.sourceInfo.id` (D-106).

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-105 | `DisplayEntry.primary` is **`Option<bool>`** (NOT plain `bool`): `None` = not observable at capture. Rationale: changing primary in Windows does NOT change QueryDisplayConfig path order (**OBSERVED** Phase 0), so a captured `primary` value cannot be read through this read path. **REVISES plan §10 provisional `primary: bool`.** | **FINAL** (OBSERVED) |
| D-106 | Mode lookup per path uses **SOURCE mode with `mode.id == path.sourceInfo.id`**; `path.sourceInfo.modeInfoIdx` is a 4-bit bitfield whose raw union value reads as an unusable sentinel on this HW (`0x1ffff`/`0x4ffff`/`0x7ffff` — OBSERVED 2026-09-25), so index-based lookup is not viable. Rotation from `path.targetInfo.rotation`; refresh from `path.targetInfo.refreshRate` rational. | **FINAL** (OBSERVED + DOCUMENTED SDK struct layout) |
| D-107 | Profile storage: pretty JSON at `%LOCALAPPDATA%\dis-play\profiles\<name>.json`; `DisplayProfile` carries `schema_version` (currently `1`) for drift detection (Phase 2 gate). `role` stays `Option<DisplayRole>` and `None` at capture — no stable slot key exists (`connectorInstance` volatile/duplicated, E4). | **FINAL** |

## Actual Results
- T2.1 done: `core/capture.rs` — pure `build_profile(name, candidates)` + `entry_from_candidate()`. No FFI. Each entry keys on D-P2 evidence (`path_prefix` + EDID), `binding_policy` default `Auto`, `role=None`, `primary=None`, `desired_mode` from candidate mode, `enabled` from candidate `connected`.
- T2.2 done: `core/persistence.rs` — `default_profile_dir()` (`%LOCALAPPDATA%`), `save_profile`, `load_profile`, `list_profiles`. Std fs only.
- T2.3 done: 8 new unit tests (4 capture + 4 persistence) alongside the 7 Phase 1 resolver tests = **15/15 pass** (`cargo test` run on this host).
- `model/profile.rs` created: `DisplayProfile` + finalized `DisplayEntry` + `DisplayRole`. `DisplayEntry` moved out of `candidate.rs` (plan §18 layout). `model/candidate.rs` keeps `DisplayCandidate`, `ModeInfo`, `Snapshot`, `BindingPolicy`, `IdentityEvidence` (+`PartialEq` for round-trip equality).
- `windows/display_config.rs` `enumerate_targets()` now fills `mode` per path (D-106). `dump` prints source ids + SOURCE-mode width/height.
- CLI: `profile capture <name>`, `profile list`, `profile show <name>` wired into `main.rs` (read-only — writes profile JSON only, never calls SetDisplayConfig).
- **Live target-HW capture OBSERVED 2026-09-25:** `profile capture work` → `C:\Users\Fotsumi\AppData\Local\dis-play\profiles\work.json`, 3 displays, `desired_mode` = 2560x1440@320Hz (VIE2701), 1920x1080@60Hz rotated 270° (SAM0D20 — portrait), 3840x2160@59.94Hz (TCL9653). `profile show work` round-tripped identical fields.
- **DISCOVERY:** this environment IS the target hardware (VIE2701/SAM0D20/TCL9653 enumerate live here; EDID + raw_target_ids match recorded snapshots). The earlier "this host is not the target hardware" claim is **SUPERSEDED** — the rc=0x57 baseline was the pre-fix QueryDisplayConfig bug on this same machine, not a different machine.
- **Reboot round-trip OBSERVED 2026-09-25 (user-run on target HW):** `profile capture pre-reboot` → reboot → `profile capture post-reboot`. Both parse under `schema_version=1`; `key_evidence` + field set identical across reboot (no drift).

## Status
**COMPLETE.** Both gate items satisfied with OBSERVED citations: round-trip without loss (unit + live) and schema stable across a reboot (user-run pre/post reboot capture). Ready to advance to Phase 3 (Apply — SetDisplayConfig rc=87 investigation).