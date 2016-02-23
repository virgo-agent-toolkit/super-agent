# Agent Endpoint

The AEP is deployed as a plain luajit process using the lit libraries.

- listens to connections from agents
  - reports agent connections to the API server (and possibly logging system)
- listens for connections from end clients
  - verifies client authorization and proxies to agent
  - reports all proxied data to logging system
- We need to support having multiple instances running behind a load balancer
  sharing the same public IP and port.

## wss://hostname/agent/:agent_id

This is the main endpoints. It's used to request a proxy connection to an agent.

Internally the AEP will have a single connection to the agent and will multiplex
various external connections by translating request and response ids in the
schema-rpc protocol.
