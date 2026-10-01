# Phase 9 — Release v1.0 (finish the current state)

## Objective

Ship a trustworthy v1.0 — **verified, signed, reproducible, documented**.

**User value:** users can install, run, and *trust* the app (no SmartScreen blocks, clear version, stable installer).

**Release it maps to:** v1.0.0.

## Origin (why this phase exists)

All Phases 0–8 are **COMPLETE** (gates HW-validated on the target machine; 56/56 tests, clean release — see `STATUS.md`, `phases/INDEX.md`). The build works end to end; what separates it from a releasable v1.0 is **trust infrastructure, not features**: code-signing, versioning, CI, release documentation, and a clean-launching tray binary.

The last item comes from a real user-reported problem (**OBSERVED** 2026-09-26): when the tray is started from a console window, **closing that `cmd` window kills the tray app**. Root cause confirmed by source review (**OBSERVED**): `dis-play.exe` is a **console** binary (`product/Cargo.toml` has no `subsystem = "windows"`) and `cmd/tray.rs::run()` never calls `SetConsoleCtrlHandler`, so the tray is a console process that dies with its parent console. The user selected **Option B** (a separate GUI-subsystem binary) over Option A (`SetConsoleCtrlHandler` in the one binary) and Option C (a launcher script) — recorded as **D-136**.

## Scope

- **In:** final verification (T9.1); Authenticode code-signing of the release binary + installer (T9.2); versioning + CHANGELOG (T9.3); CI/CD on `windows-latest` (T9.4); README refresh (T9.5); installer polish (T9.6); GUI-subsystem tray binary (T9.7).
- **Out:** tray profile management / toasts / per-profile hotkeys / settings (Phase 10); sleep/wake + hotplug + deeper recovery (Phase 11); diagnostics / CLI polish (Phase 12); quality automation (Phase 13 — parallel-safe, needs no HW); extensibility (Phase 14 — deferred).

## Tasks

| # | Task | Output | Status |
|---|---|---|---|
| T9.1 | Complete final verification: full test suite on target HW (56/56), `validate work`/`work-notv` rc=0, install→run→uninstall on a **clean** Win10/11 machine | clean-machine verification evidence | **IN PROGRESS (partial)** — tests 56/56 done; `validate`/`verify` exit-code fixed (D-137); validation + clean-machine **deferred** (profiles drifted) |
| T9.2 | **Authenticode code-signing** of release binary + installer (`signtool`) with a published cert; verify the signature | signed artifacts + `signtool verify` evidence | **PLANNED** |
| T9.3 | **Versioning:** bump `Cargo.toml` `version`, surface via `--version`, stamp installer metadata, keep a CHANGELOG | versioned release + CHANGELOG | **PLANNED** |
| T9.4 | **CI/CD** (GitHub Actions): build, test, `cargo clippy -- -D warnings`, build installer on `windows-latest` (Win10/11) | CI workflow + green runs | **PLANNED** |
| T9.5 | **README refresh:** all commands, install, troubleshooting, known deferrals (E3, E5), uninstall behavior | updated README | **PLANNED** |
| T9.6 | **Installer polish:** uninstall removes autostart Run key + start-menu shortcut, (optional) user config dir; add file size + version to release notes | polished installer + release notes | **PLANNED** |
| T9.7 | **GUI-subsystem tray binary (Option B):** add a second `[[bin]] name = "dis-play-tray" subsystem = "windows"` with a small entry calling `cmd::tray::run()` — the tray runs with **no console**, so (a) launching from Start-Menu / autostart shows no black window, and (b) closing the parent cmd window no longer kills the tray. Retain `dis-play tray` (console) for compatibility; the T7.2 single-instance guard already prevents both from running at once. Point the Start-Menu shortcut (T9.6) and the autostart Run value (T7.3) at `dis-play-tray.exe`. | `dis-play-tray.exe` (GUI subsystem, no console) + updated launch targets | **PLANNED** |

