return {
  name = "super-agent/api-server",
  private = true,
  version = "0.0.1",
  luvi = {
    version = "2.6.1",
    flavor = "tiny",
  },
  files = {
    "main.lua",
    "server.lua",
    "package.lua",
    "libs/**.lua",
    "crud/**.lua",
  },
  dependencies = {
    "creationix/weblit-app",
    "creationix/weblit-websocket",
    "creationix/weblit-logger",
    "creationix/weblit-auto-headers",
    "creationix/schema",
    "creationix/coro-postgres",
    "creationix/coro-http",
    "creationix/msgpack",
    "luvit/json",
    "luvit/pretty-print",
    "creationix/uv",
    "creationix/uuid4",
  }
}
