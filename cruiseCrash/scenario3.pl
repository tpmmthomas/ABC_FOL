:- working_directory(_, '../src').
:-[main].

logic(fol).
theoryName(conTest2c).

%% Path locations
axiom([+path(start)]).
axiom([+path(med)]).
axiom([+path(end)]).

%% Connections (direct successor)
axiom([+nexti(start, med)]).
axiom([+nexti(med, end)]).

%% Reachability: transitive closure of nexti
axiom([+reachable(\x, \y), -nexti(\x, \y)]).                      % base case
axiom([+reachable(\x1, \z1), -reachable(\x1, \y1), -nexti(\y1, \z1)]).  % transitive

%% Perception (start is correct; med and end are WRONG)
axiom([+perception(start, ped)]).
axiom([+perception(med, ufo)]).      % WRONG: should be ped
axiom([+perception(end, under)]).    % WRONG: should be ped

%% Continuity of Existence Principle (in theory for constraint proofs)
%Put  into truerules, should not be part of the ground truth
% axiom([-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)]).

%% Uniqueness constraint: two different perceptions at same position → violation
%% Uses built-in \= (inequality) — resolved automatically by the proof engine.
% axiom([-perception(\p,\q), -perception(\p,\r), -(\q \= \r)]).

%% Continuity as a trueRule (anchored from start position)
trueRules([[-perception(start,\x2), -reachable(start,\z2), +perception(\z2,\x2)]]).

%% Preferred structure
trueSet([perception(start, ped)]). %GOAL: derive perception(med, ped) and perception(end, ped)
falseSet([]). %GOAL derive perception(med, ufo) and perception(end, under)

%% Heuristics: disable complex repair types to reduce search space
% hueristics([noExtC2V]).
heuristics([noAss2Rule, noExtC2V, noAxiomAdd]). %% TEST: 4 (allow merge) % noAss2Rule, noVabWeaken, noExtC2V, noMerge, noAxiomAdd

%% Increase limits to handle many faults
costLimit(50).
roundLimit(100).

%% Allow loop-back in prover to enable continuity derivation chains (-1 = fully disabled)
% loopLimit(-1).

%% Protect rules, constraints, and neq from modification
protect([[-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)],
         [-perception(\p,\q), -perception(\p,\r), -(\q \= \r)],
         perception, arity(perception)]).