**API / feasibility notes (from `ROADMAP.md` §4):**
- T9.2 — Authenticode / signtool: **DOCUMENTED** (Authenticode, signtool, Win SDK); *our* cert procurement = **SPIKE** (external dependency R5).
- T9.4 — GitHub Actions `windows-latest`: **DOCUMENTED**; CI does no live-display work (pure core runs without hardware).
- T9.7 — Cargo `subsystem = "windows"`: **DOCUMENTED** (a Windows GUI-subsystem process holds no console); target-HW behavior to be confirmed by the phase gate (**OBSERVED** needed).
- T9.7 caveat: a GUI-subsystem process has **no console**, so `stdout`/`stderr` become no-ops. Acceptable: the tray already surfaces user-facing messages via the tooltip + file logging (T7.1 / D-118); any direct `eprintln!` is effectively silenced (do not rely on it).

## Experiments / Tests (user-run on target HW)

| # | Experiment | What to record |
|---|---|---|
| X9.1 | **Clean machine (T9.1):** install on a fresh Win10/11 → `dis-play-tray` starts (tray icon) → one gated profile apply → `validate` → uninstall → confirm Run key / start-menu shortcut / config dir removed | gate item 2 evidence |
| X9.2 | **No-console + parent-close immunity (T9.7):** launch `dis-play-tray` from a `cmd` window → confirm no console window appears; press Ctrl+C and close the cmd window → tray icon remains in the system tray | gate items 5–6 evidence |
| X9.3 | **Start-Menu + autostart (T9.6/T9.7):** boot with autostart registered (and via the Start-Menu shortcut) → tray icon appears with no console; run `dis-play --version` from cmd → CLI still console, semver printed | gate items 4/6 evidence |

## Gate

Complete only when all of the following are satisfied with at least one OBSERVED or DOCUMENTED item per criterion:

- [ ] Signed binary + installer verified by `signtool verify` / Windows SmartScreen (OBSERVED on clean Win11).
- [ ] Clean-machine install → tray runs → one gated profile apply → uninstall removes autostart (OBSERVED).
- [ ] CI pipeline green: build + test + clippy + installer on `windows-latest` (OBSERVED).
- [ ] `--version` prints a real semver; CHANGELOG present (OBSERVED).
- [ ] `dis-play-tray` launches with **no console window**; closing the parent cmd window (and Ctrl+C) does **not** terminate the tray — it stays in the system tray (OBSERVED on Win11).
- [ ] Start-Menu shortcut and autostart launch `dis-play-tray.exe` with no console window; the CLI `dis-play` binary is unchanged (still a console binary with stdout) (OBSERVED).

## Potential Blockers / Open Questions

- **Code-signing certificate (R5 — main external dependency):** T9.2 requires the user to **procure a cert** (personal code-sign cert or cloud signing service). **Flag early.** Ship `v1.0.0-rc` unsigned if needed; sign before the 1.0.0 final.
- **Do not block release on CI:** if a machine is unavailable, T9.2 signing is the gating item; CI (T9.4) is parallel.
- **Live topology changed (2026-09-30, OBSERVED):** VIE2701 is now **active** and the **TCL9653 TV is absent** (supersedes the "VIE2701 physically absent" note). Current profiles (`all`/`play`/`tv`/`work`) were captured for a different state and now **validate INVALID** — must be re-captured to match the live VIE+SAM topology before T9.1's `validate … rc=0` can be met.

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-136 | The tray ships as a separate Windows **GUI-subsystem** binary (`dis-play-tray.exe`, no console — T9.7, Option B). Start-Menu + autostart launch it; `dis-play tray` (console) is retained for compatibility; the T7.2 single-instance guard prevents both from running at once. (Option B, chosen over Option A — `SetConsoleCtrlHandler` in the single binary — and Option C — launcher script.) | **FINAL** (2026-09-26, user-chose Option B; docs only — no code executed yet) |

## Actual Results

None — no tasks executed yet. Per user instruction (2026-09-26), this session produced documentation only: no new task or phase was executed.

## Status

**PLANNED (not started, 2026-09-26)** — tasks T9.1–T9.7 detailed from `ROADMAP.md` §4; D-136 FINAL (Option B). Next executable step when the user approves: procure the code-signing certificate (T9.2 prereq / R5).
