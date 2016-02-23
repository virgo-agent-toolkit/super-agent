# Super Agent

The Super Agent project is an ambitious project that makes is simple and secure
to monitor, diagnose, and repair various remote machines.  The core system is
composed of three main components.

For more details than this generic overview, See the individual READMEs in each
subfolder.

## The Agent

The agent itself is a tiny executable with Lua embedded that runs inside the
target machines.  It connects outward via the public internet to the AEPs and
performs various actions reporting the result.  This is roughly equivalent
to an SSH server, except the way you connect to it doesn't require opening
ports to the public internet on your target machine.

## The Agent End Point (AEP)

This is mostly a simply proxy that listens on a public port and accepts
connections from agents as well as clients to the super-agent system.  It acts
as a multiplexing proxy and allows agents and clients (both of whom may be
behind private networks) to communicate with each-other with as little latency as
possible.

## The API Server

This server is the main public entry into the system.  It exposes various APIs
for controlling and configuring the agents.  This server is responsible for
talking to the persistent data structures (currently stored in PostgreSQL).  It
also is used as a gateway to discover the AEP being used for a particular agent.
