# Phase 10 — On-Hardware Verification Checklist (user-run)

**Purpose:** the Phase-10 implementation is complete and its build/test evidence is **OBSERVED** (109/109 tests, clippy clean). The phase **gate** additionally requires **OBSERVED** items that only a human running the tray on the target Windows machine can produce. This file is the exact script for producing those items. Do not mark a gate criterion satisfied until its step here is recorded as **OBSERVED**.

**Related:** `phases/PHASE-10.md` (tasks, gate, X10.1/X10.2), `STATUS.md` (dashboard).

**Evidence rule:** every result you record must be labelled **OBSERVED** (you saw it happen) — not inferred. Record the actual text you see (menu label, toast text, log line, file contents), not a paraphrase.

---

## 0. Preconditions

- [ ] **P0.1** You are on the target hardware (VIE2701 / SAM0D20 / TCL9653 or the current live set). `dis-play list` returns at least one active display.
- [ ] **P0.2** At least two saved profiles exist, so switches and Undo have something to act on:
      ```powershell
      & "$env:USERPROFILE\.cargo\bin\cargo.exe" run --release -- profile list
      ```
      (If fewer than two, capture one: `... -- profile capture scratch-a`.)
- [ ] **P0.3** Note the config locations you will inspect:
      - Profiles:   `%LOCALAPPDATA%\dis-play\profiles\*.json`
      - State:      `%LOCALAPPDATA%\dis-play\state\last-known-good.json`
      - Settings:   `%LOCALAPPDATA%\dis-play\config\settings.json`
      - Hotkeys:    `%LOCALAPPDATA%\dis-play\config\hotkeys.json`
      - Logs:       `%LOCALAPPDATA%\dis-play\logs\<YYYY-MM-DD>.log`
- [ ] **P0.4** Back up your config dir before the destructive steps (delete is permanent):
      ```powershell
      Copy-Item "$env:LOCALAPPDATA\dis-play" "$env:TEMP\dis-play-backup-$(Get-Date -f yyyyMMdd-HHmmss)" -Recurse
      ```

Open the live log in a second window so you can watch lines appear as you click:
```powershell
Get-Content "$env:LOCALAPPDATA\dis-play\logs\$(Get-Date -f yyyy-MM-dd).log" -Wait -Tail 20
```

---

## 1. Launch the tray

- [ ] **U1.1** Start the GUI tray binary (no console window):
      ```powershell
      Start-Process "D:\NetDev\dis-play.knowledge\product\target\release\dis-play-tray.exe"
      ```
      (Or the installed copy: `& "C:\Program Files\DIS-PLAY\dis-play-tray.exe"`.)
      **Expect:** the tray icon appears; **no** console window opens; the log gains
      `DIS-PLAY tray app starting` + `Tray icon installed`.
- [ ] **U1.2** Hover the icon. **Expect** a tooltip whose first line is `active: '<name>' — verification <status>` (or `active: (none) — apply a profile to set one`).

**Menu map** (click the icon to verify it matches): a greyed status line, then one
**submenu per profile** (`Apply` / `Rename…` / `Duplicate…` / `Delete` / `Set hotkey…`),
then `Save Current Configuration…`, `Verify live topology`, `Recover last-known-good`,
`Refresh profiles`, then `Recent switches ▸`, `Settings ▸`, then `Exit`.

---

## 2. Gate item 1 — profile management from the tray + persistence

> Criterion: *User can Save Current / rename / delete / duplicate profiles entirely from the tray; state persists across restarts.*

### 2a. Save Current (T10.1)
- [ ] **G1.1** Menu → `Save Current Configuration…`. A modal dialog appears with a
      preselected suggested name `display-YYYYMMDD-HHMMSS`.
- [ ] **G1.2** Type a name (e.g. `hw-check`) → **Enter**.
      **Expect:** status line/toast `saved 'hw-check' (N display(s)) to <path>`, and a new
      `%LOCALAPPDATA%\dis-play\profiles\hw-check.json` exists. Confirm the file appeared:
      ```powershell
      Get-Item "$env:LOCALAPPDATA\dis-play\profiles\hw-check.json" | Select-Object FullName,Length
      ```
