local platform = require('platform')
local agentId = "fc1eb9f7-69f0-4079-9e74-25ffd091022a"
local token = "d8e92bcf-2adf-4bd7-b570-b6548e2f6d5f"
local p = require('pretty-print').prettyPrint

local msgpackDecode = require('msgpack').decode
local wsConnect = require('websocket-client')
local loadResource = require('resource').load
local makeRpc = require('rpc')
local codec = require('websocket-to-message')
local createServer = require('coro-net').createServer
local registry = require('registry')()
local register = registry.register
local alias = registry.alias
local String = registry.String
local Function = registry.Function
local Optional = registry.Optional
local Int = registry.Int
local Number = registry.Number
local Array = registry.Array
local NamedTuple = registry.NamedTuple
local Bool = registry.Bool
local Any = registry.Any

assert(register("scandir", "Reads a directory, calling onEntry for each name/type pair", {
  {"path", String},
  {"onEntry", Function},
}, {
  {"exists", Bool},
}, platform.scandir))

assert(register("echo", "Echo testing streams", {
  {"data", Any}
}, {
  {"data", Any}
}, platform.echo))

assert(register("readstream", "Read a file in 1024 byte chunks", {
  {"path", String},
  {"data", Function},
}, {
  {"exists", Bool},
}, platform.readstream))

assert(register("readfile", "Read a file, but buffer all the chunks", {
  {"path", String},
}, {
  {"data", Optional(String)},
}, platform.readfile))

assert(register("readlink", "Read the target of a symlink", {
  {"path", String},
}, {
  {"target", Optional(String)},
}, platform.readlink))

assert(register("writestream", "Write a file in chunks, pass nill to end", {
  {"path", String},
  {"error", Function},
}, {
  {"data", Function},
}, platform.writestream))

assert(register("writefile", "Write a file from a buffer", {
  {"path", String},
  {"data", String},
}, {
  {"created", Bool}
}, platform.writefile))

assert(register("symlink", "Create a symlink", {
  {"target", String},
  {"path", String},
}, {}, platform.symlink))

assert(register("mkdir", "Create a directory, optionally creating parents", {
  {"path", String},
  {"recursive", Bool},
}, {
  {"created", Bool},
}, platform.mkdir))

assert(register("unlink", "Remove a file", {
  {"path", String},
}, {
  {"existed", Bool},
}, platform.unlink))

assert(register("rmdir", "Remove an empty directory", {
  {"path", String},
}, {
  {"existed", Bool},
}, platform.rmdir))

assert(register("rm", "Remove a file or directory (optionally recursivly)", {
  {"path", String},
  {"recursive", Bool},
}, {
  {"existed", Bool},
}, platform.rm))

assert(register("lstat", "Get stats for a file or directory", {
  {"path", String},
}, {
  {"stat", Optional(NamedTuple{
    {"mtime", Number},
    {"atime", Number},
    {"size", Int},
    {"type", String},
    {"mode", Int},
    {"uid", Int},
    {"gid", Int},
  })}
}, platform.lstat))

assert(register("chmod", "Change the mode/permissions of a file", {
  {"path", String},
  {"mode", Int},
}, {}, platform.chmod))

assert(register("chown", "Change the user id and group id of a file", {
  {"path", String},
  {"uid", Int},
  {"gid", Int},
}, {}, platform.chown))

assert(register("utime", "Update access and modification times for a file", {
  {"path", String},
  {"atime", Number},
  {"mtime", Number},
}, {}, platform.utime))

assert(register("rename", "Rename or move a file", {
  {"path", String},
  {"newPath", String},
}, {}, platform.rename))

assert(register("realpath", "Gets the realpath by resolving symlinks", {
  {"path", String},
}, {
  {"fullPath", String}
}, platform.realpath))

assert(register("diskusage", "Calculate diskusage of folders and subfolders", {
  {"path", String},
  {"depth", Int},
  {"onEntry", Function},
  {"onError", Function}
}, {
  {"exists", Bool},
}, platform.diskusage))

