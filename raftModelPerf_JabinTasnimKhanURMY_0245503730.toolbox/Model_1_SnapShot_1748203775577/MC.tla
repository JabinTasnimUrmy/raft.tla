---- MODULE MC ----
EXTENDS raftModelPerf_JabinTasnimKhanURMY_0245503730, TLC

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_1748203768850162000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:11Value
const_1748203768850163000 == 
{"v1","v2"}
----

\* CONSTANT definitions @modelParameterConstants:12Server
const_1748203768850164000 == 
{"r1","r2","r3","r4","r5"}
----

\* CONSTANT definitions @modelParameterConstants:14MaxClientRequests
const_1748203768850165000 == 
2
----

\* INVARIANT definition @modelCorrectnessInvariants:2
inv_1748203768850168000 ==
 LeaderCompletenessInv
----
\* INVARIANT definition @modelCorrectnessInvariants:6
inv_1748203768850172000 ==
 LeaderCountInv
----
=============================================================================
\* Modification History
\* Created Sun May 25 22:09:28 CEST 2025 by jabin
