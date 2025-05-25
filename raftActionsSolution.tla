---------------------------- MODULE raftActionsSolution ----------------------------

EXTENDS raftInit

----
\* Define state transitions

\* Modified to allow Restarts only for Leaders
\* Server i restarts from stable storage.
\* It loses everything but its currentTerm, votedFor, and log.
\* Also persists messages and instrumentation vars elections, maxc, leaderCount, entryCommitStats
Restart(i) ==
    /\ state[i] = Leader \* limit restart to leaders todo mc
    /\ state'          = [state EXCEPT ![i] = Follower]
    /\ votesResponded' = [votesResponded EXCEPT ![i] = {}]
    /\ votesGranted'   = [votesGranted EXCEPT ![i] = {}]
    /\ voterLog'       = [voterLog EXCEPT ![i] = [j \in {} |-> <<>>]]
    /\ nextIndex'      = [nextIndex EXCEPT ![i] = [j \in Server |-> 1]]
    /\ matchIndex'     = [matchIndex EXCEPT ![i] = [j \in Server |-> 0]]
    /\ commitIndex'    = [commitIndex EXCEPT ![i] = 0]
    /\ UNCHANGED <<messages, currentTerm, votedFor, log, instrumentationVars, NetAgghovercraftVars, Servers>>

\* Modified to restrict Timeout to just Followers
\* Server i times out and starts a new election. Follower -> Candidate
Timeout(i) == /\ state[i] \in {Follower} \*, Candidate
              /\ currentTerm[i] < MaxTerm
              /\ state' = [state EXCEPT ![i] = Candidate]
              /\ currentTerm' = [currentTerm EXCEPT ![i] = currentTerm[i] + 1]
              \* Most implementations would probably just set the local vote
              \* atomically, but messaging localhost for it is weaker.
              /\ votedFor' = [votedFor EXCEPT ![i] = Nil]
              /\ votesResponded' = [votesResponded EXCEPT ![i] = {}]
              /\ votesGranted'   = [votesGranted EXCEPT ![i] = {}]
              /\ voterLog'       = [voterLog EXCEPT ![i] = [j \in {} |-> <<>>]]
              /\ UNCHANGED <<messages, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\* Modified to restrict Leader transitions, bounded by MaxBecomeLeader
\* Candidate i transitions to leader. Candidate -> Leader
BecomeLeader(i) ==
    /\ state[i] = Candidate
    /\ votesGranted[i] \in Quorum
    /\ leaderCount[i] < MaxBecomeLeader
    /\ state'      = [state EXCEPT ![i] = Leader]
    /\ nextIndex'  = [nextIndex EXCEPT ![i] =
                         [j \in Server |-> Len(log[i]) + 1]]
    /\ matchIndex' = [matchIndex EXCEPT ![i] =
                         [j \in Server |-> 0]]
    /\ leaderCount' = [leaderCount EXCEPT ![i] = leaderCount[i] + 1]
    /\ UNCHANGED <<messages, currentTerm, votedFor, candidateVars, logVars, maxc, entryCommitStats, NetAgghovercraftVars, Servers>>

\* Modified up to MaxTerm; Back To Follower
\* Any RPC with a newer term causes the recipient to advance its term first.
UpdateTerm(i, j, m) ==
    /\ m.mterm > currentTerm[i]
    /\ m.mterm < MaxTerm
    /\ currentTerm'    = [currentTerm EXCEPT ![i] = m.mterm]
    /\ state'          = [state       EXCEPT ![i] = Follower]
    /\ votedFor'       = [votedFor    EXCEPT ![i] = Nil]
       \* messages is unchanged so m can be processed further.
    /\ UNCHANGED <<messages, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\***************************** REQUEST VOTE **********************************************
\* Message handlers
\* i = recipient, j = sender, m = message

