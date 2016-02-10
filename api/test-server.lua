local p = require('pretty-print').prettyPrint
local request = require('coro-http').request
local msgpackEncode = require('msgpack').encode
local jsonEncode = require('json').stringify
local connect = require('websocket-client')

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
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"User-Agent", userAgent},
    {"Content-Type", "application/json"}
  }, jsonEncode{aep}))
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"User-Agent", userAgent},
    {"Content-Type", "application/msgpack"}
  }, msgpackEncode{aep}))
  local read, write = connect("ws://localhost:8080/websocket", "schema-rpc", {
    {"User-Agent", userAgent}
  })
  write {
    opcode=1,
    payload=jsonEncode{1,"aep.create",aep}
  }
  dump("Result", read())
  write {
    opcode=2,
    payload=msgpackEncode{1,"aep.create",aep}
  }
  dump("result", read())
  write()

end)()
