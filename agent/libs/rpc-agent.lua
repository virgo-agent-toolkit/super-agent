local listen = require 'agent'
local log = require('log').log

listen({
  -- host = "127.0.0.1",
  -- port = 9001,
  proxy = "ws://localhost:9000/enlist/foo",
  api = {
    add = function (a, b) return a + b end,
    echo = function (...) return ... end
  },
}, function (rpc, client)
  log(4, "new client", client)
  rpc.readLoop()
end)
