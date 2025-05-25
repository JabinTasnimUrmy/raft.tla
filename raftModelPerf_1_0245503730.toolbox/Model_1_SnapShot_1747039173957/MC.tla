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
const_174703916808023000 == 
{v1, v2}
----

\* MV CONSTANT definitions Server
const_174703916808024000 == 
{r1, r2, r3, r4}
----

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_174703916808125000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:6MaxBecomeLeader
const_174703916808126000 == 
1
----

=============================================================================
\* Modification History
\* Created Mon May 12 10:39:28 CEST 2025 by jabin
