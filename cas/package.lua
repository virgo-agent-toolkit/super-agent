return {
  name = "virgo-agent-toolkit/cas",
  version = "0.0.0",
  luvi = {
    flavor = "tiny",
  },
  dependencies = {
    "luvit/pretty-print@2.0.0",
    "luvit/json@2.5.2",
    "creationix/msgpack@2.2.1",
    "creationix/redis-client@1.1.0",
    "creationix/weblit-app@2.1.1",
    "creationix/weblit-auto-headers@2.0.2",
    "creationix/weblit-logger@2.0.0",
    "creationix/weblit-etag-cache@2.0.0",
    "creationix/schema@1.0.0",
  },
  files = {
    "*.lua"
  },
}
