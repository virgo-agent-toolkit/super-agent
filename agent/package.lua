return {
  name = "virgo-agent-toolkit/rax",
  version = "0.1.0",
  description = "Remote Agent eXperiment.",
  luvi = {
    version = "2.6.1",
    flavor = "regular",
  },
  homepage = "https://github.com/virgo-agent-toolkit/super-agent",
  dependencies = {
    "creationix/websocket-client",
    "luvit/pretty-print",
    "creationix/msgpack",
    "creationix/schema",
    "creationix/coro-websocket",
    "creationix/coro-fs",
    "luvit/json",
    "luvit/secure-socket",
  }
}
