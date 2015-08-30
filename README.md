# cmem
Cluster membership service, v0.1.0-ALPHA

This project implements a cluster membership service written in perl.  Moose is used heavily.
The agent is implemented as cmembd.pl.  On startup, cmemd.pl joins the multicast group for reading
and for writing.  It announces its presence to the mulitcast group.  It then enters the standard
operational loop, looking for waiting input from the cluster, sending regular heartbeat messages
to the cluster, and processing requests for third-party clients (membership list queries).  On
shutdown, the agent will leave the multicast group.  All other cluster members should detect
all cluster join/leave events.

## Protocol ##

All messages are prefaced by a timestamp, followed by a colon and a space.  The timestamp is
in UNIX time (seconds from the epoch) as returned for UTC.

The next message element is the sender.  The sender identification is the prefaced with an open
square bracket, followed by the sender name identifier, followed by a close square bracket.  The
sender identification is followed by a space.  Note that the name identifier in the message is
that used in the cluster join message.

The last element of a CMem protocol message is the message data.  This can be one of several
messages:

- *cjoin &lt;identifier&gt;*: indicates an intent to participate in the cluster, includes the name
identifier used by the joining member
- *alive &lt;identifier&gt; &lt;time&gt;*: indicates that the sending member is alive and participating in the
cluster; the time parameter is seconds from UTC epoch
- *leave &lt;identifier&gt;*: indicates that the member is leaving the cluster
- *cluster &lt;cluster_membership_list&gt;*: when a new cluster member joins, existing cluster members
reply with their current cluster membership list (this allows the joining member to know who is
participating in the cluster, even though the joiner wasn't present for the previous join
messages); note that disagreements in cluster membership need to be rectified, but this is
done in the implementation of the cluster, not in the cluster protocol

## Notes ##

* Needs logging methodology

* Needs cluster auth

* Needs to handle signals

* Enable daemonization
