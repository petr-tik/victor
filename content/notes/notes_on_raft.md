+++
title = "Notes on raft"
author = ["Petr Tikilyaynen"]
date = 2019-11-09T22:43:00+00:00
lastmod = 2019-11-09T22:53:01+00:00
categories = ["notes"]
draft = false
description = "cRafting consensus"
+++

Below are my notes from watching Martin Thompson's [talk on Cluster consensus in Aeron](https://www.youtube.com/watch?v=GFfLCGW%5F5-w).


## Raft - a consensus algorithm {#raft-a-consensus-algorithm}


### Most fitting definition of consensus {#most-fitting-definition-of-consensus}

> the judgement agreed on by the majority

Consensus can apply to a single value or shared state made of different primitives.


### Prior work - Paxos {#prior-work-paxos}

Consensus algorithms were an active research topic in the 1970s and 1980s and
Paxos was one of the early ones.

However, the implementation complexity has let Paxos down and made it hard to use.


### What problem is Raft solving {#what-problem-is-raft-solving}

Raft is a consensus algorithm that optimises for human understanding and ease of
implementation.


## In a nutshell {#in-a-nutshell}

Raft makes the implementation easy to follow by minimising the state space as much as possible and sticking to a few key principles.


#### Principles {#principles}

-   Monotonically increasing time divided into terms: every term starts
    with an election. Elections can either results in a new leader for this
    term or undecided, in which case a new term starts with another election.
-   Randomisation settles conflicts.
    Followers have a random timeout. If they don't receive an AppendEntries RPC
    from their leader after this time out, they assume that the king/leader
    is dead (long live the leader), they randomly decide to throw in the ring and become candidates for
    this election.


#### Roles {#roles}

There are only 3 roles and transitions between them can be represented by this finite state machine.

<pre>
               +--------------------------+
               |                          |
               v                          |
       +---------------+          +-------|----------+         +------------------+
       |               |          |                  |         |                  |
       |   follower    |          |    candidate     |         |      leader      |
 +---->|               +--------->|                  +-------->|                  |
       |               |          |                  |         |                  |
       +---------------+          +---------------|--+         +---------|--------+
               ^                         ^        |                      |
               |                         |        |                      |
               |                         +--------+                      |
               |                                                         |
               +---------------------------------------------------------+
</pre>

-    Follower

    Every node starts as a follower. Followers are passive and issue no requests,
    they can only serve the requests of others: candidates or the current leader.

-    Candidate

    A node that wants to become leader in this term/election cycle. Sends the
    RequestVote RPC to followers with its current state.

-    Leader

    The only node that can send AppendEntries requests to other nodes. Is in
    charge of dealing with requests from the client and passing them to
    followers.


#### RPC {#rpc}

-    RequestVote

    Candidates get on the campaign trail by asking followers to back them.
    Instead of hosting debates, this election is settled by checking if the
    candidate "knows more" i.e. is further ahead in its state than the
    follower that receives the request.

    When a follower receives a RequestVote it compares its state with that of
    the candidate and sends a positive vote if the candidate is further ahead
    in its state.

    This ensures that no candidate that is behind in terms is elected to be leader.

    > This is one of the crucial differences between Paxos and Raft. Paxos allows
    electing a leader that is behind in its state. After electing such a leader,
    they need to catch up/replay the state from their followers. This removes the
    monotonic principle and increases implementation complexity by needing more RPC
    types.

-    AppendEntries

    After successfully winning an election, the leader uses the same RPC to
    replicate his state and heartbeat with all other nodes.

    If there are no entries to append, this RPC serves as a heartbeat. In
    case, there are new entries, the leader sends it out to all its followers.


## Applications {#applications}

-   Using Raft enables aeron to focus on "Guaranteed Processing" of messages
    instead of "Guaranteed Delivery". If processing is idempotent, delivering
    the same message twice doesn't change system state.
-   Dynamically changing the state of the system - adding new nodes or hot
    upgrades to currently running nodes.
-   State machine replication for event-sourced systems. Once the leader
    sequences messages from the outside world and its followers commit them to
    their logs, we can do a Gaddafi without losing system state.


## Cool visualition with more detail {#cool-visualition-with-more-detail}

<http://thesecretlivesofdata.com/raft/>
