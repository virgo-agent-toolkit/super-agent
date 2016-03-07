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
local Int = registry.Int
local Array = registry.Array
local String = registry.String
local Optional = registry.Optional
local Callback = registry.Callback
local Stream = registry.Stream

assert(register("add", "Adds two integers", {{"a",Int}, {"b",Int}}, Int, function (a, b)
  return a + b
end))

assert(register("readdir", "Reads a directory", {{"path",String}}, Optional(Array(String)), function (path)
  local names = {}
  local req, err = fs.scandir(path)
  if not req then
    if not err or err:match("^ENOENT:") then return end
    error(err)
  end

  local i = 0
  for entry in req do
    i = i + 1
    names[i] = entry.name
  end
  return names
end))

local remote
assert(register("echo", "Echo testing streams", {
  {"write", Int}
}, Int, function (wid)
  local rid = remote.register()
  local function read()
    return remote.wait(rid)
  end
  local function write(...)
    return remote.send(wid, ...)
  end
  coroutine.wrap(function ()
    for message in read do
      write(message)
    end
    write()
  end)()
  return rid
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
  remote = makeRpc(registry.call, log, read, write)
  remote.readLoop()
end)()

require('uv').run()
