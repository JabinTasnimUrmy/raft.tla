
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

--------------------------------------------------------------------------------------------------------