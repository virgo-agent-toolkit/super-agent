local p = require('pretty-print').prettyPrint
local request = require('coro-http').request

local connect = require('websocket-client')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')

local function dump(...)
  local args = {...}
  for i = 1, select("#", ...) do
    p(args[i])
  end
end
local userAgent = "test-server.lua"

coroutine.wrap(function ()
  local aep = {
    hostname = "localhost"
  }
  -- dump(request("POST", "http://localhost:8080/api/aep.create", {
  --   {"User-Agent", userAgent},
  --   {"Content-Type", "application/json"}
  -- }, jsonEncode{aep}))
  -- dump(request("POST", "http://localhost:8080/api/aep.create", {
  --   {"User-Agent", userAgent},
  --   {"Content-Type", "application/msgpack"}
  -- }, msgpackEncode{aep}))
  local read, write = connect("ws://localhost:8080/websocket", "schema-rpc", {
    {"User-Agent", userAgent}
  })

  local severityTable = {
    "Fatal",
    "Error",
    "Warning",
    "Notice",
    "Debug"
  }


  local api = makeRpc(p, function (severity, ...)
    print(severityTable[severity], ...)
  end, codec(read, write))

  coroutine.wrap(api.readLoop)()

  local AEP = api.aep

  local id = assert(AEP.create { hostname = "test.host" })

  assert(AEP.read(id))

  assert(AEP.update { id = id, hostname = "updated.host" })

  assert(AEP.read(id))

  AEP.query({})

  AEP.query({hostname="localhost"})

  AEP.query({hostname="local*"})

  assert(AEP.delete(id))

  assert(not AEP.read(id))

  AEP.delete("6050BE6B-A8BC-4BF8-A55C-11D616679CBC")

  AEP.update { id = "6050BE6B-A8BC-4BF8-A55C-11D616679CBC", hostname = "updated.host" }

  write()

end)()
