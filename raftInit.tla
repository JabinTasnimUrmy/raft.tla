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
        /\ entryCommitStats = [ idx_term \in {} |-> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ] ] \* Initialize new variable

\* MyNetAggInit remains unchanged for the core Raft state, entryCommitStats is handled in Init.
MyNetAggInit ==
    LET ServerIds == CHOOSE ids \in [1..5 -> Server] :
                        \A i, j \in 1..5 : i # j => ids[i] # ids[j]
        r1 == ServerIds[1]
        r2 == ServerIds[2]
        r3 == ServerIds[3]
        r4 == ServerIds[4]
        r5 == ServerIds[5]
    IN
    /\ switchIndex = r1
    /\ netAggPerServerSendIndex = r2
    /\ Servers = Server \ {r1, r2}
    /\ commitIndex = [s \in Server |-> 0]
    /\ currentTerm = [s \in Server |-> 2]
    /\ leaderCount = [s \in Server |-> IF s = r2 THEN 1 ELSE 0]
    /\ log = [s \in Server |-> <<>>]
    /\ matchIndex = [s \in Server |-> [t \in Server |-> 0]]
    /\ maxc = 0
    /\ messages = [m \in {} |-> 0]  \* Start with empty messages
    /\ netAggRecentSentEntries = [m \in {} |-> {}]
    /\ nextIndex = [s \in Server |-> [t \in Server |-> 1]]
    /\ state = [s \in Server |->
              CASE s = switchIndex -> Switch
              [] s = r2 -> NetAgg
              [] s = r3 -> Leader
              [] OTHER  -> Follower]
    /\ votedFor = [s \in Server |-> IF s = r3 THEN Nil ELSE r3]
    /\ voterLog = [s \in Server |-> IF s = r3 THEN (r4 :> <<>> @@ r5 :> <<>>) ELSE <<>>]
    /\ votesGranted = [s \in Server |-> IF s = r3 THEN {r4, r5} ELSE {}]
    /\ votesResponded = [s \in Server |-> IF s = r3 THEN {r4, r5} ELSE {}]
    /\ entryCommitStats = [ idx_term \in {} |-> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ] ] \* Initialize here too
    /\ switchToServerSentRecord = [s \in Server |-> {} ]
    /\ unorderedClientRequests = [s \in Server |-> {} ]
    /\ switchBuffer = [i \in {} |-> [term: Nat, value: STRING, payload: STRING]]



=============================================================================
\* Created by Ovidiu-Cristian Marcu