---------------------------- MODULE raftHelpers ----------------------------
EXTENDS raftVariables, Naturals, Sequences, FiniteSets

\* The set of all quorums. This just calculates simple majorities, but the only
\* important property is that every quorum overlaps with every other.
Quorum == {i \in SUBSET(Server) : Cardinality(i) * 2 > Cardinality(Server)}

\* The term of the last entry in a log, or 0 if the log is empty.
LastTerm(xlog) == IF Len(xlog) = 0 THEN 0 ELSE xlog[Len(xlog)].term


WithMessage(m, msgs) ==
    IF m \in DOMAIN msgs THEN
        [msgs EXCEPT ![m] = msgs[m] + 1]
        \* [msgs EXCEPT ![m] = IF msgs[m] < 2 THEN msgs[m] + 1 ELSE 2 ]
    ELSE
        msgs @@ (m :> 1)

WithoutMessage(m, msgs) ==
    IF m \in DOMAIN msgs THEN
        IF msgs[m] <= 1 THEN [i \in DOMAIN msgs \ {m} |-> msgs[i]]
        ELSE [msgs EXCEPT ![m] = msgs[m] - 1]
    ELSE
        msgs

\* Add a message to the bag of messages.
Send(m) == messages' = WithMessage(m, messages)

\* Remove a message from the bag of messages. Used when a server is done
\* processing a message.
Discard(m) == messages' = WithoutMessage(m, messages)

\* Helper for Send and Reply. Given a message m and bag of messages, return a
\* Combination of Send and Discard
Reply(response, request) ==
    messages' = WithoutMessage(request, WithMessage(response, messages))


ValidMessage(msgs) == { m \in DOMAIN msgs : msgs[m] > 0 }


\* Return the minimum value from a set, or undefined if the set is empty.
Min(s) == CHOOSE x \in s : \A y \in s : x <= y
\* Return the maximum value from a set, or undefined if the set is empty.
Max(s) == CHOOSE x \in s : \A y \in s : x >= y

min(a, b) == IF a < b THEN a ELSE b

\* The prefix of the log of server i that has been committed
Committed(i) ==
    IF commitIndex[i] = 0
    THEN << >>
    ELSE SubSeq(log[i],1,commitIndex[i])


Symmetry == Permutations(Server)



=============================================================================
\* Created by Ovidiu-Cristian Marcu on behalf of the user