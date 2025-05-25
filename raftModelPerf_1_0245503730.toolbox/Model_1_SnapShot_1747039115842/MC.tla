---- MODULE MC ----
EXTENDS raftModelPerf, TLC

\* MV CONSTANT declarations@modelParameterConstants
CONSTANTS
v1, v2
----

\* MV CONSTANT declarations@modelParameterConstants
CONSTANTS
r1, r2, r3
----

\* MV CONSTANT definitions Value
const_174703911118313000 == 
{v1, v2}
----

\* MV CONSTANT definitions Server
const_174703911118314000 == 
{r1, r2, r3}
----

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_174703911118315000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:6MaxBecomeLeader
const_174703911118316000 == 
1
----

=============================================================================
\* Modification History
\* Created Mon May 12 10:38:31 CEST 2025 by jabin
