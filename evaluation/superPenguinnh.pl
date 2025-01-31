:- working_directory(_, '../src').
:-[main].

logic(datalog).

theoryName(superPenguinnh).

axiom([-penguin(\x),+bird(\x)]).
axiom([-bird(\x),+fly(\x)]).
axiom([-superPenguin(\x),+penguin(\x)]).
%axiom([-superPenguin(\x),+fly(\x)]).
axiom([+superPenguin(opus)]).
axiom([+brokenWing(opus)]).
axiom([-brokenWing(\x),-bird(\x),+cannotFly(\x)]).
axiom([-fly(\x),-cannotFly(\x)]).

trueSet([fly(opus)]).
falseSet([cannotFly(opus)]).
protect([]).
heuristics([]).

theoryFile:- pass. 
