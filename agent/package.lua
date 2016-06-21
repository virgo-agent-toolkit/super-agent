return {
  name = "virgo-agent-toolkit/fife",
  version = "0.4.3",
  description = "Deputy Fife does exactly what you tell him.",
  luvi = {
    version = "2.7.3",
    flavor = "regular",
  },
  homepage = "https://github.com/virgo-agent-toolkit/super-agent",
  files = {
    "**.lua",
    "platform.api",
  },
  dependencies = {
    "creationix/websocket-client",
    "creationix/weblit-app",
    "creationix/weblit-auto-headers",
    "creationix/weblit-logger",
    "creationix/weblit-etag-cache",
    "creationix/weblit-static",
    "creationix/weblit-websocket",
    "luvit/pretty-print",
    "creationix/msgpack",
    "creationix/schema",
    "creationix/coro-websocket",
    "creationix/coro-fs",
    "luvit/json",
    "luvit/secure-socket",
  }
}
