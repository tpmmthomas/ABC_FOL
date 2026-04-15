# ABC_FOL Implementation Log — Continuity-of-Existence & Constraint-Based Repair

This document records all implementations, bug fixes, and design decisions made during the development of constraint-based fault detection and repair for the continuity-of-existence test case (`evaluation/conTest.pl`).

---

## Table of Contents

1. [Test Case Overview](#1-test-case-overview)
2. [Bugs Found & Fixed](#2-bugs-found--fixed)
3. [Features Implemented](#3-features-implemented)
4. [Heuristics Added](#4-heuristics-added)
5. [The neq → `\=` Migration](#5-the-neq--migration)
6. [Files Modified](#6-files-modified)
7. [How to Run](#7-how-to-run)
8. [Key Technical Details](#8-key-technical-details)

---

## 1. Test Case Overview

**File:** `evaluation/conTest.pl`

The test models a **continuity-of-existence** scenario on a 3-node path:

```
start → med → end
```

Each node has a `perception` observation. The starting observation `perception(start, ped)` is correct; the other two are WRONG:

| Axiom | Status |
|-------|--------|
| `perception(start, ped)` | Correct |
| `perception(med, ufo)` | **Wrong** — should be `ped` |
| `perception(end, under)` | **Wrong** — should be `ped` |

**Continuity Principle (trueRule):** If we observe `ped` at `start` and `start` is reachable to other nodes, we should observe `ped` there too:
```prolog
trueRules([[-perception(start,\x2), -reachable(start,\z2), +perception(\z2,\x2)]]).
```

**Uniqueness Constraint:** A position cannot have two different perceptions simultaneously:
```prolog
axiom([-perception(\p,\q), -perception(\p,\r), -(\q \= \r)]).
```
The `\=` is Prolog's standard inequality operator, resolved automatically by the proof engine's existing equality/inequality infrastructure.

**Preferred Structure:**
```prolog
trueSet([perception(start, ped)]).
falseSet([]).
```

**Expected Result:** The system should detect 2 insufficiencies (`perception(med, ped)` and `perception(end, ped)` are missing) plus constraint violations (conflicting perceptions at same positions), then repair by renaming: `ufo → ped` and `under → ped`.

**Actual Result:** ✅ 1 solution, 0 semi-solutions — clean rename repairs.

---

## 2. Bugs Found & Fixed

### 2.1 `compose1` — Substitution Composition Failure

**File:** `src/ABC_FOL/util.pl`, line ~207

**Problem:** `compose1` assumed `Sub` was always a single substitution `_/_`, but during trueRule proof it could be a list of substitutions. This caused silent failures.

**Fix:** Changed `Sub = [_]` guard to `is_list(Sub)`:
```prolog
compose1(Sub, SublistIn, SublistOut) :-
    subst(Sub, SublistIn, SublistMid),
    (is_list(Sub) -> append(Sub, SublistMid, SubTem);  % was: Sub = [_]
     Sub = _/_-> SubTem = [Sub|SublistMid]),
    sort(SubTem, SublistOut).
```

### 2.2 `updateDeriv` — Empty Derivation Crash

**File:** `src/ABC_FOL/proof.pl`, line ~445

**Problem:** `updateDeriv(Deriv, reorder, DerivNew)` calls `last(DerivRemain, Target)` internally, which FAILS when `Deriv = []`. The `\=`/neq reorder was always the FIRST operation on a constraint (empty derivation), so it always failed silently — no proofs were ever returned.

**Root Cause:** `slRLMain2` reorders `=/\=` goals to the end. When this is the first proof step, `Deriv = []`. The `updateDeriv([], reorder, _)` call tries `last([], Target)` which has no solution, causing the entire reorder clause to fail.

**Impact:** After `appRepair(merge(...))` applies a merge repair, it calls `sort` on literals within each clause (line 168 of repairApply.pl), destroying the `orderAxiom` ordering that placed `\=` at the end. When `\=` sorts first (standard term ordering: `\=` < `perception`), `slRLMain2` must reorder it. With empty derivation, this fails → violations go undetected → merge repair falsely appears fault-free.

**Fix:** Added a base case for empty derivations:
```prolog
updateDeriv([], reorder, []):- !.
```

**Verification:**
- Before fix: `heuristics([])` → 1 solution (merge, falsely fault-free despite conflicting perceptions)
- After fix: `heuristics([])` → 3 solutions, 13 semi-solutions (violations correctly detected)
- With full heuristics: 1 solution (clean rename) — unchanged

### 2.3 Virtual neq Assertions — Invalid Repair Plans

**File:** `src/ABC_FOL/proof.pl`

**Problem:** When the custom neq ground resolution clause used `InputClause = [+[neq, C1, C2]]` in its derivation step, the repair system treated this as a real axiom and generated invalid rename/delete/renamePred plans targeting non-existent `neq` assertions.

**Fix (now obsolete — removed with neq clauses):** Changed to use `(unae, [])` as `InputClause` marker (same pattern as `=/\=` built-in resolution) with `secondNum` as `PredType`.

**Note:** After migrating to `\=`, this is handled natively — the `resolveEqu` flow uses `unae` markers by design.

### 2.4 Arity Protection Bugs (5 locations)

**Problem:** Several repair generation predicates checked whether a predicate was protected but did NOT check `arity(P)` protection, allowing arity-modifying repairs on protected predicates.

**Files & Fixes:**
- `src/ABC_FOL/repairPlanGen.pl` — 3 locations (lines ~241, ~325, ~811): Added `notin(arity(P), ProtectedList)` checks
- `src/ABC_FOL/reformation.pl` — 2 locations (lines ~58, ~84): Added `notin(arity(P), ProtectedList)` checks

### 2.5 Protection List Ordering Mismatch — Constraint Not Protected

**File:** `src/ABC_FOL/preprocess.pl`, `initProtList` (line ~238)

**Problem:** `initProtList` converts clause-typed protection items with `convertClause` (which calls `sort/2`) but NOT `orderAxiom`. The theory axioms go through both `convertClause` AND `orderAxiom`. Because `\=` sorts before `perception` in standard term ordering, the protection list stores the constraint as `[-[\=,...], -[perception,...], -[perception,...]]` while the theory stores it as `[-[perception,...], -[perception,...], -[\=,...]]`. When `weaken` checks if a clause is protected, the comparison fails due to different literal orderings.

**Impact:** The uniqueness constraint was unprotected despite being in the `protect(...)` list. `weaken` could replace constraint variables with dummy constants, effectively neutralizing the constraint, and the system would report a "fault-free" solution.

**Fix:** Added `orderAxiom` call after `convertClause` in the protection list initialization:
```prolog
(is_list(Item1)->
    convertClause(Item1, ItemC),
    orderAxiom(ItemC, Item);
    Item1 = Item)
```

**Verification:**
- Before fix: `heuristics([])` → 10 solutions (all with weakened constraint)
- After fix: `heuristics([])` → 0 solutions, 85 semi (constraint properly protected)
- Full heuristics: 1 solution (clean rename) — unchanged

---

## 3. Features Implemented

### 3.1 `provePrecondsAccum/5` — Sequential Precondition Proving

**File:** `src/ABC_FOL/abc.pl`, end of file (~line 464)

**Purpose:** Prove trueRule preconditions one at a time, accumulating substitutions between literals. This avoids the `combineSubs` bug where variable chains through intermediate clause variables are lost when `updateOldCls` skips proof steps with `RemNum=[0,0]`.

```prolog
provePrecondsAccum([], _, _, Subs, Subs).
provePrecondsAccum([Lit|Rest], Theory, EC, SubsIn, SubsOut) :-
    subst(SubsIn, [Lit], [LitGround]),
    retractall(spec(proofNum(_))), assert(spec(proofNum(0))),
    slRL([LitGround], Theory, EC, Proof, [], []),
    combineSubs([], Proof, StepSubs),
    compose1(StepSubs, SubsIn, SubsNew),
    provePrecondsAccum(Rest, Theory, EC, SubsNew, SubsOut).
```

**Called from:** `detInsInc` in the trueRules processing section (line ~175).

### 3.2 Augmented-Theory Violation Detection

**File:** `src/ABC_FOL/abc.pl`, `detInsInc` predicate (lines ~207–245)

**Purpose:** TrueRule insufficiencies generate expected facts (e.g., `perception(med, ped)`) that don't yet exist in the theory. These expected facts are added as temporary assertions to create an "augmented theory." Constraint violation detection then runs against this augmented theory, allowing the uniqueness constraint to fire when the expected facts conflict with wrong existing facts.

**Flow:**
1. Collect trueRules insufficiency heads as temp assertions (`TRInsufHeads`)
2. Add them to the protection list (so repair planner won't target them)
3. Create `AugmentedTheory = Theory ++ TRInsufHeads`
4. Run constraint violation detection with `slRL(Constrain, AugmentedTheory, EC, Proof3, [], [])`

### 3.3 TrueRule Anchoring to `start`

**File:** `evaluation/conTest.pl`

**Design decision:** The trueRule is anchored to the `start` position:
```prolog
trueRules([[-perception(start,\x2), -reachable(start,\z2), +perception(\z2,\x2)]]).
```

This ensures the continuity principle propagates from the known-correct observation at `start`, rather than from arbitrary positions.

---

## 4. Heuristics Added

### 4.1 `noExtC2V` — Disable Extend-Constant-to-Variable

**File:** `src/ABC_FOL/reformation.pl`, inside `extCons2Vble/8` (line ~178)

**Gate:**
```prolog
spec(heuris(Heuristics)),
notin(noExtC2V, Heuristics),
```

**Reason:** Without this heuristic, `extC2V` repairs dominate rename repairs in Pareto selection because they achieve fault-free status in fewer rounds (a single `extC2V` like `perception(\z, \y)` matches everything in 1 round, while rename needs 2 rounds).

### 4.2 `noMerge` — Disable Merge Plans

**File:** `src/ABC_FOL/reformation.pl`, inside `mergePlan/7` (line ~103)

**Gate:**
```prolog
spec(heuris(Heuristics)),
notin(noMerge, Heuristics),
```

**Reason:** Without this heuristic (but with `noExtC2V`), merge plans produce solutions with dummy constants instead of clean renames.

### 4.3 Full Heuristic Set for conTest

```prolog
heuristics([noAss2Rule, noVabWeaken, noExtC2V, noMerge, noAxiomAdd]).
```

With all heuristics active, the system produces exactly **1 solution** — the ideal pure rename: `rename(ufo → ped)` + `rename(under → ped)`.

---

## 5. The neq → `\=` Migration

### Background

Initially, inequality in the uniqueness constraint was expressed as a custom predicate `neq(\q, \r)` with a `builtinPred(neq)` mechanism:
- `builtinPred(neq).` declared in conTest.pl
- `spec(builtinPred(neq))` registered during preprocessing
- Two custom `slRLMain` clauses in proof.pl:
  - `slRLMain_neq1`: Reorder `neq` to end when args are not ground
  - `slRLMain_neq2`: Resolve immediately when both args are ground different constants

### Discovery

The proof engine already has complete infrastructure for handling `\=` (Prolog's standard inequality):

| Component | Location | What it does |
|-----------|----------|-------------|
| `orderAxiom/2` | util.pl line ~617 | Moves `\=` literals to end of clauses during preprocessing |
| `slRLMain2` | proof.pl line ~141 | Reorders `\=` to end at proof time if it's first |
| `slRLMain5` | proof.pl line ~360 | Detects when all remaining goals are `=/\=`, calls `resolveEqu` |
| `resolveEqu` | proof.pl | Orchestrates equality/inequality resolution |
| `equalSub([\=, X, Y], _, Subs)` | equalities.pl line ~384 | Ground inequality: `is_cons(X), is_cons(Y), (X \= Y -> Subs=[])` |
| `equalSub([\=, ...], EC, Subs)` | equalities.pl lines ~387-397 | Variable inequality using equivalence classes |

### Migration (final changes)

All custom neq handling was **removed** and replaced by simply using `\=` in the constraint:

| File | Before | After |
|------|--------|-------|
| conTest.pl | `axiom([-perception(\p,\q), -perception(\p,\r), -neq(\q,\r)])` | `axiom([-perception(\p,\q), -perception(\p,\r), -(\q \= \r)])` |
| conTest.pl | `builtinPred(neq).` | (removed) |
| conTest.pl | `protect([..., neq, arity(neq)])` | `protect([...])` — neq entries removed |
| proof.pl | `slRLMain_neq1` + `slRLMain_neq2` (~25 lines) | (removed) |
| preprocess.pl | `builtinPred` registration code | (removed) |

**Net result:** ~30 lines of custom infrastructure eliminated. Zero custom code needed — inequality is handled entirely by the existing `\=` resolution pipeline.

---

## 6. Heuristic Importance Analysis

### Goal
Determine the minimal set of heuristics (from the original 5) needed to produce the clean rename solution: `rename(ufo→ped)` + `rename(under→ped)`.

### Individual Removal Tests

Each heuristic was removed one at a time from the full set `[noAss2Rule, noVabWeaken, noExtC2V, noMerge, noAxiomAdd]`:

| Removed Heuristic | Solutions | Semi | Effect |
|---|---|---|---|
| noAss2Rule | 0 | 245 | **ESSENTIAL** — ass2rule repairs dominate, all fail |
| noVabWeaken | 0 | 245 | **ESSENTIAL** — vabWeaken repairs dominate, all fail |
| noExtC2V | 1 | 10 | Solution uses extC2V + dummy constants (not clean rename) |
| noMerge | 1 | 0 | **Same clean rename** — merge is naturally ineffective here |
| noAxiomAdd | 9 | 0 | 9 solutions, none are clean rename (expand dominates) |

### Combination Tests

| Heuristic Set | Solutions | Semi | Clean Rename? |
|---|---|---|---|
| All 5 | 1 | 0 | Yes |
| `[noAss2Rule, noVabWeaken, noExtC2V, noAxiomAdd]` (no noMerge) | 1 | 0 | **Yes** |
| `[noAss2Rule, noVabWeaken, noExtC2V]` | 9 | 0 | No (all use expand) |
| `[noAss2Rule, noVabWeaken]` | 1 | 11 | No (extC2V + dummy constants) |
| `[]` (none) | 0 | 85 | N/A |

### Classification

- **Essential** (without → 0 solutions): `noAss2Rule`, `noVabWeaken`
- **Important for clean rename** (without → wrong solution type): `noExtC2V`, `noAxiomAdd`
- **Redundant**: `noMerge` — merge repairs cannot produce fault-free theories for this problem (the `updateDeriv` fix ensures the `\=` constraint is properly checked after merge), so blocking them is unnecessary

### Minimal Heuristic Set

**`[noAss2Rule, noVabWeaken, noExtC2V, noAxiomAdd]`** — 4 heuristics suffice. `noMerge` can be safely omitted.

### How `\=` Resolution Works in the Constraint

1. **Preprocessing:** `convertClause` converts `(\q \= \r)` → `[\=, vble(q), vble(r)]`. Then `orderAxiom` moves it to the END of the clause.
2. **Proof time — initial state:** Constraint goals: `[-[perception, vble(p), vble(q)], -[perception, vble(p), vble(r)], -[\=, vble(q), vble(r)]]`. The `perception` goals come first.
3. **Resolution:** `slRLMain3.1` resolves the two `perception` goals against theory assertions, binding variables to ground constants.
4. **After perception goals resolved:** Only `-[\=, [ped], [ufo]]` remains (or similar ground inequality).
5. **slRLMain5 fires:** All remaining goals are `=/\=`, so it calls `resolveEqu`.
6. **equalSub:** `equalSub([\=, [ped], [ufo]], _, Subs)` succeeds with `Subs=[]` because `[ped] \= [ufo]`.
7. **Derivation:** Uses the `unae` marker — the repair system correctly ignores this step.

---

## 6. Files Modified

### `evaluation/conTest.pl`
- Complete test case with path/connectivity/perception axioms
- Reachability rules (base + transitive)
- Uniqueness constraint using `\=`
- TrueRule anchored to `start`
- Heuristics: `[noAss2Rule, noVabWeaken, noExtC2V, noMerge, noAxiomAdd]`
- Protection list for rules, constraint, and `perception` predicate/arity

### `src/ABC_FOL/abc.pl`
- Augmented-theory violation detection in `detInsInc`
- `provePrecondsAccum/5` at end of file

### `src/ABC_FOL/util.pl`
- `compose1` fix: `is_list(Sub)` instead of `Sub = [_]`

### `src/ABC_FOL/proof.pl`
- Custom neq clauses **removed** (migrated to `\=`)
- All debug prints removed

### `src/ABC_FOL/preprocess.pl`
- `builtinPred` registration code **removed**

### `src/ABC_FOL/reformation.pl`
- `noExtC2V` heuristic gate in `extCons2Vble/8`
- `noMerge` heuristic gate in `mergePlan/7`
- 2 arity protection bug fixes

### `src/ABC_FOL/repairPlanGen.pl`
- 3 arity protection bug fixes

### `src/ABC_FOL/repairApply.pl`
- Debug prints removed from `appRepair(rename(...))`

---

## 7. How to Run

```powershell
cd evaluation
swipl -l conTest.pl -g "abc, halt" 2>&1
```

**Expected output (last lines):**
```
The original theory :
...
[- (\q\= \r),-perception(\p,\q),-perception(\p,\r)]
...
In total, there are 1 solutions with 0 semi-solutions remaining.
```

The solution applies `rename(ufo → ped)` and `rename(under → ped)` across multiple rounds, producing a clean theory where all positions observe `ped`.

---

## 8. Key Technical Details

### Internal Representation

| Concept | Syntax | Internal |
|---------|--------|----------|
| Variable | `\x` | `vble(x)` |
| Constant | `ped` | `[ped]` |
| Predicate | `perception(\x, \y)` | `[perception, vble(x), vble(y)]` |
| Positive literal | `+perception(start, ped)` | `+[perception, [start], [ped]]` |
| Negative literal | `-perception(\x, \y)` | `-[perception, vble(x), vble(y)]` |
| Inequality | `(\q \= \r)` | `[\=, vble(q), vble(r)]` |
| Constant check | — | `is_cons(X) :- X = [Y], atomic(Y)` |

### Proof Resolution Order (slRLMain clauses)

1. **slRLMain1:** Cost/loop limit checks
2. **slRLMain2:** Reorder `=/\=` to end when other goals exist
3. **slRLMain3.1:** Resolve `-[P|Arg]` assertion against theory `+[P|Arg2]`
4. **slRLMain3.2:** Resolve `+[P|Arg]` against theory `-[P|Arg2]`
5. **slRLMain4:** Resolve with multi-literal rules (full resolution)
6. **slRLMain5:** When ALL remaining goals are `=/\=` → call `resolveEqu`

### Relevant Predicates

| Predicate | File | Purpose |
|-----------|------|---------|
| `detInsInc/6` | abc.pl | Main fault detection (insufficiencies + incompatibilities + violations) |
| `repInsInc/4` | abc.pl | Repair loop with Pareto selection |
| `provePrecondsAccum/5` | abc.pl | Sequential precondition proving for trueRules |
| `slRL/6` | proof.pl | Entry point for SL-resolution proofs |
| `slRLMain/9` | proof.pl | Main resolution dispatch |
| `resolveEqu/7` | proof.pl | Equality/inequality resolution |
| `equalSub/3` | equalities.pl | Computes substitutions for `=/\=` goals |
| `orderAxiom/2` | util.pl | Reorders clause literals during preprocessing |
| `compose1/3` | util.pl | Substitution composition |
| `extCons2Vble/8` | reformation.pl | Extend-constant-to-variable repair generation |
| `mergePlan/7` | reformation.pl | Merge repair generation |
