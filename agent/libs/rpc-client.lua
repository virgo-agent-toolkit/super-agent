local connect = require 'client'

coroutine.wrap(function ()
  local rpc = connect {
    url = 'ws://localhost:9000/agent/foo',
    proxy = true,
    -- url = 'ws://localhost:9001/',
  }
  coroutine.wrap(rpc.readLoop)()
  rpc.call("add", 1, 2)
  local e = rpc.call("echo", function (...)
    return ...
  end)
  e(42)
  rpc.close()
end)()
