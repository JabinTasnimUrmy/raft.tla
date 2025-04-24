---------------------------- MODULE raftActionsSolution ----------------------------

EXTENDS raftInit

----
\* Define state transitions

\* Modified to allow Restarts only for Leaders
\* Server i restarts from stable storage.
\* It loses everything but its currentTerm, votedFor, and log.
\* Also persists messages and instrumentation vars elections, maxc, leaderCount, entryCommitStats


ClientRequestViaSwitch(v) ==
    /\ maxc < MaxClientRequests  
    /\ LET newReqId == maxc + 1
           
           newCacheEntry == [value |-> v, payload |-> v, reqId |-> newReqId]
       IN
          
          /\ serverCache' = [ s \in Server |-> serverCache[s] \cup {newCacheEntry} ]
          
          /\ maxc' = newReqId
    
    /\ UNCHANGED <<messages, logVars, serverVars, candidateVars, leaderVars, entryCommitStats, leaderCount>>


\* Leader i selects a request from its cache and adds corresponding metadata to its log.
LeaderLogMetadata(i) ==
    /\ state[i] = Leader
   
    /\ serverCache[i] /= {}
    /\ LET LogIsEmpty == Len(log[i]) = 0
           EntriesInLog == {log[i][idx].reqId : idx \in DOMAIN log[i]}
           CacheHasNewEntry == \E ce \in serverCache[i] : ce.reqId \notin EntriesInLog
       IN (LogIsEmpty \/ CacheHasNewEntry)
    /\ LET
         
         entryToLog == CHOOSE ce \in serverCache[i] :
                          ce.reqId \notin {log[i][idx].reqId : idx \in DOMAIN log[i]}

         
         metadataLogEntry == [ term    |-> currentTerm[i],
                                value   |-> entryToLog.value,
                                reqId   |-> entryToLog.reqId ]

         newEntryIndex == Len(log[i]) + 1
         newEntryKey == <<newEntryIndex, metadataLogEntry.term>>
       IN
        
         /\ log' = [log EXCEPT ![i] = Append(log[i], metadataLogEntry)] 

        
         /\ entryCommitStats' =
              entryCommitStats @@ (newEntryKey :> [ sentCount |-> 0, ackCount |-> 0, committed |-> FALSE ])

        
         /\ serverCache' = [serverCache EXCEPT ![i] = @ \ {entryToLog}]

   
    /\ UNCHANGED <<messages, serverVars, candidateVars, leaderVars, commitIndex, leaderCount, maxc>>


\* Leader i sends metadata for a log entry to follower j.
AppendMetadata(i, j) ==
    /\ i /= j
    /\ state[i] = Leader
    /\ nextIndex[i][j] <= Len(log[i])  
    /\ LET entryIndex == nextIndex[i][j]
           metadataEntry == log[i][entryIndex]
           entriesToSend == << metadataEntry >>
           prevLogIndex == entryIndex - 1
           prevLogTerm == IF prevLogIndex > 0 THEN log[i][prevLogIndex].term ELSE 0
           entryKey == <<entryIndex, metadataEntry.term>>
       IN
        
         /\ Send([mtype          |-> AppendEntriesRequest, 
                  mterm          |-> currentTerm[i],
                  mprevLogIndex  |-> prevLogIndex,
                  mprevLogTerm   |-> prevLogTerm,
                  mentries       |-> entriesToSend,  
                  mcommitIndex   |-> Min({commitIndex[i], prevLogIndex}),
                  msource        |-> i,
                  mdest          |-> j]) 

        
         /\ entryCommitStats' =
            IF entryKey \in DOMAIN entryCommitStats /\ ~entryCommitStats[entryKey].committed
            THEN [entryCommitStats EXCEPT ![entryKey].sentCount = @ + 1]
            ELSE entryCommitStats 

   
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, maxc, leaderCount, serverCache>>


