# Phase 4 — Verification & Recovery

## Objective
After apply, verify the live topology matches intent; on mismatch or failure, recover (re-apply known-good state) without user intervention beyond a log line.

## Scope
- In: post-apply verification (compare captured state to intended); recovery path (re-apply last-known-good Profile).
- Out: UI presentation of verify/recover status (Phase 5).

## Tasks
| # | Task | Output |
|---|---|---|
| T4.1 | Verify post-apply state vs intended topology | verify fn |
| T4.2 | Recovery: re-apply last-known-good Profile on mismatch | recover fn |
| T4.3 | Log line + optional user notification hook (no UI yet) | logging |

## Gate
- [ ] Verification detects a real mismatch on HW. **OBSERVED**
- [ ] Recovery restores intended topology after a forced bad apply. **OBSERVED**

## Potential Blockers
- Needs Phase 3 apply working first; recovery is only meaningful if apply can fail.

## Decisions Produced
_(record here as made)_

## Actual Results
_pending — blocked by Phase 3_

## Status
**BLOCKED by Phase 3.**
