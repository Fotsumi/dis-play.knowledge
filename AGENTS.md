# dis-play.knowledge — Operational Instructions

## Workspace Identity

This directory (`dis-play.knowledge/`) is the **knowledge and operations root** for the DIS-PLAY project. It holds:

- Historical findings, plans, and design documents (V1 + V2)
- Operational documentation (`STATUS.md`, `phases/`)
- Evidence records and decision logs

It does **not** contain implementation source code. All product source lives in `product/`.

## Repository Separation

| Path | Role | Git |
|---|---|---|
| `dis-play.knowledge/` (this repo) | Knowledge, plans, evidence, operations | Tracked here |
| `product/` | Implementation (Rust CLI → tray app) | **Separate git repository** — ignored by this repo via `.gitignore` |

Rules:
- Never commit `product/` contents into this repository.
- `product/` has its own `.git`, its own history, and its own `AGENTS.md`.
- Cross-references between the two use relative paths only (no symlinks).

## Evidence Labels

Every factual claim in any document must carry one of these labels:

| Label | Meaning |
|---|---|
| **DOCUMENTED** | Verified against an authoritative source (MS Learn, Windows SDK header, crate docs) with a citation. |
| **OBSERVED** | Empirically confirmed by running the diagnostic CLI or a controlled experiment on target hardware. |
| **INFERRED** | Logical deduction from DOCUMENTED/OBSERVED facts; not yet independently verified. |
| **UNKNOWN** | No evidence available; explicitly flagged as open question. |

Rules:
- A claim without a label is treated as unverified and must not gate a phase.
- When new evidence contradicts an existing claim, the old claim is annotated with `[SUPERSEDED by <source>]` — it is never silently deleted or overwritten.
- Historical documents (V1) are immutable once committed; corrections live in V2+ only.

## Decision Tracking

Every significant design decision gets:
1. A **Decision ID** (e.g., `D-001`, `D-002`) recorded in the relevant phase doc and linked from `STATUS.md`.
2. The **context** (what question was being answered).
3. The **options considered** (brief).
4. The **decision + rationale**.
5. A **status**: `FINAL` / `PENDING-EVIDENCE` / `REVISED`.

Decisions that depend on Phase 0 evidence are marked `PENDING-EVIDENCE` and must not be treated as final until the gate is satisfied.

## Phase Execution Rules

1. Phases are defined in `phases/INDEX.md`; each has its own doc (`PHASE-N.md`).
2. A phase is **complete** only when its gate criteria (listed in the phase doc) are all satisfied with evidence.
3. No phase may be marked complete based on inference alone — at least one OBSERVED or DOCUMENTED item must satisfy each gate criterion.
4. If a phase produces findings that invalidate or clarify an earlier plan section, the affected document is updated and `STATUS.md` records which sections changed.
5. Phase work happens in this order: **read gate → execute tasks → record evidence → update docs → mark complete**.

## STATUS.md Maintenance

- `STATUS.md` is the single operational dashboard. It must be updated at the end of every working session.
- Required fields (see template in the file): current phase, overall status, last completed work, current work, next action, gates, blockers, questions, decisions, discoveries, experiments, affected docs, product status, date.
- A stale `STATUS.md` is a process violation — if you are about to stop working, update it first.

## Product Implementation Instructions

All implementation-specific instructions (Rust conventions, safety rules for SetDisplayConfig, build procedure, crate choices) live in **`product/AGENTS.md`** — not here. This file only governs the knowledge/operations layer.
