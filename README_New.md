
In order to overcome leader bottlenecks and increase scalability for datacenter workloads, this project offers a TLA+ specification for the Raft consensus algorithm that is expanded with essential ideas from the Hovercraft protocol. It simulates the fundamental Hovercraft tactic of isolating leader-driven metadata ordering from initial payload replication.

Key Concepts Modeled Simulated Multicast Request: Client requests simulate the impact of a multicast switch/middlebox by causing the request payload to become simultaneously available in all server caches (ClientRequestViaSwitch).

Metadata Logging: The leader records only the metadata (term, value identifier, and request ID) into its Raft log (LeaderLogMetadata) after choosing requests from its cache.

Metadata AppendEntries: Using AppendEntries messages, the leader sends followers only this metadata (AppendMetadata).

Follower Cache Lookup & Log Reconstruction: After receiving metadata, followers search their local cache (which was filled by the first simulated multicast) for the matching full payload. They then reconstruct or append the entire entry to their local Raft log (HandleMetadataRequest).

The metadata log's standard Raft leader election and commit logic has been modified.

Modules Description
- raftConstants.tla: System constants.
- raftVariables.tla: State variable declarations.
- raftHelpers.tla: Helper operators (message handling, math, log helpers like Committed, CheckIsPrefix).
- raftInit.tla: Initial state predicates (Init, MyInit).
- raftActionsSolution.tla: (Main Logic) State transition actions (Hovercraft-specific and standard Raft, with corrected UNCHANGED clauses).
- raftModelPerf.tla: Performance/instrumentation invariants (e.g., MaxCInv, EntryCommitAckQuorumInv). EntryCommitMessageCountInv is commented out.
- raftSpec.tla: (Top-Level) Integrates modules, defines Spec/MyNetAggSpec, core safety invariants (TypeOK, LogInv, etc.), combines invariants for checking.

A screenshot of the model overview has already been provided.

Remarks and Restrictions
The primary Hovercraft metadata/payload separation is the main focus.
The optional follower recovery mechanism for missed multicast messages is not implemented.
- Large state spaces are possible; model checking necessitates low constant bounds, particularly MaxClientRequests. 
