
/**********************************************************************************************
   fileName: generate file name.
***********************************************************************************************/
fileName(FileCore, Name):-
   date(date(_,X,Y)),
   get_time(Stamp),
   stamp_date_time(Stamp, DateTime, local),
   date_time_value(time, DateTime, time(H,M,_)),
   appEach([X,Y,H,M], [term_string], [X1,Y1,H1,M1]),
   string_concat(Y1,X1,Date),
   string_concat(H1,M1,Time),
   appEach([Date, Time], [string_concat, '_'], [Date1, Time1]),
   appAll(string_concat, ['.txt',Time1, Date1,'_' , FileCore , '_', 'log/'],[''], Name, 1).

/**********************************************************************************************
  fileName: generate file name.
***********************************************************************************************/
initLogFiles(StreamRec, StreamRepNum, StreamRepTimeNH, StreamRepTimeH):-
  (\+exists_directory('log')-> make_directory('log'); nl),
  fileName('record', Fname),
  open(Fname, write, StreamRec),

  fileName('repNum', Fname2),
  open(Fname2, write, StreamRepNum),
  assert(spec(repNum(StreamRepNum))),

  (exists_file('repTimeHeu.txt')->
   open('repTimeHeu.txt', append, StreamRepTimeH);
  \+exists_file('repTimeHeu.txt')->
  open('repTimeHeu.txt', write, StreamRepTimeH)),
  assert(spec(repTimeH(StreamRepTimeH))),

  (exists_file('repTimenNoH.txt')->
   open('repTimenNoH.txt', append, StreamRepTimeNH);
  \+exists_file('repTimenNoH.txt')->
  open('repTimenNoH.txt', write, StreamRepTimeNH)),
  assert(spec(repTimeNH(StreamRepTimeNH))),

  maplist(assert, [spec(debugMode(1)), spec(logStream(StreamRec))]).
  %(OverloadedPred \= [] -> concepChange(OverloadedPred,  AllSents, RepSents, CCRepairs, Signature, RSignature);        %Detect if there is conceptual changes: a predicate has multiple arities.
  %RepSents = AllSents, CCRepairs = []),



/**********************************************************************************************
   output: write_term screen and write record file abc_record.txt.
***********************************************************************************************/
% If no repairs found, output the current result of semi-repairs.
output(AllRepStates, ExecutionTime):-
    notin([fault-free|_], AllRepStates),!,
    fileName('faulty', Fname2),
    open(Fname2, write, Stream2),
    write_term('******************************************'),
    write_term('Execution took '),
    write_term(ExecutionTime),
    write_term(' ms.'),nl,
    nl, write_term('The faulty theory cannot be repaired.'),
    write_term('The semi-repaired theories are:'),

    findall(RepTheory, member([fault,_,[[_,_], _, _, RepTheory, _, _]], AllRepStates),TBS),
    deleteAll(TBS, [], TBS1),
    sort(TBS1, TBSS),
    length(AllRepStates, SemiNumRaw),
    length(TBSS, SemiNum),

    write_Spec(Stream2, ExecutionTime, 0, SemiNum),
    writeFile(fault, Stream2, TBSS, AllRepStates),
    writeLog([nl, write_term('------------- TBSS -------------'), nl,
                  write_termAll(TBSS),nl,nl,nl,
                  write_term('SemiNumRaw is: '), write_term(SemiNumRaw),nl,
                  write_term('SemiNum is: '), write_term(SemiNum),nl, finishLog]),
    close(Stream2),
    nl, write_term('In total, there are ',[]), write_term(SemiNum,[]), write_term(' semi-repaired theories.',[nl]).

