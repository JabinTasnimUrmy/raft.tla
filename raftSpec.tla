------------------------------ MODULE raftSpec ------------------------------

\* This is the formal specification for the Raft consensus algorithm.
\* Modified by Ovidiu Marcu. Simplified model and performance invariants added.
\* Modified further to track message counts for entry commitment.
\*
\* Copyright 2014 Diego Ongaro.
\* This work is licensed under the Creative Commons Attribution-4.0
\* International License https://creativecommons.org/licenses/by/4.0/

EXTENDS Naturals, Sequences, FiniteSets, TLC,
        raftConstants, raftVariables, raftHelpers, raftInit,
        raftActionsSolution
        


MySpecInit == MyInit 


\* Receive a message.
Receive(m) ==
    LET i == m.mdest
        j == m.msource
    IN \* Any RPC with a newer term causes the recipient to advance
       \* its term first. Responses with stale terms are ignored.
       \/ UpdateTerm(i, j, m)
       \/ /\ m.mtype = RequestVoteRequest
          /\ HandleRequestVoteRequest(i, j, m)
       \/ /\ m.mtype = RequestVoteResponse
          /\ \/ DropStaleResponse(i, j, m)
             \/ HandleRequestVoteResponse(i, j, m)
       \/ /\ m.mtype = AppendEntriesRequest
          /\ HandleMetadataRequest(i, j, m)
       \/ /\ m.mtype = AppendEntriesResponse
          /\ \/ DropStaleResponse(i, j, m)
             \/ HandleAppendEntriesResponse(i, j, m)

Next == 
           \/ \E i \in Server : Timeout(i)
\*           \/ \E i \in Server : Restart(i)
           \/ \E i,j \in Server : i /= j /\ RequestVote(i, j)
           \/ \E i \in Server : BecomeLeader(i)
           \/ \E i \in Server, v \in Value : state[i] = Leader /\ ClientRequestViaSwitch(v)
           \/ \E i \in Server : AdvanceCommitIndex(i)
           \/ \E i,j \in Server : i /= j /\ AppendMetadata(i, j)
           \/ \E m \in {msg \in ValidMessage(messages) : \* to visualize possible messages
                    msg.mtype \in {RequestVoteRequest, RequestVoteResponse, AppendEntriesRequest, AppendEntriesResponse}} : Receive(m)
\*           \/ \E m \in {msg \in ValidMessage(messages) : 
\*                    msg.mtype \in {AppendEntriesRequest}} : DuplicateMessage(m)
\*           \/ \E m \in {msg \in ValidMessage(messages) : 
\*                    msg.mtype \in {RequestVoteRequest}} : DropMessage(m)



IsMessageRecord(m) ==
    /\ DOMAIN m = {"mtype", "mterm", "msource", "mdest"} \cup CASE m.mtype = RequestVoteRequest   -> {"mlastLogTerm", "mlastLogIndex"}
                                                             [] m.mtype = RequestVoteResponse  -> {"mvoteGranted", "mlog"}
                                                             [] m.mtype = AppendEntriesRequest -> {"mprevLogIndex", "mprevLogTerm", "mentries", "mcommitIndex"}
                                                             [] m.mtype = AppendEntriesResponse-> {"msuccess", "mmatchIndex"}
                                                             [] OTHER -> {}
    /\ m.mtype \in {RequestVoteRequest, RequestVoteResponse, AppendEntriesRequest, AppendEntriesResponse}
    /\ m.mterm \in Nat
    /\ m.msource \in Server \cup {Switch}
    /\ m.mdest \in Server

IsLogEntry(e) ==
    /\ {"term", "value", "reqId"} \subseteq DOMAIN e  
    /\ e.term \in Nat
    /\ e.value \in Value
    /\ e.reqId \in Nat
    

IsCacheEntry(e) ==
    /\ DOMAIN e = {"value", "payload", "reqId"}
    /\ e.value \in Value
    /\ e.payload \in Value
    /\ e.reqId \in Nat



