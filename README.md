# ABC_FOL — Cruise Crash Case Study

This branch (`fol.cruise-crash`) accompanies the note *Critiquing the Cruise Crash using Conceptual Change* by Alan Bundy, Gonzalo Aranda and Thomas Wong. It applies the FOL-ABC theory repair system to the 2023 Cruise robotaxi incident analysed by Koopman, in which the vehicle failed to recognise three successive sensor views of the same pedestrian (`Ped` at the crosswalk, `UFO` on the bonnet, and `Under` beneath the chassis) as a single object.

## The Cruise Crash formulation

The faulty `Robotaxi` theory records the three disjoint perceptions together with a *continuity of existence* principle — that an object present at one location on its path must also be present at the next location. The initial theory is insufficient: the continuity axiom cannot be proved for the second or third view because each view is bound to a distinct constant.

FOL-ABC is invoked with the heuristics `noAxiomAdd`, `noAss2Rule` and `noExtC2V` (see the paper for details), which together rule out superficial repairs. Under this reduced search space, **constant renaming** emerges as the correct repair: `UFO` and `Under` are merged into `Ped`, yielding a fault-free theory in which all three views refer to the same pedestrian — precisely the conceptual change required by the continuity of existence principle.

The formalisation lives in [cruiseCrash/scenario1.pl](cruiseCrash/scenario1.pl). Running it produces three output files seen in `results/`:

- `abc_crash1_..._faultFree.txt` — the repaired, fault-free theory.
- `abc_crash1_..._record.txt` — the full trace of ABC's repair procedure.
- `abc_crash1_..._repNum.txt` — the pruned sub-optimal repair candidates.

## How to run the Cruise Crash example

**Step 1.** Open a SWI-Prolog console at the project root.

**Step 2.** Consult the scenario file:

```prolog
1 ?- working_directory(_, './cruiseCrash').
true.

2 ?- [scenario1].
true.
```

The header of `scenario1.pl` already sets the working directory to `../src`, loads `main.pl`, and selects the FOL backend via `logic(fol).`

**Step 3.** Run the repair:

```prolog
3 ?- abc.
```

Inspect the generated files in `src/ABC_FOL/log` to see the repair solutions, the procedure log, and the pruned candidates.

## Writing your own scenario

A theory input file must provide:

- `axiom([...])` clauses for the object theory.
- `trueRules([...])` for rules that must remain provable (the continuity principle in this case).
- `trueSet([...])` and `falseSet([...])` for the preferred structure.
- optional `protect([...])` to shield items from modification, and `heuristics([...])` to restrict the repair search space.

Prepend the following header so the file can be consulted directly:

```prolog
:- working_directory(_, '../src').
:- [main].

logic(fol).
theoryName(yourTheoryName).
```
