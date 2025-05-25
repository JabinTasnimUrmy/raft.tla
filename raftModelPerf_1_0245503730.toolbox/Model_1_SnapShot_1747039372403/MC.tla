---- MODULE MC ----
EXTENDS raftModelPerf, TLC

\* MV CONSTANT declarations@modelParameterConstants
CONSTANTS
v1, v2
----

\* MV CONSTANT declarations@modelParameterConstants
CONSTANTS
r1, r2, r3, r4
----

\* MV CONSTANT definitions Value
const_174782610941750000 == 
{v1, v2}
----

\* MV CONSTANT definitions Server
const_174782610941751000 == 
{r1, r2, r3, r4}
----

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_174782610941752000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:6MaxBecomeLeader
const_174782610941753000 == 
1
----

\* CONSTANT definitions @modelParameterConstants:13MaxClientRequests
const_174782610941754000 == 
3
----

=============================================================================
\* Modification History
\* Created Wed May 21 13:15:09 CEST 2025 by jabin
