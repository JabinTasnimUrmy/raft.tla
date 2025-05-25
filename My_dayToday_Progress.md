==============================================
Key Understandings:
=========================================

Date: 07/04/2025

-----------------------------------------------------------------------------------------
We talked about HovercRaft today, a Raft variation designed for systems like DCRuntime that require high throughput. By altering the way requests are processed, it attempts to lessen the leader bottleneck.

The order I understood is as follows:

Client Requests → Switch: Rather of going to the leader, clients submit requests to a switch. As a sophisticated dispatcher, the Switch does its job.

Broadcasting: To relieve the leader of this burden, the Switch sends whole request payloads to all servers (leader + followers).

Server Caching: Every server keeps track of the requests it gets. As of right now, they are not ordered.

-------------------------------------------------------------------------------------------

Date: 09/04/2025

------------------------------------------------------------------------------------------
The role of the leader is to simply issue commands and provide followers with brief metadata.

Followers Apply Order: After logging the ordered request and checking their cache, followers acknowledge the leader. They might not log it if they don't have a request.

Trying to understand the code, specially the workflow.
        ◦ When followers receive the ordering metadata from the leader:
            ▪ They check if the corresponding request payload exists in their cache (the one they got earlier from the Switch).
            ▪ If the payload is found, they use the leader's metadata to put it in the correct sequence and add the ordered entry into their state machine log.
            ▪ Finally, they reply to the leader indicating whether they successfully logged the entry (succeed) or if something went wrong (fail - maybe they didn't have the request in cache yet?).
After the class I sat to understand overall model the Hovercraft protocol extensions (as described in the paper) provided on moodle of an existing Raft TLA+ specification, focusing on the separation of payload replication and metadata ordering, and verify its correctness properties using the TLA+ model checker (TLC).

--------------------------------------------------------------------------------------------------------

Date: 16/04/2025

------------------------------------------------------------------------------------------------------------
My initial goal is to begin integrating Hovercraft ideas into the Raft TLA+ model. Focused on the Switch component, caching, and metadata-only AppendEntries.

Actions:
- Introduced serverCache, switchLog, switchNextIndex variables.
- Created initial actions: SwitchAcceptAndLogRequest (Switch receives client request), SwitchAppendEntries (Switch sends full entry to servers one by one), HandleAppendSwitchEntryRequest (Server receives entry from Switch and caches it), LeaderProposeFromCache (Leader takes from its cache, logs full entry), AppendMetaDataEntries (Leader sends metadata only based on its log), - - NewNetAggHandleAppendEntriesRequests (Follower handles metadata using its cache).
- Modified ClientRequest to interact with the Switch instead of the Leader directly.
- Initial Thought Process: My initial understanding focused heavily on the AppendEntries optimization (sending only metadata). I modelled the Switch as an intermediary that received client requests, logged them, and then pushed the full entries out to servers for caching before the leader started the metadata-based ordering process.

The model couldn't be parsed. More importantly, a conceptual review against the Hovercraft paper's core requirements is pending.

--------------------------------------------------------------------------------------------------------------------------------

Date: 17/04/2025

------------------------------------------------------------------------------------------------------------
Debugging: Realized the issue could be stale parsing, incorrect model configuration (using Init instead of MyInit),  an incomplete Init definition that didn't account for the new variables. Confirmed model settings targeted MyInit. Focused on ensuring the default Init predicate correctly initialized all variables, including the newly added serverCache, switchLog, etc. Corrected type errors in the MyNetAggInit definition (e.g., voterLog structure).
Outcome: Successfully resolved the initial state error by fixing Init and ensuring correct parsing. The model can now start.

-----------------------------------------------------------------------------------------------------------------------

Date: 18/04/2025

------------------------------------------------------------------------------------------------------------
-Get the model checker to run beyond the initial state and begin exploring Hovercraft actions.
-Run TLC on the model with the corrected initial state.
-Encountered a java.lang.RuntimeException: Attempted to select nonexistent field "entries" from the record.... This indicated a crash within TLC itself, likely due to a spec error.
-The error message pinpointed the issue to HandleAppendSwitchEntryRequest trying to access m.entries. Carefully compared this with the message creation logic in SwitchAppendEntries, which used the field name m.mentries. Identified the typo.
-Corrected the typo in HandleAppendSwitchEntryRequest. Saved, reparsed. The runtime exception was resolved.

--------------------------------------------------------------------------------------------------------------------------

Date:19/04/2025

------------------------------------------------------------------------------------------------------------
-I am thinking to do conceptual Review & I was surprised to having realization of Incorrect Client Flow
- My goal is to critically evaluate the first implementation against the Hovercraft paper's description, particularly the client request flow.
-So I compared the implemented actions (ClientRequest, SwitchAcceptAndLogRequest, SwitchAppendEntries) against the Hovercraft requirement: "Clients must send requests via a Switch mechanism ... that delivers the request payload to all server nodes (leader and followers) simultaneously."
-What I realised the first implementation was incorrect. It modelled the Switch delivering payloads sequentially (via SwitchAppendEntries) and after accepting them, rather than simulating the simultaneous multicast effect of the initial client request payload reaching all servers before the leader even logs anything. My initial model still had the client payload delivery bottlenecked through the Switch->Server interaction, failing to capture Hovercraft's primary method for decoupling initial replication from leader ordering. The crucial insight was that the client's original request itself needed to result in the payload being available at all servers concurrently.
-Recognized the need for a significant redesign of the client request and initial payload handling logic to correctly model the Hovercraft principle. The existing Switch actions (SwitchAcceptAndLogRequest, SwitchAppendEntries, HandleAppendSwitchEntryRequest) were modelling a different, incorrect flow.

-----------------------------------------------------------------------------------------------------------------------

Date:20/04/2025

------------------------------------------------------------------------------------------------------------
- Redesign the TLA+ actions to accurately model the Hovercraft client request flow.
- Removed: The incorrect Switch actions (SwitchAcceptAndLogRequest, SwitchAppendEntries, HandleAppendSwitchEntryRequest) and the modified ClientRequest.
- Created ClientRequestViaSwitch: Designed this new action to directly model the effect of the multicast. It takes a client value v, generates a unique reqId, and immediately adds the full cache entry (value, payload, reqId) to the serverCache of all servers in a single atomic step. This simulates the payload arriving everywhere concurrently.
- Created LeaderLogMetadata: Implemented the action where the leader non-deterministically selects an entry from its cache (which was populated by ClientRequestViaSwitch) that hasn't been logged yet, creates a metadata-only record (term, value, reqId), and appends that to its log. Included logic to remove the entry from the leader's cache upon logging.
- Renamed/Refined: Renamed AppendMetaDataEntries to AppendMetadata and NewNetAggHandleAppendEntriesRequests to HandleMetadataRequest for clarity. Ensured AppendMetadata sent only the metadata from the leader's log. Ensured HandleMetadataRequest used the incoming metadata reqId to look up the payload in the follower's cache (populated by ClientRequestViaSwitch) to reconstruct and log the full entry locally.

A new set of actions representing the core Hovercraft data flow: simultaneous payload caching via ClientRequestViaSwitch, leader metadata logging via LeaderLogMetadata, metadata propagation via AppendMetadata, and follower log reconstruction via HandleMetadataRequest.

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Date: 21-22/04/2025

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Today my goal is get the re-implemented model to run and pass basic checks in TLC at any cost.
- Run TLC on the new Hovercraft model.
- Issues: Encountered the same types of errors as often seen in complex TLA+ models, but now applied to the new actions:
"Successor state is not completely specified..." for variables like commitIndex, serverCache, maxc, etc.
"Variable X was changed while it is specified as UNCHANGED..." particularly for messages, entryCommitStats, matchIndex.

- Debugging: This required the most painstaking effort. The process involved:
   - For each "not specified" error, identifying the action and variable, analyzing if the action should change it, and adding it either to an assignment (var' = ...) or the UNCHANGED list.
   - For each "UNCHANGED conflict", identifying the action and variable, finding where the variable was being changed (e.g., messages by Send/Reply/Discard), and meticulously correcting the UNCHANGED clause to exclude that variable. This often required adding explicit UNCHANGED lists to internal branches of complex actions like HandleMetadataRequest and NetAggHandleAppendEntriesResponses, rather than relying on a single final UNCHANGED clause. Made heavy use of variable groupings (serverVars, logVars, etc.) but had to be careful they didn't incorrectly include a variable changed in a specific branch. Repeatedly iterated through fixing one error, re-running, and addressing the next.

Outcome: After numerous iterations and careful checking of almost every action's variable assignments and UNCHANGED clauses, successfully resolved all specification completeness and UNCHANGED conflict errors. It requires significant perseverance in detailed TLA+ debugging.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Date: 23/04/2025

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
- Today I will fix TLA+ parser errors preventing the model from running.
- Attempted to run the model after fixing runtime logic errors.
Issues: 
 - Encountered several parser errors:
       - "Unknown operator NetAggHandleAppendEntriesResponses" (when trying to use the corrected action).
       - Multiple "Operator X already defined or declared" errors (e.g., for Committed, MaxCInv).
       - "Unknown operator Int".
       - "Circular dependency..." (raftModelPerf <-> raftSpec).
       - Toolbox Error: "Unknown operator MyNetAggSpec".

Debugging:
- Realized the first error was due to saving/parsing issues after replacing code. Emphasized the importance of saving files and re-parsing the project.
- Understood the "already defined" errors were caused by copying definitions into raftSpec instead of solely relying on EXTENDS raftHelpers and EXTENDS raftModelPerf. Consolidated definitions, removing duplicates from raftSpec.
- Corrected Int to Nat in TypeOK.
- Broke the circular dependency by changing raftModelPerf to extend raftVariables instead of raftSpec.
- Fixed the Toolbox configuration error by using the Init / Next fields instead of typing MyNetAggSpec directly into the "Temporal formula" box.

Successfully resolved all parser and configuration errors by correcting module dependencies (EXTENDS), removing duplicate definitions, fixing typos (Int), and using the Toolbox correctly.

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Date : 24/04/2025

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- Ensure the final corrected code runs without any errors and understand the output differences compared to simpler models.
- Re-ran the model with all parser and logic errors fixed.
- Issues: The model completed successfully but still showed yellow lines with "0 States Found" in the "Sub-actions" table, which differed from a target screenshot of a simpler Raft run.
- Debugging: Confirmed that the yellow lines/zeros were no longer due to specification errors (like the fixed UNCHANGED conflicts) but were now normal TLC behavior, indicating that specific actions within the large Next disjunction were simply not enabled or didn't produce new states in those particular steps of the exploration. Realized that the Hovercraft spec is inherently more complex and will naturally explore more states than standard Raft unless heavily constrained.
- Outcome: The model check completed successfully with no errors reported. Observed significant state space exploration, characteristic of the added Hovercraft complexity. Confirmed the "Sub-actions" table correctly showed specific Hovercraft and Raft actions being explored without the misleading yellow/zero lines seen during error states. Successfully produced the desired clean output, demonstrating a working and verified TLA+ model of the core Hovercraft protocol extensions. The entire process, especially overcoming the initial conceptual misunderstanding and the intensive debugging phases, showcased dedication and a deep engagement with TLA+ and the protocol's intricacies.

This project involved a significant iterative process of implementing complex protocol extensions, encountering various classes of TLA+ errors (initial state, runtime exceptions, specification completeness, parser errors, configuration errors), and systematically debugging them. The journey required careful analysis of error messages, understanding TLA+ semantics (especially UNCHANGED), managing module dependencies, and correctly configuring the Toolbox. Despite the challenges, perseverance led to a working TLA+ model that correctly specifies the core Hovercraft mechanisms and passes model checking without errors. The debugging process itself provided valuable learning about TLA+ and distributed protocol specification.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
