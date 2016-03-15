  return {
    name = "super-agent",
    private=true,
    version = "0.0.1",
    description = "agent with tty",
    tags = { "lua", "luvit" },
    author = { name = "Adam", email = "harageth@gmail.com" },
    homepage = "https://github.com/virgo-agent-toolkit/super-agent",
    dependencies = {
      "creationix/weblit",
      "creationix/coro-split",
      "luvit/pretty-print",
      "creationix/uv",
      "luvit/resource",
      "luvit/json",
      "creationix/msgpack",
      "luvit/secure-socket",
    },
    files = {
      "**.lua",
      "!test*"
    }
  }
