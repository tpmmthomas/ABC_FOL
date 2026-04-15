:- working_directory(_, '../src').
:-[main].

logic(fol).
theoryName(crash4).

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

%% No Uniqueness constraint - only the two insufficiencies 

%% Continuity as a trueRule (anchored from start position)
trueRules([[-perception(start,\x2), -reachable(start,\z2), +perception(\z2,\x2)]]).

%% Preferred structure
trueSet([perception(start, ped)]). %GOAL: derive perception(med, ped) and perception(end, ped)
falseSet([]). % perception(med, ufo) and perception(end, under) will NOT be derived

%% Heuristics: None
heuristics([]).

%% Increase limits to handle many faults
costLimit(50).
roundLimit(100).

%% Protect rules, constraints, and neq from modification
protect([[-perception(\y,\x), -reachable(\y,\z), +perception(\z,\x)],
         [-perception(\p,\q), -perception(\p,\r), -(\q \= \r)],
         perception, arity(perception)]).