- [ ] **G1.3** Cancel path: reopen `Save Current Configuration…`, press **Escape** →
      status `save: cancelled`; no new file.

### 2b. Rename (T10.3)
- [ ] **G1.4** Open profile `hw-check` submenu → `Rename…` → enter `hw-check-2` → **Enter**.
      **Expect:** `renamed 'hw-check' -> 'hw-check-2'`; `hw-check.json` gone, `hw-check-2.json` present.
- [ ] **G1.5** Reference-integrity check (the rename spike): if `hw-check` had a hotkey
      binding, confirm `config\hotkeys.json` now says `hw-check-2` (see §4 for adding one first).

### 2c. Duplicate (T10.3)
- [ ] **G1.6** Open `hw-check-2` submenu → `Duplicate…` (prefilled `<name>-copy`) → accept.
      **Expect:** `duplicated 'hw-check-2' as 'hw-check-2-copy'`; the source is untouched.

### 2d. Delete (T10.3)
- [ ] **G1.7** Open `hw-check-2-copy` submenu → `Delete` → a Yes/No `MessageBox` appears →
      choose **No** → `delete: cancelled`, file still present.
- [ ] **G1.8** Repeat → choose **Yes** → `deleted profile 'hw-check-2-copy'`; file removed.

### 2e. Persistence across restart
- [ ] **G1.9** Menu → `Refresh profiles`: `hw-check-2` is listed, `hw-check-2-copy` is gone.
- [ ] **G1.10** Menu → `Exit`, then relaunch the tray (§1).
      **Expect:** the profile set is identical — the created/renamed profiles survived the restart.

