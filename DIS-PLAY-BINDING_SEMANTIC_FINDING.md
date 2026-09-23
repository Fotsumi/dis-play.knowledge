# Binding Semantic Finding — Physical vs Connector/Role Identity

Focused design finding on one remaining V2 ambiguity: **what a saved profile entry *means* when it names a display.** It does not rewrite the master plan; it proposes a small, explicit mechanism and the Phase 0 tests that decide whether the mechanism is even expressible.

Confidence labels as in the V2 docs — **DOCUMENTED** (SDK), **OBSERVED** (expected on this machine, unconfirmed here), **INFERRED**, **UNKNOWN**.

---

## 1. The problem

A profile entry like "Monitor A ON" can mean two different things:

- **PHYSICAL binding** — "this exact physical monitor unit." If that unit is unplugged and a *different* unit is plugged into the same port, the profile no longer matches; it follows the *unit*, not the slot.
- **CONNECTOR/ROLE binding** — "whatever display currently occupies this GPU connector / role (e.g., DP1)." It follows the *slot*, not the unit.

V2 already keeps these as separate concepts (§5 of findings: physical identity vs display role; §16 of plan) and says the resolver must support both. But it never decides **which one a saved entry actually commits to**, or makes that choice visible. Today `DisplayEntry` carries `key_evidence` + an optional `role`, but no *binding policy* — so the resolver would implicitly pick, and a DP1↔DP2 swap could silently change behavior with no signal to the user. That is exactly the "silent assignment" anti-pattern V2 already forbids for AMBIGUOUS matches.

**The collapse principle (the whole point):** PHYSICAL and CONNECTOR/ROLE are *observationally identical* in every case except one — **a connector move of an indistinguishable unit.** For distinct units, both bindings behave the same (the unit's own EDID/model evidence travels with it). The only scenario where they diverge is: two physically-identical units + a re-plug/swap. And whether PHYSICAL is even *expressible* in that scenario depends entirely on Phase 0 evidence (do per-unit paths survive the move?). So the policy has observable teeth **only** in the identical-units + swap case — which is precisely where an implicit resolver would silently misbehave.

## 2. Concrete scenarios (identical Dells, DP1↔DP2)

Setup: two Dell U2723QE, same manufacturer/model/product code, no serial, identical EDID. Profile **Work** = "Monitor A ON, Monitor B OFF." At capture time A is the unit on DP1, B is the unit on DP2 (both facts are *slots*, because for identical units we cannot label which physical unit is which — only the slot is knowable).

| # | Event | PHYSICAL intent | CONNECTOR/ROLE intent |
|---|-------|-----------------|------------------------|
| S1 | No swap, apply Work | A (unit on DP1) ON, B OFF | Same result — indistinguishable from physical here |
| S2 | User swaps which unit is on DP1 vs DP2, then applies Work | Follows the *units*: turns ON whichever unit was originally "A" (now sitting on DP2), leaves the other OFF | Follows the *slots*: turns ON whatever is now on DP1 (a different physical unit than S1's intent) |
| S3 | Same as S2, but per-unit `monitorDevicePath`/PnP path does **not** survive the move (Phase 0 result B) | **Not expressible** — we cannot tell which unit is "A" after the swap; PHYSICAL silently degrades to CONNECTOR. Must be reported, not hidden | Still works (slot is always observable) |
| S4 | One of the two units fails / is replaced by a different model on DP1 | PHYSICAL: profile no longer matches (unit gone) → PARTIAL/AMBIGUOUS | CONNECTOR: "whatever's in this slot" still applies to the new unit |

S2/S3 are where an implicit resolver silently changes behavior. S4 shows the two semantics also diverge for *non*-identical units when hardware is swapped — so the policy matters beyond just identical units, though it is only *forced* by identical units.

## 3. Recommended model

**Store an explicit binding semantic per profile entry (derived + overridable), and require the resolver to report which semantic it actually honored.** Do not let the resolver decide silently.

Add one field to `DisplayEntry` (this is a targeted change, not a rewrite):

```rust
enum BindingPolicy { Auto, Physical, Connector }   // default Auto
struct DisplayEntry {
    key_evidence: IdentityEvidence,   // monitor_device_path / pnp_instance_id / connectorInstance / EDID fields
    binding_policy: BindingPolicy,     // NEW — what the entry *means*; default Auto
    role: Option<DisplayRole>,         // existing — "the display occupying this position/connector"
    desired_mode: DesiredMode,
    primary: bool,
    enabled: bool,
}
```

Semantics of each value (what the resolver does at apply time):

- **`Auto` (default):** pick the strongest semantic available and *report which it used*. For distinct units this resolves to effectively-PHYSICAL (the unit's own evidence travels with it). For identical units it resolves to CONNECTOR/ROLE, because only the slot is knowable — and it says so. This makes "I can't guarantee which unit; honoring as connector/role" visible instead of hidden.
- **`Physical`:** user insists on exact-unit tracking. Achievable **only if** per-unit evidence survives a connector move (Phase 0). If not achievable at apply time → refuse, or degrade to AMBIGUOUS with an explicit message ("cannot guarantee which unit; falling back to connector/role"). Never silently reassign.
- **`Connector`:** follow the slot regardless of which unit is there.

The resolver output must carry a per-entry **honored binding** (`PHYSICAL` / `CONNECTOR`) so any swap/degradation is visible in verification and user-facing reporting. This directly answers "do not let the resolver implicitly decide": it may choose, but it *says so*.

Scope guard: for distinct units, `Auto == effectively physical`; no extra machinery is needed there. The policy only earns its keep in the identical-units / swap case — which is exactly where implicit resolution silently misbehaves.

## 4. What to test in Phase 0 (add to the CLI spike)

These decide whether the mechanism is expressible at all:

1. **Connector-move path stability:** move a monitor DP1→DP2; does `monitorDevicePath` / PnP instance path change? → decides if PHYSICAL is expressible at all (B1/B2).
2. **Per-unit uniqueness across swap:** two identical units — do they get distinct per-unit paths that *survive* the move? → decides if we can track "the exact unit" post-swap.
3. **Role observability after swap:** what does path-priority / `connectorInstance` report about which slot is primary and where each unit sits, post-swap? → confirms CONNECTOR binding is observable and stable (and that primary follows the documented path-priority order).
4. **Capture-time labeling:** with two identical units both present (one ON, one OFF), can we record "A = the unit on DP1" vs only "A = some abstract unit"? → confirms capture yields a *slot* label for identical units, never a physical-unit label.

Gate: fill these into the existing `display-manager identity` table; the outcome sets which of `Auto/Physical/Connector` are actually reachable on this machine.

## 5. Changes required to V2 before implementation (minimal)

1. **Add `binding_policy` field** to `DisplayEntry` (`enum Auto/Physical/Connector`, default `Auto`) — one field, not a rewrite of the profile model.
2. **Resolver emits per-entry honored binding** (`PHYSICAL` / `CONNECTOR`) and surfaces degradation: PHYSICAL requested but only CONNECTOR achievable → AMBIGUOUS/refuse or explicit fallback message (never silent reassignment).
3. **Sharpen acceptance test A9** to state the *semantic outcome* of a DP1↔DP2 swap under each policy, not just "behavior is consistent."
4. **Update findings §5/§6 and plan §10/§16** to reference the explicit policy field (replace "resolver implicitly decides" with "policy stored + reported").
5. Keep it scoped: distinct units need no extra machinery (`Auto == effectively physical`).

None of these block *starting* Phase 0; they are exactly what Phase 0's outcomes lock down. They remain blockers to *locking* the profile model until evidenced.