\* Follower i handles metadata AppendEntries request from leader j.
HandleMetadataRequest(i, j, m) ==
    LET logOk == \/ m.mprevLogIndex = 0
                 \/ /\ m.mprevLogIndex > 0
                    /\ m.mprevLogIndex <= Len(log[i])
                    /\ log[i][m.mprevLogIndex].term = m.mprevLogTerm
    IN
    
    \/ /\ m.mterm < currentTerm[i]
       /\ Reply([mtype |-> AppendEntriesResponse, mterm |-> currentTerm[i], msuccess |-> FALSE, mmatchIndex |-> 0], m) 
       
       /\ UNCHANGED <<serverVars, logVars, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount, serverCache>>

    
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Follower
       /\ \lnot logOk
       /\ Reply([mtype |-> AppendEntriesResponse, mterm |-> currentTerm[i], msuccess |-> FALSE, mmatchIndex |-> 0], m)
      
       /\ UNCHANGED <<serverVars, logVars, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount, serverCache>>

  
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Candidate
       /\ state' = [state EXCEPT ![i] = Follower] 
      
       /\ UNCHANGED <<currentTerm, votedFor, logVars, messages, serverCache, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount>>

    
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Follower
       /\ logOk
       /\ m.mentries = << >>
       /\ commitIndex' = [commitIndex EXCEPT ![i] = Max({commitIndex[i], m.mcommitIndex})] 
       /\ Reply([mtype |-> AppendEntriesResponse, mterm |-> currentTerm[i], msuccess |-> TRUE, mmatchIndex |-> m.mprevLogIndex], m)
      
       /\ UNCHANGED <<serverVars, log, serverCache, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount>>

  
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Follower
       /\ logOk
       /\ m.mentries /= << >>
       /\ LET entryMetadata == m.mentries[1]
              MatchingCacheEntries == { ce \in serverCache[i] : ce.reqId = entryMetadata.reqId }
          IN MatchingCacheEntries = {}
       /\ Reply([mtype |-> AppendEntriesResponse, mterm |-> currentTerm[i], msuccess |-> FALSE, mmatchIndex |-> 0], m)
     
       /\ UNCHANGED <<serverVars, logVars, serverCache, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount>>

  
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Follower
       /\ logOk
       /\ m.mentries /= << >>
       /\ LET entryMetadata == m.mentries[1]
              MatchingCacheEntries == { ce \in serverCache[i] : ce.reqId = entryMetadata.reqId }
              index_cond == m.mprevLogIndex + 1
          IN /\ MatchingCacheEntries /= {} 
             /\ Len(log[i]) >= index_cond
             /\ LET MatchingCacheEntry == CHOOSE ce \in MatchingCacheEntries : TRUE
                IN log[i][index_cond].term /= entryMetadata.term
       /\ LET index_eff == m.mprevLogIndex + 1
              newLog == SubSeq(log[i], 1, index_eff - 1)
          IN log' = [log EXCEPT ![i] = newLog] 
      
       /\ UNCHANGED <<serverVars, commitIndex, messages, serverCache, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount>>

   
    \/ /\ m.mterm = currentTerm[i]
       /\ state[i] = Follower
       /\ logOk
       /\ m.mentries /= << >>
       /\ LET entryMetadata == m.mentries[1]
              MatchingCacheEntries == { ce \in serverCache[i] : ce.reqId = entryMetadata.reqId }
              index == m.mprevLogIndex + 1
          IN /\ MatchingCacheEntries /= {} 
             /\ LET MatchingCacheEntry == CHOOSE ce \in MatchingCacheEntries : TRUE
                IN \/ Len(log[i]) = index - 1 
                   \/ /\ Len(log[i]) >= index   
                      /\ log[i][index].term = entryMetadata.term 
                      /\ log[i][index].reqId = entryMetadata.reqId 
       
       /\ LET MatchingCacheEntry == CHOOSE ce \in { c \in serverCache[i] : c.reqId = m.mentries[1].reqId } : TRUE
              fullEntryToLog == [ term    |-> m.mentries[1].term,
                                  value   |-> MatchingCacheEntry.value,
                                  payload |-> MatchingCacheEntry.payload,
                                  reqId   |-> m.mentries[1].reqId ]
              index == m.mprevLogIndex + 1
          IN log' = IF Len(log[i]) = index - 1
                     THEN [log EXCEPT ![i] = Append(log[i], fullEntryToLog)]
                     ELSE log 
       /\ commitIndex' = [commitIndex EXCEPT ![i] = Max({commitIndex[i], m.mcommitIndex})] 
       /\ LET MatchingCacheEntry == CHOOSE ce \in { c \in serverCache[i] : c.reqId = m.mentries[1].reqId } : TRUE
           IN serverCache' = [serverCache EXCEPT ![i] = @ \ {MatchingCacheEntry}] 
       /\ Reply([mtype |-> AppendEntriesResponse, mterm |-> currentTerm[i], msuccess |-> TRUE, mmatchIndex |-> m.mprevLogIndex + 1], m) 
       /\ UNCHANGED <<serverVars, candidateVars, leaderVars, maxc, entryCommitStats, leaderCount>>

