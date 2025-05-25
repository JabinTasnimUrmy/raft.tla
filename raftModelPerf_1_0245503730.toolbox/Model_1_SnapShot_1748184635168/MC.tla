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
const_17481846228152000 == 
{v1, v2}
----

\* MV CONSTANT definitions Server
const_17481846228153000 == 
{r1, r2, r3, r4}
----

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_17481846228154000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:6MaxBecomeLeader
const_17481846228155000 == 
1
----

\* CONSTANT definitions @modelParameterConstants:13MaxClientRequests
const_17481846228156000 == 
3
----

=============================================================================
\* Modification History
\* Created Sun May 25 16:50:22 CEST 2025 by jabin
