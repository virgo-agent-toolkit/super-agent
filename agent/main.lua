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
local Int = registry.Int
local Bool = registry.Bool

assert(register("scandir", "Reads a directory, calling onEntry for each name/type pair", {
  {"path", String},
  {"onEntry", Function},
}, {
  {"exists", Bool},
}, function (path, onEntry)
  local iter, err = fs.scandir(path)
  if not iter then
    if err:match("^ENOENT:") then return false end
    error(err)
  end
  for entry in iter do
    onEntry(entry.name, entry.type)
  end
  return true
end))

assert(register("echo", "Echo testing streams", {
  {"data", Function}
}, {
  {"data", Function}
}, function (echo)
  -- This is echo as simple as it gets.
  return echo
end))

-- diskusage(
--   path: String,
--   depth: Integer,
--   onEntry: Callback(path: String, size: Integer)
--   onError: Callback(path: String, error: String)
-- ) -> error: Optional(String)
assert(register("diskusage", "Calculate diskusage of folders and subfolders", {
  {"path", String},
  {"depth", Int},
  {"onEntry", Function},
  {"onError", Function}
}, {
  {"exists", Bool},
}, function (rootPath, maxDepth, onEntry, onError)
  local function scan(path, depth)
    local stat, err = fs.lstat(path)
    if not stat then
      if err then
        onError(path, err)
      end
      return 0
    end
    local total = stat.size
    if stat.type == "directory" then
      local iter, err2 = fs.scandir(path)
      if not iter then
        if err2 then
          onError(path, err2)
        end
        return total
      end
      for entry in iter do
        local subpath = (path == "/" and "" or path) .. "/" .. entry.name
        local subtotal, err3 = scan(subpath, depth - 1)
        if subtotal then
          total = total + subtotal
        elseif err3 then
          onError(subpath, err3)
        end
      end
    end
    if depth >= 0 then
      onEntry(path, total)
    end
    return total
  end
  local stat, err = fs.stat(rootPath)
  if not stat then
    if not err or err:match("^ENOENT:") then
      return false
    end
    error(err)
  end
  scan(rootPath, maxDepth)
  return true
end))


-- pty(
--   shell: String,
--   uid: Integer,
--   gid: Integer,
--   cols: Integer,
--   rows: Integer,
--   onTitle: Function(title: String),
--   onOut: Function(chunk: Buffer),
--   onExit: Function()
-- ) -> error: Optional(String),
--      write: Function(chunk: Buffer),
--      close: Function(error: Optional(String)),
--      resize: Function(cols: Integer, rows: Integer)


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