TypeOK ==
    /\ messages \in [DOMAIN messages -> Nat]
    /\ \A m \in DOMAIN messages : IsMessageRecord(m) /\ messages[m] >= 0
    /\ currentTerm \in [Server -> Nat]
    /\ state \in [Server -> {Follower, Candidate, Leader}]
    /\ votedFor \in [Server -> Server \cup {Nil}]
    /\ \A i \in Server: \A e \in SubSeq(log[i], 1, Len(log[i])) : IsLogEntry(e)
    /\ commitIndex \in [Server -> Nat]
    /\ votesResponded \in [Server -> SUBSET Server]
    /\ votesGranted \in [Server -> SUBSET Server]
    /\ \A i \in Server: \A j \in DOMAIN voterLog[i]: \A e \in SubSeq(voterLog[i][j], 1, Len(voterLog[i][j])): IsLogEntry(e)
    /\ nextIndex \in [Server -> [Server -> Nat \ {0}]]
    /\ matchIndex \in [Server -> [Server -> Nat]]
    /\ leaderCount \in [Server -> Nat]
    /\ maxc \in Nat
    /\ \A k \in DOMAIN entryCommitStats: Len(k)=2 /\ k[1]\in Nat /\ k[2]\in Nat
    /\ \A v \in {entryCommitStats[k] : k \in DOMAIN entryCommitStats} :
          DOMAIN v = {"sentCount", "ackCount", "committed"} /\ v.sentCount \in Nat /\ v.ackCount \in Nat /\ v.committed \in BOOLEAN
    /\ \A i \in Server: \A e \in serverCache[i] : IsCacheEntry(e)



MyNext ==
    \/ (\E v \in Value : ClientRequestViaSwitch(v))
    \/ (\E i \in Server : LeaderLogMetadata(i))
    \/ (\E i,j \in Server : AppendMetadata(i, j))
    \/ (\E i,j \in Server: \E m \in ValidMessage(messages):
           m.mtype = AppendEntriesRequest /\ HandleMetadataRequest(i, j, m))

   \*   \/ (\E i \in Server : Restart(i))
    \*  \/ (\E i \in Server : Timeout(i))
   \*   \/ (\E i \in Server : BecomeLeader(i))
  \*   \/ (\E i,j \in Server: \E m \in ValidMessage(messages): UpdateTerm(i, j, m))
   \*   \/ (\E i,j \in Server : RequestVote(i, j))
    \/ (\E i,j \in Server: \E m \in ValidMessage(messages):
           m.mtype = RequestVoteRequest /\ HandleRequestVoteRequest(i, j, m))
     \/ (\E i,j \in Server: \E m \in ValidMessage(messages):
           m.mtype = RequestVoteResponse /\ HandleRequestVoteResponse(i, j, m))
    \* \/ (\E i,j \in Server: \E m \in ValidMessage(messages): DropStaleResponse(i, j, m))
     \/ (\E i,j \in Server: \E m \in ValidMessage(messages):
            m.mtype = AppendEntriesResponse /\ HandleAppendEntriesResponse(i, j, m))
     \/ (\E i \in Server : AdvanceCommitIndex(i))

    \* -- Network Actions --
   \*   \/ (\E m \in ValidMessage(messages): DuplicateMessage(m))
    \*  \/ (\E m \in ValidMessage(messages): DropMessage(m))

Spec == Init /\ [][Next]_vars

MySpec == MySpecInit /\ [][MyNext]_vars /\ WF_vars(MyNext)



Invariant ==
    /\ TypeOK
    /\ ((\E i \in Server : state[i] = Leader) => maxc <= MaxClientRequests) 
    /\ (\A i \in Server : leaderCount[i] <= MaxBecomeLeader) 
    /\ (\A i \in Server : currentTerm[i] <= MaxTerm) 
    
    \* /\ LET MinFollowersForMajority == Cardinality(Server) \div 2
    \*        NumFollowers == Cardinality(Server) - 1
    \*    IN (\A key \in DOMAIN entryCommitStats :
    \*          LET stats == entryCommitStats[key]
    \*          IN IF stats.committed
    \*             THEN (stats.sentCount >= MinFollowersForMajority /\ stats.sentCount <= NumFollowers)
    \*                  \/ (stats.ackCount >= MinFollowersForMajority /\ stats.ackCount <= NumFollowers)
    \*             ELSE TRUE)
    
    /\ LET NumServers == Cardinality(Server) 
           MinFollowerAcksForMajority == NumServers \div 2
       IN (\A key \in DOMAIN entryCommitStats :
             LET stats == entryCommitStats[key]
             IN stats.committed => (stats.ackCount >= MinFollowerAcksForMajority))

=============================================================================