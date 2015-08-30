# cmem
Cluster membership service

Disclaimer: This service is not yet functional.

This project implements a cluster membership service written in perl.  Moose is used heavily.
The agent is implemented as cmembd.pl.  On startup, cmemd.pl joins the multicast group for reading
and for writing.  It announces its presence to the mulitcast group.  It then enters the standard
operational loop, looking for waiting input from the cluster, sending regular heartbeat messages
to the cluster, and processing requests for third-party clients (membership list queries).  On
shutdown, the agent will leave the multicast group.  All other cluster members should detect
all cluster join/leave events.
