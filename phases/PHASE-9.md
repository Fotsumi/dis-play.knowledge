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
| T9.1 | Complete final verification: full test suite on target HW (56/56), `validate work`/`work-notv` rc=0, install→run→uninstall on a **clean** Win10/11 machine | clean-machine verification evidence | **COMPLETE (2026-10-15)** — target-HW (OBSERVED): `cargo test --release` 57/57; live topology VIE2701+SAM0D20 active / TCL9653 absent; `validate work`/`all`/`play`/`tv` all rc=0; `verify work` → OK (2/2 active, TV-absent entry skipped) rc=0. `work-notv` no longer exists (profile set renamed to all/play/tv/work; `work` already carries TV-disabled = the old `work-notv` semantics). Clean-machine (OBSERVED 2026-10-15, user-run, separate clean Win10/11): install → tray icon appeared → one gated profile apply = verification OK → `validate` rc=0 → uninstall removed Start-Menu shortcut + Run-key autostart; `%LOCALAPPDATA%\dis-play` config dir **persisted** (config removal is optional per T9.6) |
| T9.2 | **Authenticode code-signing** of release binary + installer (`signtool`) with a published cert; verify the signature | signed artifacts + `signtool verify` evidence | **IN PROGRESS (pipeline built + tested 2026-10-15; production signing BLOCKED on R5)** — `product/sign-release.bat` (SHA-256 + RFC 3161 timestamp + `signtool verify`) OBSERVED working with a temporary self-signed CodeSigning cert: both artifacts "Successfully signed", `verify /v` shows primary signature + DigiCert TSA timestamp; sole error = test-root-not-trusted (inherent to a self-signed test cert; a production CA cert chains to a public root by design). No production code-signing cert on the machine (OBSERVED — see R5) |
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

- **Code-signing certificate (R5 — main external dependency):** T9.2 requires the user to **procure a cert** (personal code-sign cert or cloud signing service). **Flag early.** Ship `v1.0.0-rc` unsigned if needed; sign before the 1.0.0 final. **[CONFIRMED BLOCKED 2026-10-15, OBSERVED]:** no code-signing cert on the target machine — user store holds only 5 self-signed dev certs (none with the Code Signing EKU `1.3.6.1.5.5.7.3.3`), no PFX/CER in the project dirs or user profile; `signtool` IS present (Windows SDK 10.0.26100.0, `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64`). The signing pipeline (`sign-release.bat`) is ready — production signing is a one-shot re-run once the cert arrives.
- **Do not block release on CI:** if a machine is unavailable, T9.2 signing is the gating item; CI (T9.4) is parallel.
- **Live topology changed (2026-09-30, OBSERVED):** VIE2701 is now **active** and the **TCL9653 TV is absent** (supersedes the "VIE2701 physically absent" note). Current profiles (`all`/`play`/`tv`/`work`) were captured for a different state and now **validate INVALID** — must be re-captured to match the live VIE+SAM topology before T9.1's `validate … rc=0` can be met. **[RESOLVED 2026-10-15, OBSERVED]:** the live topology is VIE2701+SAM0D20 active / TCL9653 absent; all four saved profiles (`all`/`play`/`tv`/`work`) now **validate rc=0** and `verify work` → OK. No re-capture was needed — the profiles already match the live VIE+SAM topology (TV entry is disabled in `work`, so its physical absence is a correctly-skipped entry, not a mismatch). T9.1's `validate … rc=0` is met.

## Decisions Produced

| ID | Decision | Status |
|---|---|---|
| D-136 | The tray ships as a separate Windows **GUI-subsystem** binary (`dis-play-tray.exe`, no console — T9.7, Option B). Start-Menu + autostart launch it; `dis-play tray` (console) is retained for compatibility; the T7.2 single-instance guard prevents both from running at once. (Option B, chosen over Option A — `SetConsoleCtrlHandler` in the single binary — and Option C — launcher script.) | **FINAL** (2026-09-26, user-chose Option B; docs only — no code executed yet) |

## Actual Results

