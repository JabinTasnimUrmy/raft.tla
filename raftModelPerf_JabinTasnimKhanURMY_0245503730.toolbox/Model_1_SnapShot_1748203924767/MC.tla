---- MODULE MC ----
EXTENDS raftModelPerf_JabinTasnimKhanURMY_0245503730, TLC

\* CONSTANT definitions @modelParameterConstants:3MaxTerm
const_1748203916579184000 == 
2
----

\* CONSTANT definitions @modelParameterConstants:11Value
const_1748203916579185000 == 
{"v1","v2"}
----

\* CONSTANT definitions @modelParameterConstants:12Server
const_1748203916579186000 == 
{"r1","r2","r3","r4","r5"}
----

\* CONSTANT definitions @modelParameterConstants:14MaxClientRequests
const_1748203916579187000 == 
2
----

\* INVARIANT definition @modelCorrectnessInvariants:2
inv_1748203916579190000 ==
 LeaderCompletenessInv
----
=============================================================================
\* Modification History
\* Created Sun May 25 22:11:56 CEST 2025 by jabin