\* ===========================================================================
\* GIVEN RAFT ACTIONS 
\* ===========================================================================


Restart(i) ==
    /\ state[i] = Leader
    /\ state'          = [state EXCEPT ![i] = Follower]
    /\ votesResponded' = [votesResponded EXCEPT ![i] = {}]
    /\ votesGranted'   = [votesGranted EXCEPT ![i] = {}]
    /\ voterLog'       = [voterLog EXCEPT ![i] = [j \in {} |-> <<>>]]
    /\ nextIndex'      = [nextIndex EXCEPT ![i] = [j \in Server |-> Len(log[i]) + 1]]
    /\ matchIndex'     = [matchIndex EXCEPT ![i] = [j \in Server |-> 0]]
    /\ commitIndex'    = [commitIndex EXCEPT ![i] = 0]
    /\ serverCache'    = [serverCache EXCEPT ![i] = {}]
    /\ UNCHANGED <<messages, currentTerm, votedFor, log, maxc, leaderCount, entryCommitStats>>

\* Modified to restrict Timeout to just Followers
\* Server i times out and starts a new election. Follower -> Candidate
Timeout(i) ==
    /\ state[i] \in {Follower}
    /\ currentTerm[i] < MaxTerm
    /\ state' = [state EXCEPT ![i] = Candidate] 
    /\ currentTerm' = [currentTerm EXCEPT ![i] = currentTerm[i] + 1] 
    /\ votedFor' = [votedFor EXCEPT ![i] = Nil] 
    /\ votesResponded' = [votesResponded EXCEPT ![i] = {}] 
    /\ votesGranted'   = [votesGranted EXCEPT ![i] = {}] 
    /\ voterLog'       = [voterLog EXCEPT ![i] = [j \in {} |-> <<>>]] 
    /\ UNCHANGED <<messages, leaderVars, logVars, maxc, leaderCount, entryCommitStats, serverCache>>

\* Modified to restrict Leader transitions, bounded by MaxBecomeLeader
\* Candidate i transitions to leader. Candidate -> Leader
BecomeLeader(i) ==
    /\ state[i] = Candidate
    /\ votesGranted[i] \in Quorum
    /\ leaderCount[i] < MaxBecomeLeader
    /\ state'      = [state EXCEPT ![i] = Leader] 
    /\ nextIndex'  = [nextIndex EXCEPT ![i] = [j \in Server |-> Len(log[i]) + 1]] 
    /\ matchIndex' = [matchIndex EXCEPT ![i] = [j \in Server |-> 0]] 
    /\ leaderCount' = [leaderCount EXCEPT ![i] = leaderCount[i] + 1] 
    /\ UNCHANGED <<messages, currentTerm, votedFor, candidateVars, logVars, maxc, entryCommitStats, serverCache>>

\* Modified up to MaxTerm; Back To Follower
\* Any RPC with a newer term causes the recipient to advance its term first.
UpdateTerm(i, j, m) ==
    /\ m.mterm > currentTerm[i]
    /\ m.mterm < MaxTerm
    /\ currentTerm' = [currentTerm EXCEPT ![i] = m.mterm] 
    /\ state'       = [state       EXCEPT ![i] = Follower]
    /\ votedFor'    = [votedFor    EXCEPT ![i] = Nil] 
    /\ UNCHANGED <<messages, candidateVars, leaderVars, logVars, maxc, leaderCount, entryCommitStats, serverCache>>



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
    
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, maxc, leaderCount, entryCommitStats, serverCache>>



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
                 mlog         |-> << >>,
                 msource      |-> i,
                 mdest        |-> j],
                 m) 
       /\ UNCHANGED <<state, currentTerm, candidateVars, leaderVars, logVars, maxc, leaderCount, entryCommitStats, serverCache>>



\* Server i receives a RequestVote response from server j with
\* m.mterm = currentTerm[i].
HandleRequestVoteResponse(i, j, m) ==
\* This tallies votes even when the current state is not Candidate, but
\* they won't be looked at, so it doesn't matter.
    /\ m.mterm = currentTerm[i]
    /\ votesResponded' = [votesResponded EXCEPT ![i] = votesResponded[i] \cup {j}] 
    /\ \/ /\ m.mvoteGranted
          /\ votesGranted' = [votesGranted EXCEPT ![i] = votesGranted[i] \cup {j}] 
          /\ UNCHANGED voterLog
       \/ /\ ~m.mvoteGranted
          /\ UNCHANGED <<votesGranted, voterLog>>
    /\ Discard(m)
  
    /\ UNCHANGED <<serverVars, votedFor, leaderVars, logVars, maxc, leaderCount, entryCommitStats, serverCache>>




