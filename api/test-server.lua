local p = require('pretty-print').prettyPrint
local request = require('coro-http').request
local msgpackEncode = require('msgpack').encode
local jsonEncode = require('json').stringify


local function dump(...)
  local args = {...}
  for i = 1, select("#", ...) do
    p(args[i])
  end
end

coroutine.wrap(function ()
  local aep = {
    hostname = "localhost"
  }
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"Content-Type", "application/json"}
  }, jsonEncode{aep}))
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"Content-Type", "application/msgpack"}
  }, msgpackEncode{aep}))
end)()
