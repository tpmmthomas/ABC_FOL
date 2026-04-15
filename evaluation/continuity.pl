:- working_directory(_, '../src').
:-[main].

logic(fol).
theoryName(continuity).

%% Path locations
axiom([+path(start)]).
axiom([+path(med)]).
axiom([+path(end)]).

%% Connections (direct successor)
axiom([+nexti(start, med)]).
axiom([+nexti(med, end)]).

%% Reachability: transitive closure of nexti
axiom([+reachable(\x, \y), -nexti(\x, \y)]).                      % base case
axiom([+reachable(\x, \z), -reachable(\x, \y), -nexti(\y, \z)]).  % transitive

%% Perception (start is correct; med and end are WRONG)
axiom([+perception(start, ped)]).
axiom([+perception(med, ufo)]).      % WRONG: should be ped
axiom([+perception(end, under)]).    % WRONG: should be ped

%% Continuity of Existence Principle (in theory for constraint proofs)
axiom([-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)]).

%% Explicit disequality facts
axiom([+neq(ped, ufo)]).
axiom([+neq(ped, under)]).
axiom([+neq(ufo, ped)]).
axiom([+neq(ufo, under)]).
axiom([+neq(under, ped)]).
axiom([+neq(under, ufo)]).

%% Uniqueness constraint: two different perceptions at same position → violation
axiom([-perception(\p,\q), -perception(\p,\r), -neq(\q,\r)]).

%% Continuity also as a trueRule (generates insufficiency with head check excluding itself)
trueRules([[-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)]]).

%% Preferred structure
trueSet([perception(start, ped)]).
falseSet([]).

%% Allow loop-back in prover (0 = default, -1 = fully disabled, N>0 = check last N steps)
loopLimit(0).

%% Protect rules, constraints, and neq from modification
protect([[-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)],
         [-perception(\p,\q), -perception(\p,\r), -neq(\q,\r)],
         neq, arity(neq)]).
