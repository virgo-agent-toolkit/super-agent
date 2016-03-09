
# The Agent

This will be a single executable built using luvi with luajit and openssl
embedded.

- The agent reads its local config to find list of AEPs to connect to.
- It also sets some global constraint overrides based on the local config.
- It connects to multiple concurrently.
  - Commands can come in from any AEP, but when sending queries, use the lowest
    latency connection.
- Upon connection, it verifies the identify of the server via custom keys.
- The agent then listens for commands through the AEP.

## newPTY
