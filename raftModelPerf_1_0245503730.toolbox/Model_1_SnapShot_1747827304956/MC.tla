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
const_174782729189169000 == 
{v1, v2}
----

\* MV CONSTANT definitions Server
const_174782729189170000 == 
{r1, r2, r3, r4}
----

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_174782729189171000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:6MaxBecomeLeader
const_174782729189172000 == 
1
----

\* CONSTANT definitions @modelParameterConstants:13MaxClientRequests
const_174782729189173000 == 
3
----

=============================================================================
\* Modification History
\* Created Wed May 21 13:34:51 CEST 2025 by jabin
