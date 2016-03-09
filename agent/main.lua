local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
local p = require('pretty-print').prettyPrint
local fs = require('coro-fs')

local agentId = "fc1eb9f7-69f0-4079-9e74-25ffd091022a"
local token = "d8e92bcf-2adf-4bd7-b570-b6548e2f6d5f"

local wsConnect = require('websocket-client')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')
local registry = require('registry')()
local register = registry.register
local String = registry.String
local Function = registry.Function
local Optional = registry.Optional
local Boolean = registry.Boolean

assert(register("scandir", "Reads a directory, calling onEntry for each name/type pair", {
  {"path", String},
  {"onEntry", Function},
}, {Boolean, Optional(String)}, function (path, onEntry)
  local req, err = fs.scandir(path)
  if not req then return {false, err} end
  for entry in req do
    onEntry(entry.name, entry.type)
  end
  return {true}
end))

assert(register("echo", "Echo testing streams", {
  {"echo", Function}
}, Function, function (echo)
  -- This is echo as simple as it gets.
  return echo
end))


-- assert(register("pty", "Create a pty with given shell and dimensions, uses streams", {
--   {"shell", String},
--   {"cols", Int},
--   {"rows", Int},
--   {"onExit", Int},
--   {"onStdout", Int},
--   {"onStderr", Int},
-- }, Int, require('pty')))

local function log(...)
  p("log", ...)
end

coroutine.wrap(function ()
  local url = "ws://localhost:8000/enlist/" .. agentId .. "/" .. token
  local read, write = assert(wsConnect(url , "schema-rpc", {}))
  read, write = codec(read, write, true)
  makeRpc(registry.call, log, read, write).readLoop()
end)()

require('uv').run()
