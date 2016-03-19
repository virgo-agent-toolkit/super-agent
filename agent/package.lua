return {
  name = "super-agent/rax",
  version = "0.0.1",
  description = "A super agent. Daemon and CLI tool.",
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
    "creationix/coro-fs",
    "luvit/json",
    "luvit/secure-socket",
  }
}