**Record (OBSERVED):** names created/renamed/deleted, the exact status strings, and the
`profiles\` directory listing before/after restart.

---

## 3. Gate item 2 — toasts + opt-out (X10.1)

> Criterion: *Every switch (success / PARTIAL / failure) shows a dismissable toast; opt-out is respected (OBSERVED on target HW).*

- [ ] **G2.1 Success** — apply a profile that fully matches live (e.g. the profile currently
      in effect). **Expect** an **info** toast titled `DIS-PLAY` (e.g. `Applied '<name>'`),
      dismissable from the Action Center, and status `verification OK`.
- [ ] **G2.2 PARTIAL** — apply a profile whose target is present but not in the captured
      mode (or re-use an existing PARTIAL fixture). **Expect** a **warning** toast
      (`verification PARTIAL`) with the finding count.
- [ ] **G2.3 Failure** — trigger a failing apply (e.g. a profile with no resolvable
      targets). **Expect** an **error** toast (`apply failed`, mentions `SetDisplayConfig rc=…`);
      last-known-good is **not** updated.
- [ ] **G2.4 Quiet hours / policy** — note whether the OS suppresses toasts (enterprise
      policy / Focus Assist). Record the behavior; the tooltip + log remain the fallback.

### Opt-out
- [ ] **G2.5** Menu → `Settings ▸ Notifications: on` (click to turn **off**).
      **Expect** status `settings: notifications off` and `settings.json` → `"toasts": false`:
      ```powershell
      Get-Content "$env:LOCALAPPDATA\dis-play\config\settings.json"
      ```
- [ ] **G2.6** Apply a profile again. **Expect no toast**, but the status line still updates
      and the log still records `toast ...`/apply lines.
- [ ] **G2.7** `Settings ▸ Notifications: off` → click to turn back **on**; verify a toast reappears.

**Record (OBSERVED):** the three toast outcomes (kind + text), the quiet-hours/policy note,
and the `"toasts"` value flipping.

---

## 4. Gate item 3 — per-profile hotkeys + conflicts (X10.2)

> Criterion: *Each profile can bind its own hotkey; conflicts are detected and surfaced; `ERROR_HOTKEY_ALREADY_REGISTERED` per-key handled (OBSERVED).*

### 4a. Bind by pressing (T10.6)
- [ ] **G3.1** Open profile A's submenu → `Set hotkey…`. The capture dialog appears with a
      hint. Press a combo, e.g. **Ctrl+Alt+W**.
      **Expect:** dialog closes; status `hotkey '<profile A>' -> Ctrl+Alt+W` (or similar);
      the submenu item now reads `Set hotkey…  [Ctrl+Alt+W]`; `config\hotkeys.json` gains a
      `bindings` entry; log records the registration.
- [ ] **G3.2** Repeat for profile B with **Ctrl+Alt+G**.
- [ ] **G3.3** Fire **Ctrl+Alt+W** from any app. **Expect:** profile A applies (+ toast +
      `active:` updates). Fire **Ctrl+Alt+G** → profile B applies.

### 4b. Config-level conflict
- [ ] **G3.4** `Set hotkey…` on profile B and press **Ctrl+Alt+W** (already bound to A).
      **Expect** a conflict message (tooltip + toast), the saved config is **unchanged**, and
      B keeps `Ctrl+Alt+G`.
- [ ] **G3.5** `Set hotkey…` on a profile and press the built-in **Ctrl+Alt+D** toggle →
      conflict reported (it is reserved), config unchanged.

### 4c. OS-level conflict (`ERROR_HOTKEY_ALREADY_REGISTERED`)
- [ ] **G3.6** Claim a combo in another app first (or use the same combo already owned by
      another running process), then `Set hotkey…` it for a profile. **Expect** the app does
      **not** crash; the per-key conflict is surfaced and **other** bindings keep working.
- [ ] **G3.7** Clear a binding: `Set hotkey…` then press **Delete** → binding removed
      (`Set hotkey…` shows the no-combo label); the profile still applies from the menu.

**Record (OBSERVED):** each combo, the fire result, the two conflict messages, and that
`hotkeys.json` is written/updated without corruption.

---

## 5. Gate item 4 — settings persist + take effect on restart (T10.7)

> Criterion: *Settings (autostart, default profile, log level, toast on/off) persist and take effect on restart (OBSERVED).*

### 5a. Set each value
- [ ] **G4.1 Log level** — `Settings ▸ Log level` → pick **Error**. **Expect** a check next
      to `Error`; `settings.json` → `"log_level": "error"`; the running log **immediately**
      stops writing `INFO` lines (cause an INFO event, e.g. `Refresh profiles`, and confirm no
      new INFO line appears).
- [ ] **G4.2 Default profile** — `Settings ▸ Default profile` → pick profile A. **Expect** a
      check next to A; `settings.json` → `"default_profile": "A"`.
- [ ] **G4.3 Autostart** — `Settings ▸ Start with Windows: disabled` → click to enable.
      **Expect** `settings: start with Windows enabled` and the Run key set (the label reads
      from the live registry, so it flips even if `settings.json` and the registry disagree).
      Confirm:
      ```powershell
      Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name DisPlayTray -ErrorAction SilentlyContinue
      ```
      Note the documented prerequisite: the Run value points at
      `%LOCALAPPDATA%\dis-play-tray.exe`, so `registration` succeeds only when that copy exists
      (the tray reports a clear message otherwise — record whichever you see).
- [ ] **G4.4 Notifications** — leave it at your chosen state (from §3).

### 5b. Restart + confirm (the real test)
- [ ] **G4.5** Menu → `Exit`, then relaunch (§1). **Expect:**
      - The **default profile (A) is applied on startup** (log: `Settings: applying default
        profile 'A' on startup`; the `active:` tooltip becomes `A`; no menu click needed).
      - The **log level is honored from the first line** (no INFO lines at startup when set to Error).
      - `Settings ▸` reflects the persisted **Notifications** / **Default profile** / **Log level**
        values (checks in the right places).
- [ ] **G4.6** Negative path: set `Default profile → (none)`, restart → no default apply, and
      the tray falls back to whatever last-known-good is (or none).

**Record (OBSERVED):** the `settings.json` contents after each change, the startup log lines,
the post-restart `active:` value, and the log-level effect.

---

## 6. Supporting checks (not gate items, but cheap)

### T10.4 — active-profile indicator
- [ ] **S1** After an apply, open the menu: the active profile's submenu **and** its `Apply`
      child show a **checkmark**; the greyed status line reads `active: '<name>' — verification <status>`.
- [ ] **S2** `Verify live topology` updates the status line; the tooltip also names the active profile.

### T10.8 — Recent switches + Undo
- [ ] **S3** From a known start (lkg = X), apply A then B.
      Open `Recent switches ▸` → expect **B** (newest) then **A**; `Undo — re-apply 'A'` at top.
- [ ] **S4** Click `Undo — re-apply 'A'`. **Expect:** A applies (+ toast), and `active:` becomes A
      (the list reorders so A is now newest).
- [ ] **S5** With no prior switch on a fresh start, the item reads `Undo (no previous switch)`
      and is harmless if clicked (`undo: no previous switch to undo`).
- [ ] **S6** Bounded history: apply 6+ distinct profiles; `Recent switches` lists at most **5**.

---

## 7. Evidence capture

Paste the raw strings you saw (not summaries). One block per gate item:

```
Gate item 1 (profile mgmt)   OBSERVED <date>:
  save    : status/toast = "..."   file = %LOCALAPPDATA%\dis-play\profiles\<...>.json (Length=...)
  rename  : "..."  | hotkeys.json after = "..."
  dup     : "..."
  delete  : No -> "..."  |  Yes -> "..."
  restart : profiles after relaunch = [ ... ]