\* Responses with stale terms are ignored.
DropStaleResponse(i, j, m) ==
    /\ m.mterm < currentTerm[i]
    /\ Discard(m) \* Assigns messages'
    \* Corrected: Explicit list excluding messages
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars>>


\***************************** AppendEntries **********************************************
\* Server i receives an AppendEntries response from server j.
\* Server i receives an AppendEntries request from server j with
\* m.mterm <= currentTerm[i]. This just handles m.entries of length 0 or 1, but
\* implementations could safely accept more by treating them the same as
\* multiple independent requests of 1 entry.
HandleAppendEntriesResponse(i, j, m) ==
    /\ m.mterm = currentTerm[i]
    /\ \/ /\ m.msuccess 
          /\ LET newMatchIndex == m.mmatchIndex
                 entryKey == IF newMatchIndex > 0 /\ newMatchIndex <= Len(log[i])
                              THEN <<newMatchIndex, log[i][newMatchIndex].term>>
                              ELSE <<0, 0>>
             IN /\ nextIndex'  = [nextIndex  EXCEPT ![i][j] = newMatchIndex + 1] 
                /\ matchIndex' = [matchIndex EXCEPT ![i][j] = newMatchIndex] 
                /\ entryCommitStats' =
                     IF /\ entryKey /= <<0, 0>>
                        /\ entryKey \in DOMAIN entryCommitStats
                        /\ ~entryCommitStats[entryKey].committed
                     THEN [entryCommitStats EXCEPT ![entryKey].ackCount = @ + 1]
                     ELSE entryCommitStats 
             /\ UNCHANGED <<serverVars, candidateVars, log, maxc, leaderCount, serverCache>>
       \/ /\ \lnot m.msuccess 
          /\ nextIndex' = [nextIndex EXCEPT ![i][j] = Max({nextIndex[i][j] - 1, 1})] 
          /\ UNCHANGED <<matchIndex, entryCommitStats, serverVars, candidateVars, logVars, maxc, leaderCount, serverCache>>
    /\ Discard(m) 
    /\ UNCHANGED <<serverVars, candidateVars, logVars, maxc, leaderCount, serverCache>>



\* Leader i advances its commitIndex.
\* Leader i advances its commitIndex.
\* This is done as a separate step from handling AppendEntries responses,
\* in part to minimize atomic regions, and in part so that leaders of
\* single-server clusters are able to mark entries committed.
AdvanceCommitIndex(i) ==
    /\ state[i] = Leader
    /\ LET Agree(index) == {i} \cup {k \in Server : matchIndex[i][k] >= index}
           agreeIndexes == {index \in 1..Len(log[i]) : Agree(index) \in Quorum}
           newCommitIndex ==
              IF /\ agreeIndexes /= {}
                 /\ log[i][Max(agreeIndexes)].term = currentTerm[i]
              THEN Max(agreeIndexes)
              ELSE commitIndex[i]
           committedIndexes == { k \in Nat : k > commitIndex[i] /\ k <= newCommitIndex }
           keysToUpdate == { key \in DOMAIN entryCommitStats : key[1] \in committedIndexes }
       IN /\ commitIndex' = [commitIndex EXCEPT ![i] = newCommitIndex] 
          /\ entryCommitStats' =
               [ key \in DOMAIN entryCommitStats |->
                   IF key \in keysToUpdate
                   THEN [ entryCommitStats[key] EXCEPT !.committed = TRUE ]
                   ELSE entryCommitStats[key] ] 
    /\ UNCHANGED <<messages, serverVars, candidateVars, leaderVars, log, maxc, leaderCount, serverCache>>

\* Network state transitions

\* The network duplicates a message
DuplicateMessage(m) ==
    /\ Send(m) 
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars>>

\* The network drops a message
DropMessage(m) ==
    /\ Discard(m) 
    /\ UNCHANGED <<serverVars, candidateVars, leaderVars, logVars, instrumentationVars>>

=============================================================================
\* Created by Ovidiu-Cristian Marcu