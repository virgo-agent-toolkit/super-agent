local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
local p = require('pretty-print').prettyPrint

local agentId = "fc1eb9f7-69f0-4079-9e74-25ffd091022a"
local token = "d8e92bcf-2adf-4bd7-b570-b6548e2f6d5f"

local wsConnect = require('websocket-client')

coroutine.wrap(function ()
  local url = "ws://localhost:8000/enlist/" .. agentId .. "/" .. token
  local read, write, socket = wsConnect(url , "schema-rpc", {})
  p(read, write, socket)
  for message in read do
    p(message)
    write {
      opcode = 1,
      payload = "Agent saw your message " .. #message.payload
    }
  end
  write()
end)()

require('uv').run()