Gate item 2 (toasts / X10.1) OBSERVED <date>:
  success : toast kind = info   text = "..."
  PARTIAL : toast kind = warning text = "..."
  FAILURE : toast kind = error   text = "..."   lkg updated? = no
  policy  : toasts suppressed by OS? = yes/no ("...")
  opt-out : settings.json "toasts" = false -> no toast? = ... ; back on -> toast? = ...

Gate item 3 (hotkeys / X10.2) OBSERVED <date>:
  bind A  = Ctrl+Alt+W -> "..."   bind B = Ctrl+Alt+G -> "..."
  fire A  -> "..."   fire B -> "..."
  cfg conflict (A's combo on B) -> "..."
  built-in Ctrl+Alt+D conflict -> "..."
  OS conflict (ERROR_HOTKEY_ALREADY_REGISTERED) -> "..."  others still work? = ...
  clear (Delete) -> "..."

Gate item 4 (settings / restart) OBSERVED <date>:
  log_level  = error -> settings.json "..." ; INFO suppressed after? = ...
  default    = A     -> settings.json "..." ; applied on startup? = ... (log line "...")
  autostart  = enabled -> Run key = "..."
  restart    -> defaults re-applied? = yes/no ; checks correct? = ...
```

---

## 8. Sign-off (only after every box above is ticked)

- [ ] **Gate item 1** satisfied (OBSERVED) → tick the box in `phases/PHASE-10.md` §Gate.
- [ ] **Gate item 2** satisfied (OBSERVED, X10.1) → tick the box.
- [ ] **Gate item 3** satisfied (OBSERVED, X10.2) → tick the box.
- [ ] **Gate item 4** satisfied (OBSERVED) → tick the box.

When all four are ticked: set `phases/PHASE-10.md` Status → **COMPLETE**, update the
`phases/INDEX.md` Phase-10 row, and advance `STATUS.md` (current phase, gate table, last
completed work). Then commit + push the knowledge repo (evidence lives here).

> If any step fails, **do not** tick the box. Record the failure as **OBSERVED**, add it to
> `STATUS.md` **Open Blockers**, and treat the phase as still awaiting verification.