output(AllRepStates, ExecutionTime):-
    forall(member([fault-free, X,[_,_,_,_,_,_]], AllRepStates), X ==0),
    findall(ClS, (axiom(Cl), sort(Cl, ClS)), Facts),
    sort(Facts, OrigTheory),
    fileName('faultFree', Fname1),
    open(Fname1, write, Stream1),
    writeLog([nl, write_term('------------- AllRepStates -------------'), nl,
                  write_termAll(AllRepStates),nl,nl,nl, finishLog]),

    % output the execution time.
    (exists_file('aacur.txt')->
        open('aacur.txt', append, StreamC), nl(StreamC),
        write(StreamC, ExecutionTime),
        close(StreamC);
    \+exists_file('aacur.txt')->
        open('aacur.txt', write, StreamC), nl(StreamC),
        write(StreamC, ExecutionTime),
        close(StreamC)),

    trueSet(TrueSet),
    falseSet(FalseSet),
    write_term('Execution took ',[quoted(false)]),
    write_term(ExecutionTime,[quoted(false)]),
    write_term(' ms.',[quoted(false)]), nl,
    write(Stream1, 'The original theory is fault-free.'), nl(Stream1),!,
    write(Stream1, 'The fault-free theory : '), nl(Stream1),
    writeAll(Stream1, OrigTheory), nl(Stream1),
    write(Stream1, 'The true set:'), nl(Stream1),
    (TrueSet \= [] ->  writeAll(Stream1, TrueSet), !;
             write(Stream1, '[]')), nl(Stream1),
    write(Stream1, 'The false set: '), nl(Stream1),
    (FalseSet \= [] -> writeAll(Stream1, FalseSet), !;
             write(Stream1, '[]')), nl(Stream1),close(Stream1).

output(AllRepStates, ExecutionTime):-
    setof(ClS, Cl^(axiom(Cl), sort(Cl, ClS)), OrigTheory),
    length(OrigTheory, AxiomNum),
    assert(spec(axiomNu(AxiomNum))),
    fileName('faultFree', Fname1),
    open(Fname1, write, Stream1),

    % output the execution time.
    (exists_file('aacur.txt')->
        open('aacur.txt', append, StreamC), nl(StreamC),
        write(StreamC, ExecutionTime),
        close(StreamC);
    \+exists_file('aacur.txt')->
        open('aacur.txt', write, StreamC), nl(StreamC),
        write(StreamC, ExecutionTime),
        close(StreamC)),

    writeLog([nl, write_term('------------- AllRepStates -------------'), nl,
              write_termAll(AllRepStates),nl,nl,nl, finishLog]),

    trueSet(TrueSet),
    falseSet(FalseSet),
    write_term('Execution took ',[quoted(false)]),
    write_term(ExecutionTime,[quoted(false)]),
    write_term(' ms.',[quoted(false)]), nl,nl,


    nl, write_term('The original theory : ', [nl]), write_termAll(OrigTheory), nl,

    (TrueSet \= [] -> write_term('The original True  Set is: ', [nl]), trueSet(TS), write_termAll(TS), !;
      TrueSet == []->         write_term('The original True  Set is empty.', [nl])),
    (FalseSet \= [] -> write_term('The original False Set is: ', [nl]), falseSet(FS), write_termAll(FS), !;
     FalseSet == []->    write_term('The original False Set is empty.', [nl])),

    findall([TheoryA, RepPlan, TheoryB],
            (member([fault-free, _,[[RepPlan,_],_,_,TheoryA,_,_]], AllRepStates), TheoryB = [];
             member([fault, _,[_,_,_,TheoryB,_,_]], AllRepStates), TheoryA = []),
             AllResult),

    transposeF(AllResult, [TAS, RepPlanAll1, TBS]),
    delete(TAS, [], TAS1),
    delete(TBS, [], TBS1),
    sort(TAS1, TASS),
    sort(TBS1, TBSS),
    sort(RepPlanAll1, RepPlanAll),
    length(TAS1, FullyNumRaw),
    length(TASS, FullyNum),
    length(TBS1, SemiNumRaw),
    length(TBSS, SemiNum),

    writeLog([nl, write_term('------------- TASS -------------'), nl,
                    write_term('FullyNumRaw is: '), write_term(FullyNumRaw),nl,
                    write_term('FullyNum is: '), write_term(FullyNum),nl,nl,nl,
                  write_termAll(TASS),nl,nl,nl,
                  write_term('------------- TBSS -------------'), nl,
                  write_term('SemiNumRaw is: '), write_term(SemiNumRaw),nl,
                  write_term('SemiNum is: '), write_term(SemiNum),nl,nl,nl,
                  write_termAll(TBSS),nl,nl,nl, finishLog]),


    write_Spec(Stream1, ExecutionTime, FullyNum, SemiNum),
    write(Stream1, 'The original theory : '), nl(Stream1),
    writeAll(Stream1, OrigTheory), nl(Stream1),
    write(Stream1, 'The true set:'), nl(Stream1),
    (TrueSet \= [] ->  writeAll(Stream1, TrueSet), !;
             write(Stream1, '[]')), nl(Stream1),
    write(Stream1, 'The false set: '), nl(Stream1),
    (FalseSet \= [] -> writeAll(Stream1, FalseSet), !;
             write(Stream1, '[]')), nl(Stream1),

    length(RepPlanAll, RPNum),
    write(Stream1, 'All of '),  write(Stream1, RPNum),
    write(Stream1, ' repair plans are: '), nl(Stream1),
    writeAll(Stream1, RepPlanAll), nl(Stream1),

    writeFile(fault-free, Stream1, TASS, AllRepStates),
    (TBSS \=[]-> fileName('faulty', Fname2),
                open(Fname2, write, Stream2),
                write_Spec(Stream2, ExecutionTime, FullyNum, SemiNum),
                writeFile(fault, Stream2, TBSS, AllRepStates),
                close(Stream2); true),

    findall(R, spec(round(R)), RoundsA),
    sort(RoundsA, RoundsAs), write_term(RoundsAs),

    write(Stream1, 'Solutions are found at rounds:'),write(Stream1,RoundsAs),nl(Stream1),nl,
    nl, write_term('In total, there are '), write_term(FullyNum), write_term(' solutions with '),
    close(Stream1),
    write_term(SemiNum), write_term(' semi-solutions remaining.',[nl]).