if platform.user then
  assert(register("user", "Get username from user id", {
    {"uid", Int},
  }, {
    {"username", Optional(String)},
  }, platform.user))
end

if platform.group then
  assert(register("group", "Get group from group id", {
    {"gid", Int},
  }, {
    {"group", Optional(String)},
  }, platform.group))
end

if platform.uid then
  assert(register("uid", "Get user id from username", {
    {"username", String},
  }, {
    {"uid", Optional(Int)},
  }, platform.uid))
end

if platform.gid then
  assert(register("gid", "Get user id from group name", {
    {"group", String},
  }, {
    {"gid", Optional(Int)},
  }, platform.gid))
end

if platform.pty then
  local SpawnOptions = assert(alias("SpawnOptions", "Options for spawning child processes", {
    args = Optional(Array(String)),
    env = Optional(Array(String)),
    cwd = Optional(String),
    uid = Optional(Int),
    gid = Optional(Int),
    user = Optional(String),
    group = Optional(String),
  }))

  local WinSize = assert(alias("WinSize", "Cols/Rows pair for pty window size", NamedTuple {
    {"cols", Int},
    {"rows", Int},
  }))

  assert(register("pty", "Create a new pty and spawn a shell with streaming access.", {
    {"shell", String},
    {"size", WinSize},
    {"options", SpawnOptions},
    {"data", Function},
    {"error", Function},
    {"exit", Function},
  }, {
    {"child", NamedTuple {
      {"write", Function},
      {"kill", Function},
      {"resize", Function},
    }}
  }, platform.pty))

end

assert(register("getenv", "Get environment variable", {
  {"name", String}
}, {
  {"value", String}
}, platform.getenv))

assert(register("getos", "Get the Operating System", {
}, {
  {"os", String}
}, platform.getos))

if platform.getuser then
  assert(register("getuser", "Get the username of the agent", {
  }, {
    {"username", Optional(String)}
  }, platform.getuser))
end

assert(register("homedir", "Get the user's home directory", {
}, {
  {"home", String},
}, platform.homedir))

if platform.getuid then
  assert(register("getuid", "Get the userid of the agent", {
  }, {
    {"uid", Optional(Int)}
  }, platform.getuid))
end

if platform.getgid then
  assert(register("getgid", "Get the groupid of the agent", {
  }, {
    {"gid", Optional(Int)}
  }, platform.getgid))
end

if platform.getpid then
  assert(register("getpid", "Get the processid of the agent", {
  }, {
    {"pid", Optional(Int)}
  }, platform.getpid))
end

if platform.uptime then
  assert(register("uptime", "Get system uptime", {
  }, {
    {"uptime", Optional(Int)}
  }, platform.uptime))
end

if platform.freemem then
  assert(register("freemem", "Get free memory", {
  }, {
    {"freemem", Optional(Int)}
  }, platform.freemem))
end

if platform.totalmem then
  assert(register("totalmem", "Get total memory", {
  }, {
    {"totalmem", Optional(Int)}
  }, platform.totalmem))
end

if platform.getrss then
  assert(register("getrss", "Get resident set memory", {
  }, {
    {"getrss", Optional(Int)}
  }, platform.getrss))
end

local function log(...)
  p("log", ...)
end

local api

local function onCLI(read, write, socket)
  local success, err = xpcall(function ()
    local data = ""
    for chunk in read do
      data = data .. chunk
    end
    local message = msgpackDecode(data)
    print("Forwarding command from CLI to client: " .. message[1])
    api.call(unpack(message))
    write()
  end, debug.traceback)
  if not success then
    print(err)
  end

end





coroutine.wrap(function ()
  local url = "wss://localhost:8443/enlist/" .. agentId .. "/" .. token
  local read, write = assert(wsConnect(
    url ,
    "schema-rpc",
    {
      tls = {ca = assert(loadResource("./../agent-cert/new.cert.cert"))}
    }
    ))
  read, write = codec(read, write)
  api = makeRpc(registry.call, log, read, write)
  createServer({
    host = "127.0.0.1",
    port = 13377
  }, onCLI)
  api.readLoop()
end)()