\* Candidate i sends j a RequestVote request.
RequestVote(i, j) ==
    /\ state[i] = Candidate
    /\ j \notin votesResponded[i]
    /\ Send([mtype         |-> RequestVoteRequest,
             mterm         |-> currentTerm[i],
             mlastLogTerm  |-> LastTerm(log[i]),
             mlastLogIndex |-> Len(log[i]),
             msource       |-> i,
             mdest         |-> j])
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\* Server i receives a RequestVote request from server j with
\* m.mterm <= currentTerm[i].
HandleRequestVoteRequest(i, j, m) ==
    LET logOk == \/ m.mlastLogTerm > LastTerm(log[i])
                 \/ /\ m.mlastLogTerm = LastTerm(log[i])
                    /\ m.mlastLogIndex >= Len(log[i])
        grant == /\ m.mterm = currentTerm[i]
                 /\ logOk
                 /\ votedFor[i] \in {Nil, j}
    IN /\ m.mterm <= currentTerm[i]
       /\ \/ grant  /\ votedFor' = [votedFor EXCEPT ![i] = j]
          \/ ~grant /\ UNCHANGED votedFor
       /\ Reply([mtype        |-> RequestVoteResponse,
                 mterm        |-> currentTerm[i],
                 mvoteGranted |-> grant,
                 \* mlog is used just for the `elections' history variable for
                 \* the proof. It would not exist in a real implementation.
                 mlog         |-> log[i],
                 msource      |-> i,
                 mdest        |-> j],
                 m)
       /\ UNCHANGED <<state, currentTerm, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\* Server i receives a RequestVote response from server j with
\* m.mterm = currentTerm[i].
HandleRequestVoteResponse(i, j, m) ==
    \* This tallies votes even when the current state is not Candidate, but
    \* they won't be looked at, so it doesn't matter.
    /\ m.mterm = currentTerm[i]
    /\ votesResponded' = [votesResponded EXCEPT ![i] =
                              votesResponded[i] \cup {j}]
    /\ \/ /\ m.mvoteGranted
          /\ votesGranted' = [votesGranted EXCEPT ![i] =
                                  votesGranted[i] \cup {j}]
          /\ voterLog' = [voterLog EXCEPT ![i] =
                              voterLog[i] @@ (j :> m.mlog)]
       \/ /\ ~m.mvoteGranted
          /\ UNCHANGED <<votesGranted, voterLog>>
    /\ Discard(m)
    /\ UNCHANGED <<serverVars, votedFor, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\* Responses with stale terms are ignored.
DropStaleResponse(i, j, m) ==
    /\ m.mterm < currentTerm[i]
    /\ Discard(m)
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\***************************** AppendEntries **********************************************

SwitchReplicateClientRequest(i, v) == 
    /\ \E j \in DOMAIN switchBuffer: j = v \* Check if v is a valid switch request
    /\ ~(\E entry \in switchToServerSentRecord[i]: entry = <<switchBuffer[v].value, switchBuffer[v].term>>)
    /\ switchToServerSentRecord' = [switchToServerSentRecord EXCEPT ![i] = switchToServerSentRecord[i] \cup {<<switchBuffer[v].value, switchBuffer[v].term>>} ]
    /\ unorderedClientRequests' = [unorderedClientRequests EXCEPT ![i] = unorderedClientRequests[i] \cup {switchBuffer[v].value} ]
    /\ UNCHANGED <<messages, serverVars, candidateVars, leaderVars, logVars, instrumentationVars, switchIndex, netAggPerServerSendIndex, switchBuffer, netAggRecentSentEntries, Servers>> 

\* The leader adds the request to its log after receiving it from the switch. then notifies NetAgg of the AppendEntry.
LeaderIngressHovercRaftRequest(i, v) == 
    /\ state[i] = Leader    
    /\ \E j \in DOMAIN switchBuffer: v = j \* Verify that v is a legitimate switch request.
    /\ \E j \in unorderedClientRequests[i] : v = j \* Verify whether the leader server has already received the switch's request v.
    /\ ~(\E j \in DOMAIN log[i] : log[i][j] = switchBuffer[v])   
    /\ LET entryTerm == switchBuffer[v].term
           entry == switchBuffer[v]
           entries == << [term |-> entry.term, value |-> entry.value] >>
           newLog == Append(log[i], entry)
           newEntryIndex == Len(log[i]) + 1
           prevLogIndex == newEntryIndex - 1
           prevLogTerm == IF prevLogIndex > 0 THEN
                              log[i][prevLogIndex].term
                          ELSE 0
           newEntryKey == <<newEntryIndex, entryTerm>>
           message == [mtype          |-> AppendEntriesRequest,
                mterm          |-> currentTerm[i],
                mprevLogIndex  |-> prevLogIndex,
                mprevLogTerm   |-> prevLogTerm,
                mentries       |-> entries, \* This no longer includes the complete request; it now only includes metadata information.
                
                \* The proof uses mlog as a history variable.
                \* It would not exist in a real implementation.
                mcommitIndex   |-> Min({commitIndex[i], newEntryIndex}), 
                msource        |-> i,
                mdest          |-> netAggPerServerSendIndex]
       IN Send(message)
        /\ log' = [log EXCEPT ![i] = newLog]
        /\ unorderedClientRequests' = [unorderedClientRequests EXCEPT ![i] = @ \ {v}]
        /\ entryCommitStats' =
              IF newEntryIndex > 0 \* Only add stats for truly new entries
              THEN entryCommitStats @@ (newEntryKey :> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ])
              ELSE entryCommitStats
\*   Should leader still be responsible for initializing entryCommitStats?
\*   After sending this to switch, shouldn't leader increase its matchCommitIndex and nextIndex values?           
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, commitIndex, leaderCount, maxc, switchBuffer, switchIndex, netAggPerServerSendIndex, switchToServerSentRecord, netAggRecentSentEntries, Servers>>


\* Modified. Leader i receives a client request to add v to the log. up to MaxClientRequests.
ClientRequest(i, v) == 
    /\ state[i] = Leader
    /\ \E s \in Server: state[s] = Switch
    \* Make sure prevoius requests have been served before serving new request (for debugging purposes)
    \* /\ \A i \in DOMAIN switchBuffer, s \in Servers: <<switchBuffer[i].value, switchBuffer[i].term>> \in switchToServerSentRecord[s]
    /\ maxc < MaxClientRequests
    /\ LET 
           entryTerm == currentTerm[i]
           entry == [term |-> entryTerm, value |-> v, payload |-> v]
           entryExists == \E r \in DOMAIN switchBuffer: entry = switchBuffer[r]
      IN
           IF ~entryExists THEN
            /\ maxc' = maxc + 1
            /\ switchBuffer' = switchBuffer @@ (v :> entry)
           ELSE UNCHANGED <<maxc, switchBuffer>>
    /\ UNCHANGED <<messages, serverVars, candidateVars, leaderVars, logVars, leaderCount, entryCommitStats, switchIndex, netAggPerServerSendIndex, switchToServerSentRecord, unorderedClientRequests, netAggRecentSentEntries, Servers>>



\* Modified. Leader i sends j an AppendEntries request containing exactly 1 entry. It was up to 1 entry.
\* While implementations may want to send more than 1 at a time, this spec uses
\* just 1 because it minimizes atomic regions without loss of generality.
AppendEntries(i, j, m) ==  
    /\ i /= j
    /\ state[i] = Leader
    /\ m.mentries /= <<>>
    /\ Len(log[i]) > 0  \* Only proceed if the leader has entries to send
    /\ m.mprevLogIndex < nextIndex[i][j] \* Only send if follower hasn't already acknowledged this index
\*    /\ nextIndex[i][j] <= Len(log[i])  \*  Only proceed if there are entries to send to this follower
\*    /\ matchIndex[i][j] < nextIndex[i][j] \* Only send if follower hasn't already acknowledged this index
    /\ j \notin netAggRecentSentEntries[m] \* Append entries for this message not yet sent to this server
    /\ \E r \in unorderedClientRequests[j] : Head(m.mentries).value = r \* Check if server has already received request v from switch
    /\ LET  
           entryIndex == m.mprevLogIndex + 1
           entry == Head(m.mentries)
           entries == m.mentries
           entryKey == <<entryIndex, entry.term>>
           updatedSource == [m EXCEPT !.msource = netAggPerServerSendIndex]
           message == [updatedSource EXCEPT !.mdest = j]
           
       IN 
       /\ netAggRecentSentEntries' = [netAggRecentSentEntries EXCEPT ![m] = @ \cup {j}]
       /\ entryCommitStats' =
            IF entryKey \in DOMAIN entryCommitStats /\ ~entryCommitStats[entryKey].committed
            THEN [entryCommitStats EXCEPT ![entryKey].sentCount = @ + 1]
            ELSE entryCommitStats  
       /\ Send(message)       
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, maxc, leaderCount, switchBuffer, switchIndex, switchToServerSentRecord, unorderedClientRequests, netAggPerServerSendIndex, Servers>>  

\* Leader provides NetAgg with append entries, which it uses to update its message sent cache before discarding the message.
ProcessAppendEntriesFromNetAgg(i, m) ==  
    /\ state[i] = NetAgg
    /\ state[m.msource] = Leader
    /\ ~(\E msg \in DOMAIN netAggRecentSentEntries: Cardinality(netAggRecentSentEntries[msg]) < Cardinality(Servers)-1) \* Only accept once every prior message has been sent.
    /\ m.mentries /= <<>>
    /\ netAggRecentSentEntries' = netAggRecentSentEntries @@ (m :> {})
    /\ Discard(m)
    /\ UNCHANGED <<entryCommitStats, serverVars, candidateVars, leaderVars, logVars, maxc, leaderCount,switchBuffer, switchIndex, switchToServerSentRecord, unorderedClientRequests, netAggPerServerSendIndex, Servers>>  

\* Server j sends a request for AppendEntries to server i with
\* m.mterm <= currentTerm[i]. This just handles m.entries of length 0 or 1, but
\* implementations could safely accept more by treating them the same as
\* multiple independent requests of 1 entry.
NetAggHandleAppendEntriesRequests(i, j, m) ==
    LET logOk == \/ m.mprevLogIndex = 0
                 \/ /\ m.mprevLogIndex > 0
                    /\ m.mprevLogIndex <= Len(log[i])
                    /\ m.mprevLogTerm = log[i][m.mprevLogIndex].term
    IN /\ m.mterm <= currentTerm[i]
       /\ \/ /\ \* reject request
                \/ m.mterm < currentTerm[i]
                \/ /\ m.mterm = currentTerm[i]
                   /\ state[i] = Follower
                   /\ \lnot logOk
             /\ Reply([mtype           |-> AppendEntriesResponse,
                       mterm           |-> currentTerm[i],
                       msuccess        |-> FALSE,
                       mmatchIndex     |-> 0,
                       msource         |-> i,
                       mdest           |-> j],
                       m)
             /\ UNCHANGED <<serverVars, logVars, unorderedClientRequests>>
          \/ \* return to follower state
             /\ m.mterm = currentTerm[i]
             /\ state[i] = Candidate
             /\ state' = [state EXCEPT ![i] = Follower]
             /\ UNCHANGED <<currentTerm, votedFor, logVars, messages, unorderedClientRequests>>
          \/ \* accept request
             /\ m.mterm = currentTerm[i]
             /\ state[i] = Follower
             /\ logOk
             /\ LET index == m.mprevLogIndex + 1
                IN \/ \* already done with request
                       /\ \/ m.mentries = << >>
                          \/ /\ m.mentries /= << >>
                             /\ Len(log[i]) >= index
                             /\ log[i][index].term = m.mentries[1].term
                          \* This could make our commitIndex decrease (for
                          \* example if we process an old, duplicated request),
                          \* but that doesn't really affect anything.
                       /\ commitIndex' = [commitIndex EXCEPT ![i] =
                                              m.mcommitIndex]
                       /\ Reply([mtype           |-> AppendEntriesResponse,
                                 mterm           |-> currentTerm[i],
                                 msuccess        |-> TRUE,
                                 mmatchIndex     |-> m.mprevLogIndex +
                                                     Len(m.mentries),
                                 msource         |-> i,
                                 mdest           |-> j],
                                 m)
                       /\ UNCHANGED <<serverVars, log, unorderedClientRequests>>
                   \/ \* conflict: remove 1 entry (simplified from original spec - assumes entry length 1)
                      \* We must supply a wider range of values to guarantee some progress because we don't transmit blank entries.
                       /\ m.mentries /= << >>
                       /\ Len(log[i]) >= index
                       /\ log[i][index].term /= m.mentries[1].term
                       /\ LET newLog == SubSeq(log[i], 1, index - 1) \* Truncate log
                          IN log' = [log EXCEPT ![i] = newLog]
                       /\ UNCHANGED <<serverVars, commitIndex, messages, unorderedClientRequests>>

                       
                   \/ \* no conflict: append entry
                       /\ m.mentries /= << >>
                       /\ \E k \in unorderedClientRequests[i]: k = m.mentries[1].value
                       /\ Len(log[i]) = m.mprevLogIndex
                       /\ LET entryId == CHOOSE id \in DOMAIN switchBuffer: switchBuffer[id].term = m.mentries[1].term /\ switchBuffer[id].value = m.mentries[1].value 
                              entry == switchBuffer[entryId]
                          IN /\ log' = [log EXCEPT ![i] = Append(log[i], entry)] \* Add this entry to log, this includes the payload
                             /\ unorderedClientRequests' = [unorderedClientRequests EXCEPT ![i] = @ \ {m.mentries[1].value}]
                       /\ UNCHANGED <<serverVars, commitIndex, messages>>
       /\ UNCHANGED <<candidateVars, leaderVars, instrumentationVars, switchBuffer, switchIndex, netAggPerServerSendIndex, switchToServerSentRecord, netAggRecentSentEntries, Servers>> \* entryCommitStats unchanged on followers

\* NetAgg receives an AppendEntries response from server j with
\* m.mterm = currentTerm[leader].
NetAggHandleAppendEntriesResponses(agg, j, m) ==
\*    /\ m.mterm = currentTerm[i]
    /\ state[agg] = NetAgg
    /\ \/ /\ m.msuccess \* successful
          /\ LET \*newMatchIndex == IF matchIndex[i][j] > m.mmatchIndex THEN matchIndex[i][j] ELSE m.mmatchIndex
                 i == CHOOSE s \in Server: state[s] = Leader
                 newMatchIndex == m.mmatchIndex
                 entryKey == IF newMatchIndex > 0 /\ newMatchIndex <= Len(log[i])
                              THEN <<newMatchIndex, log[i][newMatchIndex].term>>
                              ELSE <<0, 0>> \* Invalid index or empty log
             IN /\ m.mterm = currentTerm[i]
                /\ nextIndex'  = [nextIndex  EXCEPT ![i][j] = m.mmatchIndex + 1]
                /\ matchIndex' = [matchIndex EXCEPT ![i][j] = m.mmatchIndex]
                /\ entryCommitStats' =
                     IF /\ entryKey /= <<0, 0>>
                        /\ entryKey \in DOMAIN entryCommitStats
                        /\ ~entryCommitStats[entryKey].committed
                     THEN [entryCommitStats EXCEPT ![entryKey].ackCount = @ + 1]
                     ELSE entryCommitStats                     
       \/ /\ \lnot m.msuccess \* not successful
          /\ LET i == CHOOSE s \in Server: state[s] = Leader
             IN nextIndex' = [nextIndex EXCEPT ![i][j] =
                               Max({nextIndex[i][j] - 1, 1})]
          /\ UNCHANGED <<matchIndex, entryCommitStats>>
    /\ Discard(m)
    /\ UNCHANGED <<serverVars, candidateVars, logVars, maxc, leaderCount, NetAgghovercraftVars, Servers>>

\* The Leader's commit index is advanced by NetAgg j.
\* This is carried out independently of managing AppendEntries responses.,
\* in part to minimize atomic regions, and in part so that leaders of
\* single-server clusters are able to mark entries committed.
AdvanceCommitIndex(j) ==
    /\ state[j] = NetAgg
    /\ LET i == CHOOSE s \in Server: state[s] = Leader
           \* The set of servers that agree up through index.
           Agree(index) == {i} \cup {k \in Servers :
                                         matchIndex[i][k] >= index}
           \* The maximum indexes for which a quorum agrees
           agreeIndexes == {index \in 1..Len(log[i]) :
                                Agree(index) \in Quorum}
           \* New value for commitIndex'[i]
           newCommitIndex ==
              IF /\ agreeIndexes /= {}
                 /\ log[i][Max(agreeIndexes)].term = currentTerm[i]
              THEN
                  Max(agreeIndexes)
              ELSE
                  commitIndex[i]
           committedIndexes == { k \in Nat : /\ k > commitIndex[i]
                                             /\ k <= newCommitIndex }
           \* Determine the entry keys.The CommitStats for recently committed entries
           keysToUpdate == { key \in DOMAIN entryCommitStats : key[1] \in committedIndexes }           
       IN /\ commitIndex' = [commitIndex EXCEPT ![i] = newCommitIndex]
          \*The 'committed' flag should be updated for the necessary entries in entryCommitStats
          /\ entryCommitStats' =
               [ key \in DOMAIN entryCommitStats |->
                   IF key \in keysToUpdate
                   THEN [ entryCommitStats[key] EXCEPT !.committed = TRUE ] \* Update record
                   ELSE entryCommitStats[key] ]                             \* Keep old record       
    /\ UNCHANGED <<messages, serverVars, candidateVars, leaderVars, log, maxc, leaderCount, NetAgghovercraftVars, Servers>>


\* Network state transitions

\* The network duplicates a message
DuplicateMessage(m) ==
    /\ Send(m)
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

\* The network drops a message
DropMessage(m) ==
    /\ Discard(m)
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars, NetAgghovercraftVars, Servers>>

=============================================================================
\* Created by Ovidiu-Cristian Marcu