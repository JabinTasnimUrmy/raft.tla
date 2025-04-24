------------------------------ MODULE raftInit ------------------------------

EXTENDS raftHelpers

InitHistoryVars == voterLog  = [i \in Server |-> [j \in {} |-> <<>>]]

InitServerVars == /\ currentTerm = [i \in Server |-> 1]
                  /\ state       = [i \in Server |-> Follower]
                  /\ votedFor    = [i \in Server |-> Nil]

InitCandidateVars == /\ votesResponded = [i \in Server |-> {}]
                     /\ votesGranted   = [i \in Server |-> {}]

\* The values nextIndex[i][i] and matchIndex[i][i] are never read, since the
\* leader does not send itself messages. It's still easier to include these
\* in the functions.
InitLeaderVars == /\ nextIndex  = [i \in Server |-> [j \in Server |-> 1]]
                  /\ matchIndex = [i \in Server |-> [j \in Server |-> 0]]


InitLogVars == /\ log          = [i \in Server |-> << >>]
               /\ commitIndex  = [i \in Server |-> 0]


Init == /\ messages = [m \in {} |-> 0]
        /\ InitHistoryVars
        /\ InitServerVars
        /\ InitCandidateVars
        /\ InitLeaderVars
        /\ InitLogVars
        /\ maxc = 0
        /\ leaderCount = [i \in Server |-> 0]
        /\ entryCommitStats = [ key \in {} |-> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ] ]
        /\ serverCache = [s \in Server |-> {}] 

\* MyInit remains unchanged for the core Raft state, entryCommitStats is handled in Init.
MyInit ==
    LET ServerIds == CHOOSE ids \in [1..3 -> Server] : TRUE 
        r1 == ServerIds[1]
        r2 == ServerIds[2]
        r3 == ServerIds[3]
    IN
    /\ commitIndex = [s \in Server |-> 0]
    /\ currentTerm = [s \in Server |-> 2]
    /\ leaderCount = [s \in Server |-> IF s = r2 THEN 1 ELSE 0]
    /\ log = [s \in Server |-> <<>>]
    /\ matchIndex = [s \in Server |-> [t \in Server |-> 0]]
    /\ maxc = 0
    /\ messages = [m \in {} |-> 0]
    /\ nextIndex = [s \in Server |-> [t \in Server |-> 1]]
    /\ state = [s \in Server |-> IF s = r2 THEN Leader ELSE Follower]
    /\ votedFor = [s \in Server |-> IF s = r2 THEN Nil ELSE r2]
    /\ voterLog = [s \in Server |-> [j \in {} |-> <<>>]]
    /\ votesGranted = [s \in Server |-> {}]
    /\ votesResponded = [s \in Server |-> {}]
    /\ entryCommitStats = [ idx_term \in {} |-> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ] ]
    /\ serverCache = [s \in Server |-> {}] 

=============================================================================
\* Created by Ovidiu-Cristian Marcu