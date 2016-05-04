-- TODO: write a parser for platform.api that replaces the need for this file.

local platform = require('platform')
local registry = require('registry')()
platform.registry = registry
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

assert(register("readbinary", "Read a file as a binary blob", {
  {"path", String},
}, {
  {"data", Optional(Any)},
}, platform.readbinary))

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

assert(register("largefiles", "Find the largest files in a filesystem", {
  {"rootPath", String},
  {"limit", Int},
  {"onError", Function},
}, {
  {"biggest", Array{String,Int}}
}, platform.largefiles))


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

local SpawnOptions = assert(alias("SpawnOptions", "Options for spawning child processes", {
  args = Optional(Array(String)),
  env = Optional(Array(String)),
  cwd = Optional(String),
  uid = Optional(Int),
  gid = Optional(Int),
  user = Optional(String),
  group = Optional(String),
}))

assert(register("spawn", "spawn an arbitrary child process with streaming pipes", {
  {"command", String},
  {"options", SpawnOptions},
  {"stdout", Function},
  {"stderr", Function},
  {"error", Function},
  {"exit", Function},
}, {
  {"data", Function},
  {"kill", Function},
}, platform.spawn))

if platform.pty then

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
    {"write", Function},
    {"kill", Function},
    {"resize", Function},
  }, platform.pty))

end


if platform.hostname then
  assert(register("hostname", "Get the machine's hostname", {
  }, {
    {"host", Optional(String)}
  }, platform.hostname))
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

assert(register("getarch", "Get the System architecture", {
}, {
  {"arch", String}
}, platform.getarch))

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

assert(register("getusername", "Get username of controlling process", {
}, {
  {"username", Optional(String)},
}, platform.getusername))

assert(register("uptime", "Get system uptime", {
}, {
  {"uptime", Optional(Int)}
}, platform.uptime))

assert(register("freemem", "Get free memory", {
}, {
  {"freemem", Optional(Int)}
}, platform.freemem))

assert(register("totalmem", "Get total memory", {
}, {
  {"totalmem", Optional(Int)}
}, platform.totalmem))

assert(register("getrss", "Get resident set memory", {
}, {
  {"getrss", Optional(Int)}
}, platform.getrss))

assert(register("loadavg", "Get the average system load", {
}, {
  {"avg", {Number, Number, Number}}
}, platform.loadavg))

assert(register("cpuinfo", "Get the average system load", {
}, {
  {"info", Array {
    times = {
        user=Int,
        idle=Int,
        sys=Int,
        nice=Int
      },
      model=String,
      speed=Int}
    }
}, platform.cpuinfo))

assert(register("iaddr","Get network interfaces",{
}, {
  {"interfaces", Array{
    netmask=String,
    ip=String,
    mac=String,
    internal=Bool,
    family=String,
    iname=String}
  }
}, platform.iaddr))

assert(register("script", "Run a remote script against the platform API", {
  {"code", String},
}, {
  {"result", Any},
}, platform.script))

assert(register("eval", "Turn a piece of lua into a callable function", {
  {"name", String},
  {"code", String},
}, {
  {"fn", Function}
}, platform.eval))

assert(register("register", "Register an ad-hoc script to be run multiple times", {
  {"name", String},
  {"code", String},
}, {
  {"success", Bool}
}, platform.register))

assert(register("exec", "Semantic sugar around spawn", {
  {"command", String},
  {"spawnOptions", SpawnOptions},
  {"stdin", String}
}, {
  {"stdout", String},
  {"stderr", String},
  {"code", Int},
  {"signal", Int}
}, platform.exec))

return registry