/**********************************************************************************************************************
    writeLog: write log files.
    This function is unavailable in python-swipl ABC.
***********************************************************************************************************************/
writeLogSep(_).
writeLog(_):- spec(debugMode(X)), X \=1, !.
writeLog([]):-!.
writeLog(List):- !, spec(logStream(Stream))-> writeLog(Stream, List).
writeLog(_,[]):-!.
writeLog(_, [finishLog]):-!.
writeLog(Stream, [nl|T]):- nl(Stream), !, writeLog(Stream, T).
writeLog(Stream, [write_term(String)|T]):-
    write(Stream, String), !,
    writeLog(Stream, T).
writeLog(Stream, [write_termAll(List)|T]):-
    forall(member(X, List), (write(Stream, X), nl(Stream))),
    writeLog(Stream, T), !.



% write_terms  alist line by line
write_termAll([]) :- !.
write_termAll([C|Cs]) :-
    write_term(C, [quoted(false)]),nl, write_termAll(Cs).

/**********************************************************************************************************************
    writeFile(Directory, OutFiles, DataList)
            Write output files in Directory with the given output data.
    Input:  Directory is the directory of output files.
            FileName is a list of the names of output files.
            DataList is a list of output data to write in order.
***********************************************************************************************************************/
writeFiles(_, [], []).
writeFiles(Directory, [FileName| RestNames], [Data| RestData]):-
  atom_concat(Directory, FileName, FilePath),
  open(FilePath, write, StreamFile),
  % write a list line by line
  writeAll(StreamFile, Data),
  close(StreamFile),
  writeFiles(Directory, RestNames, RestData).