- **T9.1 target-HW verification (2026-10-15, this host = target HW, OBSERVED):** `cargo build --release` clean; `cargo test --release` → **57/57 pass** (was 56/56 before D-137's `sole_target_position_normalized_to_origin` test). Live topology via `list`/`targets`/`identity`: **VIE2701 (2560x1440@320) + SAM0D20 (1920x1080@60) active, TCL9653 TV absent** — matches the 2026-09-30 topology-change note. `validate work` → rc=0; `validate all`/`play`/`tv` → rc=0 (all four saved profiles VALID, no mutation); `verify work` → **OK** (2 intended enabled targets, 2 active, TV-absent entry skipped as not-verifiable) rc=0. `work-notv` no longer exists — the profile set was renamed to `all`/`play`/`tv`/`work` in Phase 8 and `work` already carries the TV disabled (the old `work-notv` semantics).
- **T9.2 signing pipeline built + tested (2026-10-15, target HW, OBSERVED):** `product/sign-release.bat` created (flat `goto` batch — parenthesized `if`/`for` blocks break when a var inside expands to a `Program Files (x86)` path, so none are used). It signs `target\release\dis-play.exe` + `dis-play-setup.exe` with `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256` (cert = `/a` auto | `/sha1 <thumbprint>` | `/f <pfx> /p <password>`), then `signtool verify /v` on both. Baseline: both release artifacts **unsigned** (`verify` → "No signature found", rc=1). Pipeline test with a temporary self-signed CodeSigning cert (EKU `1.3.6.1.5.5.7.3.3`, 30-day, user store, removed after): both artifacts **"Successfully signed"**; `verify /v` → primary signature + file SHA256 + **timestamped (RFC 3161) by a DigiCert TSA** whose chain verified to DigiCert Assured ID Root CA; `verify` exits 1 with the sole error *"root certificate not trusted"* — inherent to the self-signed test cert (adding it to the Trusted Root store is blocked in this environment — the consent UI hangs; the TrustedPeople store is not honored by the Authenticode chain policy). A production CA-issued cert chains to a public root, so a full `verify` pass is expected by design. `product/README.md` gained a "Signing" section. **Remaining:** procure the production cert (R5) → re-run `sign-release.bat` with it → full `signtool verify` pass = T9.2 complete.
- **T9.1 clean-machine verification (2026-10-15, user-run on a separate clean Win10/11, OBSERVED):** installed `product\dis-play-setup.exe` (1,322,339 B) on the fresh machine → launched the tray → **tray icon appeared** in the system tray → applied one profile from the tray menu → **verification OK** → `validate` from the console → **rc=0 / VALID** → uninstalled → **Start-Menu shortcut removed + Run-key autostart value removed**; the `%LOCALAPPDATA%\dis-play` config dir **persisted** (config-dir removal is the optional part of T9.6, not part of T9.1's gate). Satisfies gate item 2 (clean-machine install → tray runs → one gated apply → uninstall removes autostart).

## Status

**T9.1 COMPLETE (2026-10-15).** Target-HW verification OBSERVED: 57/57 tests, live topology VIE+SAM (TV absent), all four profiles `validate` rc=0, `verify work` OK. Clean-machine install→tray→gated apply→validate rc=0→uninstall (X9.1) OBSERVED user-run on a separate clean Win10/11 (uninstall removed Start-Menu shortcut + Run-key autostart; config dir persisted — optional per T9.6). Gate item 2 satisfied.
**T9.2 IN PROGRESS (2026-10-15):** signing pipeline `product/sign-release.bat` built + OBSERVED-tested (self-signed test cert: both artifacts signed, RFC 3161 DigiCert timestamp, `verify` passes except the inherent self-signed-root-not-trusted error). **BLOCKED on R5** — no production code-signing cert on the machine (OBSERVED). When the cert arrives: run `sign-release.bat` with it → full `signtool verify` pass → T9.2 complete. T9.3–T9.7 still PLANNED; D-136 FINAL (Option B). Next executable step: **procure the code-signing certificate (R5)** — external dependency, user action.
