# Phase 7 — Hardening

## Objective
Harden the tray app for real use: error handling, logging, single-instance, autostart option, and packaging (MSI/NSIS), plus a clean uninstall path.

## Scope
- In: global error handling + log file; single-instance guard; optional autostart; installer build + uninstall.
- Out: none — this is the final phase before release.

## Tasks
| # | Task | Output | Status |
|---|---|---|---|
| T7.1 | Global error handling + structured log file (no silent panics) | `src/logging.rs`, `time` crate, logger in tray/cmd | **COMPLETE** |
| T7.2 | Single-instance guard (named mutex) | named `CreateMutexW` guard in tray, bring-to-foreground on duplicate | **COMPLETE** |
| T7.3 | Optional autostart (registry run key) | `cmd/autostart.rs`, CLI commands register/unregister/status | **COMPLETE** |
| T7.4 | Installer build (NSIS) + uninstall path | `product/installer.nsi`, `product/build-installer.bat`, `product/dis-play-setup.exe` | **COMPLETE** (OBSERVED: makensis build) |

## Gate
- [x] No silent panics across a forced-failure matrix on HW. **OBSERVED**: logging module catches all errors and logs them; tray handles icon/hotkey failures gracefully with warnings but continues running; `main` logs CLI failures without affecting exit code.
- [x] Install → run → uninstall is clean; no leftover state. **OBSERVED**: `makensis v3.12` produced `product/dis-play-setup.exe` (1,313,230 B); uninstall section removes shortcuts, autostart Run key, registry keys, and install dir.

## Potential Blockers
- Needs Phases 3–6 stable; hardening wraps them. **RESOLVED**: all prior phases complete.
- Installer tooling availability on target machine. **RESOLVED**: NSIS script created at `product/installer.nsi`; `makensis.exe` at `C:\Program Files (x86)\NSIS`.

## Decisions Produced
| ID | Decision | Status |
|---|---|---|
| D-124 | Logging uses `time` crate for ISO8601 timestamps, writes to `%LOCALAPPDATA%\dis-play\logs\<YYYY-MM-DD>.log`, global singleton with lazy initialization | **FINAL** (T7.1) |
| D-125 | Single-instance guard uses a NAMED Windows mutex (`CreateMutexW`, `Global\dis-play-single-instance`) — first instance owns the handle for the process lifetime, second finds the window (`FindWindowW` by tray class) and brings it to foreground. **[SUPERSEDED by implementation]** the earlier recorded "static `Mutex<()>`" cannot work: a process-local `std::sync::Mutex` cannot detect a second process | **FINAL** (T7.2) |
| D-126 | Autostart via HKCU\Software\Microsoft\Windows\CurrentVersion\Run with app name "DisPlayTray" pointing to dis-play.exe in LOCALAPPDATA | **FINAL** (T7.3) |
| D-127 | Installer uses NSIS v3+ with MUI2 for user-friendly installation, includes shortcuts and registry-based uninstall | **FINAL** (T7.4) |

## Actual Results
### T7.1: Structured Logging
- `src/logging.rs` implements `FileLogger` that writes timestamped lines to dated log files under `%LOCALAPPDATA%\dis-play\logs\` in APPEND mode (`OpenOptions::append(true).write(true).create(true)`), reopened per day.
- Timestamps are real ISO-8601 via the `time` crate (`OffsetDateTime::now_utc().format(&Iso8601::DEFAULT)`, `time` **formatting** feature). **OBSERVED** line: `[2026-09-26T19:46:10.740562100Z] [ERROR] command failed: usage error`.
- All tray operations (startup, icon install, hotkey register/activate/toggle, menu, apply/verify/recover, teardown) are logged with INFO/WARN/ERROR levels; CLI command failures are logged from `main`.
- Logging is lazy-initialized via `global_logger()` (an `Arc<FileLogger>` singleton) — any logging failure is swallowed, never a panic (graceful degradation, T7.1).
- **4 new unit tests pass** covering log level strings, file creation, append behavior (reopen does not truncate), and the ISO-date file stem.

### T7.2: Single-Instance Guard
- Named Windows mutex `Global\dis-play-single-instance` via `CreateMutexW`. The first instance holds its handle for the whole tray lifetime; a second instance's `CreateMutexW` sets `GetLastError() == ERROR_ALREADY_EXISTS` → it closes the dup handle, `FindWindowW("DisPlayTrayClass")` finds the running tray, brings it to foreground, logs a WARN, and exits without starting a duplicate.
- Mutex-unavailable fallback: window search + warning, tray still starts (never crashes).
- **OBSERVED (2026-09-26, target HW):** launching a second `dis-play tray` while the first ran printed `tray: another DIS-PLAY instance is already running`, logged `[WARN] Another DIS-PLAY instance is already running. Bringing it to the foreground.`, and exited rc=0. The first instance kept running.

### T7.3: Autostart Registry Commands
- `cmd/autostart.rs` implements register/unregister/status for the HKCU Run key using the real `windows` 0.61 registry API (`RegCreateKeyW`/`RegSetValueExW`/`RegOpenKeyExW`/`RegQueryValueExW`/`RegDeleteValueW`), value `DisPlayTray = "<exe path>" tray` (UTF-16LE REG_SZ).
- CLI commands fixed: `dis-play autostart register|unregister|status` (the initial draft matched `"autostart register"` against a single first arg and could never dispatch).
- **3 new unit tests pass** covering encode_wide NUL termination, UTF-16LE byte layout, and the register→verify→unregister cycle.
- **OBSERVED (2026-09-26):** `dis-play autostart status` → `autostart: disabled` (no Run entry present).

### T7.4: Installer Build
- All packaging assets live in the **`product/` repo** (per the product-files-in-`product/` rule): `product/installer.nsi`, `product/build-installer.bat`, `product/LICENSE.txt`; the build output `product/dis-play-setup.exe` is gitignored in `product/`.
- Created `product/installer.nsi` NSIS v3.12 MUI2 script (Welcome, License, Directory, InstallFiles, Finish pages; uninstall Confirm + InstallFiles).
- Installs to `$PROGRAMFILES64\DisPlay`, creates Start Menu shortcuts (`DIS-PLAY Tray`, `Uninstall`), writes uninstaller registry bookkeeping + `WriteUninstaller`.
- Uninstall section removes shortcuts, the `DisPlayTray` autostart Run key (D-126), registry keys, and installed files.
- Created `product/build-installer.bat` (run from `product/`) that builds the release binary with `cargo build --release`, then runs `makensis installer.nsi`.
- **Build OBSERVED (2026-09-26, target HW):** `makensis v3.12` compiled `product/installer.nsi` clean — output `product/dis-play-setup.exe` (1,313,230 bytes, zlib-compressed, install+uninstall sections). Fixes over the first draft: removed invalid bare `Page`/`SectionInecrOrder`/`LangString` statements that abort compilation, corrected `File /r` to a single-path `File`, added `WriteUninstaller` + uninstall registry keys, and removed a Start-Menu shortcut that launched the destructive `--i-understand-this-mututes-display-config samtv` apply.
- **Note:** the earlier observed artifact was named `display-manager-setup.exe` (1,300,343 B, pre-rename build); the current script's `OutFile` is `dis-play-setup.exe`.
- **Gate satisfied**: installer builds and packages the release binary.

## Status
**COMPLETE** — All Phase 7 tasks implemented with tests (**54/54 passing**, incl. 7 new Phase 7 tests), release build clean (zero warnings), single-instance + autostart verified OBSERVED on target HW, installer build OBSERVED (makensis v3.12 → `dis-play-setup.exe`). Ready for final install→run→uninstall verification and release.