% FileName is the full path.
writeFiles([], []).
writeFiles([FileName| RestNames], [Data| RestData]):-
  open(FileName, write, StreamFile),
  % write a list line by line
  writeAll(StreamFile, Data),
  close(StreamFile),
  writeFiles(RestNames, RestData).

writeFile(_, _, [], _):-!.
writeFile(Type, Stream, Theories, AllStates):-
    retractall(spec(round(_))),
    forall(member(RepTheory, Theories),
            (    nth0(NO, Theories, RepTheory),    % RepTheory is the (NO+1)th solution
                Rank is NO+1,
                % ** unify every sigle repair in the list of repairs (SetOfRepairs) to RepairSorrted
                   findall((Round, Repairs),
                               (member([Type, Round,[[Reps,_],_,_,RepTheory,_,_]], AllStates),
                                appEach(Reps, [revertFormRep], Repairs)), % rever the form of repair information back to the input form
                           RepInfo),

                   RepInfo \= [],
                   appEach(RepTheory,[appEach, [appLiteral,revert]], Axioms),

                   (Type == fault-free, spec(screenOutput(true))->!,
                nl, write_term('------------------ Solution No. '), write_term(Rank),
                    write_term(' as below ------------------',[nl]),
                forall(member((RR,Rep), RepInfo),(write_term('Repair plans found at Layer/CallNum '),
                                    write_term(RR), write_term(' :'),nl,write_termAll(Rep),nl)),
                nl, write_term('Repaired theory: ',[nl]),write_termAll(Axioms),nl;true),

                write(Stream, '------------------ Solution No. '), write(Stream, Rank),
                write(Stream, ' as below------------------'), nl(Stream),
                forall(member((RR,Rep), RepInfo),
                                (    assert(spec(round(RR))),
                                    write(Stream, 'Repair plans found at Round '),
                                    write(Stream, RR), write(Stream,' :'), nl(Stream),
                                    writeAll(Stream, Rep),nl(Stream))),
                nl(Stream),
                write(Stream, 'Repaired Theory: '), nl(Stream),
                writeAll(Stream, Axioms), nl(Stream))).

% write a list line by line
writeAll(_, []):- !.
writeAll(Stream1,[C|Cs]) :- write(Stream1, C), write(Stream1, '.'), nl(Stream1), writeAll(Stream1, Cs).

write_term(X):- write_term(X, [quoted(false)]).

write_Spec(Stream, ExecutionTime, FullyNum, SemiNum):-
    spec(costLimit(Cost)),
    spec(roundLimit(Round)),
    date(Date), term_string(Date, DateStr),
    spec(heuris(Heuristics)),
    spec(protList(Protected)),    % if there is protected item(s)), output it(them).
    spec(inputTheorySize(AxiomNum)),
    spec(faultsNum(InsuffNum, IncompNum)),

    write(Stream, DateStr), nl(Stream),
    write(Stream, '----------------------------------------------------------------------------------'),nl(Stream),
    write(Stream,'Theory size: '), write(Stream, AxiomNum),nl(Stream),
    write(Stream,'Faults Number: '), write(Stream, (InsuffNum, IncompNum)),nl(Stream),
    write(Stream,'Cost Limit is: '), write(Stream, Cost),nl(Stream),
    write(Stream,'RoundLimit is: '), write(Stream, Round),nl(Stream),
    write(Stream,'Running time: '), write(Stream, ExecutionTime), write(Stream, ' ms.'), nl(Stream),
    write(Stream,'Heuristics applied:'), write(Stream, Heuristics),  nl(Stream),
    write(Stream,'The protected item(s):'), write(Stream, Protected), nl(Stream),
    write(Stream,'Total Solution number is: '),write(Stream, FullyNum),  nl(Stream),
    (SemiNum == []->write(Stream,'No incomplete repaired theory left.'),nl(Stream), !;
    SemiNum \= []->    write(Stream, 'Remaining semi-repaired theories: '), write(Stream, SemiNum),nl(Stream)),
    write(Stream, '----------------------------------------------------------------------------------'),nl(Stream).
