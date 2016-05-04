local uv = require('uv')
local ffi = require('ffi')

local pack = table.pack

-- Function to make it easy to consume callback-based APIs in a coroutine world.
--
--     local err, result = async(asyncThing, arg1, arg2...)
--
local function async(fn, ...)
  local thread = coroutine.running()
  local args = pack(...)
  args[args.n + 1] = function (...)
    return assert(coroutine.resume(thread, ...))
  end
  fn(unpack(args))
  return coroutine.yield()
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]*$")
end

local function pathjoin(path, name)
  if path == "/" then path = "" end
  return path .. (path:match("\\") and  "\\" or "/") .. name
end

local custom = {}
local platform = setmetatable({}, {
  __index = custom
})

-- echo returns whatever it was given
function platform.echo(...)
  return ...
end

-- scandir (
--   path: String
--   entry: Emitter(
--     name: String
--     type: String
--   )
-- ) -> (exists: Boolean)
function platform.scandir(path, onEntry)
  onEntry = onEntry.emit or onEntry

  local err, req = async(uv.fs_scandir, path)
  if not req then
    if not err or err:match("^ENOENT:") then return false end
    error(err)
  end
  while true do
    local name, typ = uv.fs_scandir_next(req)
    if not name then return true end
    onEntry(name, typ)
  end
end

-- readstream (
--   path: String
--   data: Emitter(chunk: Buffer)
-- ) -> (exists: Boolean)
function platform.readstream(path, onData)
  onData = onData.emit or onData
  local err, fd, chunk
  err, fd = async(uv.fs_open, path, "r", 438)
  if not fd then
    if not err or err:match("^ENOENT:") then return false end
    error(err)
  end
  while true do
    err, chunk = async(uv.fs_read, fd, 1024, -1)
    if not chunk or #chunk == 0 then
      uv.fs_close(fd)
      assert(not err, err)
      return true
    end
    onData(chunk)
  end
end

-- readfile (path: String) -> (data: Optional(Buffer))
function platform.readfile(path)
  local err, fd, stat, data
  err, fd = async(uv.fs_open, path, "r", 438)
  if not fd then
    if not err or err:match("^ENOENT:") then return false end
    error(err)
  end
  err, stat = async(uv.fs_fstat, fd)
  if stat then
    err, data = async(uv.fs_read, fd, stat.size, 0)
  end
  uv.fs_close(fd)
  return (assert(data, err))
end

-- readbinary (path: String) -> (data: Optional(Buffer))
function platform.readbinary(path)
  local data = platform.readfile(path)
  if not data then return nil end
  return ffi.new('uint8_t[?]', #data, data)
end


-- readlink (path: String) -> (target: Optional(String))
function platform.readlink(path)
  local err, target = async(uv.fs_readlink, path)
  if target then return target end
  if not err or err:match("^ENOENT:") then return nil end
  error(err)
end

-- writestream (
--   path: String
--   error: Emitter(String)
-- ) -> (data: Emitter(Optional(Buffer)))
function platform.writestream(path, onError)
  onError = onError.emit or onError

  local err, fd = async(uv.fs_open, path, "w", 438)
  if not fd then error(err or "Unknown problem opening file: " .. path) end
  return function (data)
    if not data then
      uv.fs_close(fd)
      return
    end
    err = async(uv.fs_write, fd, data, -1)
    if err then
      uv.fs_close(fd)
      onError(err)
    end
  end
end

-- writefile (
--   path: String
--   data: Buffer
-- ) -> (created: Boolean)
function platform.writefile(path, data)
  local created = true
  local err, fd = async(uv.fs_open, path, "wx", 438)
  if err and err:match("^EEXIST:") then
    err, fd = async(uv.fs_open, path, "w", 438)
    created = false
  end
  if not fd then error(err or "Unknown problem opening file: " .. path) end
  err = async(uv.fs_write, fd, data, 0)
  assert(not err, err)
  uv.fs_close(fd)
  return created
end

-- symlink (
--   target: String
--   path: String
-- ) -> ()
function platform.symlink(target, path)
  local err = async(uv.fs_symlink, target, path)
  assert(not err, err)
end

-- mkdir (
--   path: String
--   recursive: Boolean
-- ) -> (created: Boolean)
function platform.mkdir(finalPath, recursive)
  local function mkdir(path)
    local err = async(uv.fs_mkdir, path, 493)
    if err then
      if err:match("^EEXIST:") then return false end
      if recursive and err:match("^ENOENT:") then
        local parent = dirname(path)
        if parent then
          mkdir(parent)
          recursive = false
          return mkdir(path)
        end
      end
      error(err)
    end
    return true
  end
  return mkdir(finalPath)
end

-- unlink (path: String) -> (existed: Boolean)
function platform.unlink(path)
  local err = async(uv.fs_unlink, path)
  if err then
    if err:match("^ENOENT:") then return false end
    error(err)
  end
  return true
end

-- rmdir (path: String) -> (existed: Boolean)
function platform.rmdir(path)
  local err = async(uv.fs_rmdir, path)
  if err then
    if err:match("^ENOENT:") then return false end
    error(err)
  end
  return true
end

-- rm (
--   path: String
--   recursive: Boolean
-- ) -> (existed: Boolean)
function platform.rm(rootPath, recursive)
  local function deltree(path, recurse)
    local err = async(uv.fs_rmdir, path)
    if err then
      if recurse and err:match("^ENOTEMPTY:") then
        local req
        err, req = async(uv.fs_scandir, path)
        if not req then
          error(err or "Unknown problem scanning " .. path)
        end
        while true do
          local name, typ = uv.fs_scandir_next(req)
          if not name then break end
          local subpath = pathjoin(path, name)
          if typ == "directory" then
            deltree(subpath, recurse)
          else
            err = async(uv.fs_unlink, subpath)
            assert(not err, err)
          end
        end
        return deltree(path, false)
      end
      error(err)
    end
    return true
  end
  local err = async(uv.fs_unlink, rootPath)
  if err then
    if err:match("^ENOENT:") then return false end
    if err:match("^EPERM:") then return deltree(rootPath, recursive) end
    error(err)
  end
  return true
end

-- lstat (path: String) -> (stat: Optional((
--   mtime: Number
--   atime: Number
--   size: Integer
--   type: String
--   mode: Integer
--   uid: Integer
--   gid: Integer
-- )))
function platform.lstat(path)
  local err, stat = async(uv.fs_lstat, path)
  if not stat then
    if err and err:match("^ENOENT:") then return nil end
    error(err or "Unknown error statting " .. path)
  end
  return stat.mtime.sec,
         stat.atime.sec,
        stat.size,
        stat.type,
        stat.mode,
        stat.uid,
        stat.gid
end

-- chmod (
--   path: String
--   mode: Integer
-- ) -> ()
function platform.chmod(path, mode)
  local err = async(uv.fs_chmod, path, mode)
  assert(not err, err)
end

-- chown (
--   path: String
--   uid: Integer
--   gid: Integer
-- ) -> ()
function platform.chown(path, uid, gid)
  local err = async(uv.fs_chown, path, uid, gid)
  assert(not err, err)
end

-- utime (
--   path: String
--   atime: Number
--   mtime: Number
-- ) -> ()
function platform.utime(path, atime, mtime)
  local err = async(uv.fs_utime, path, atime, mtime)
  assert(not err, err)
end

-- rename (
--   path: String
--   newPath: String
-- ) -> ()
function platform.rename(path, newPath)
  local err = async(uv.fs_rename, path, newPath)
  assert(not err, err)
end

-- realpath (path: String) -> (fullPath: String)
function platform.realpath(path)
  local err, fullPath = async(uv.fs_realpath, path)
  if not fullPath then
    error(err or "Unknown problem getting fullPath for " .. path)
  end
  return path
end

function platform.largefiles(rootPath, limit, onError)
  onError = onError.emit or onError
  local biggest = {}
  local len = 0

  local insert = table.insert

  local function store(name, size)
    if len == 0 then
      biggest[1] = {name, size}
      len = 1
      return
    end

    if len >= limit and size <= biggest[len][2] then
      return
    end

    -- Insert value at sorted position
    local i = 1
    while true do
      if size > biggest[i][2] then
        insert(biggest, i, {name, size})
        len = len + 1
        break
      end
      i = i + 1
      if i > len then
        biggest[i] = {name, size}
        len = len + 1
        break
      end
    end
    if len > limit then
      biggest[len] = nil
      len = limit
    end
  end

  local function search(path)
    local err, req = async(uv.fs_scandir, path)
    if not req then
      return onError(path, err)
    end
    while true do
      local name = uv.fs_scandir_next(req)
      if not name then break end
      local subpath = pathjoin(path, name)
      local stat
      err, stat = async(uv.fs_lstat, subpath)
      if stat then
        if stat.type == "directory" then
          search(subpath)
        else
          store(subpath, stat.size)
        end
      else
        onError(path, err)
      end
    end
  end
  search(rootPath)
  return biggest
end

-- diskusage (
--   path: String
--   depth: Integer
--   onEntry: Emitter(
--     path: String
--     size: Integer
--   )
--   onError: Emitter(
--     path: String
--     error: String
--   )
-- ) -> (exists: Bool)
function platform.diskusage(rootPath, maxDepth, onEntry, onError)
  onEntry = onEntry.emit or onEntry
  onError = onError.emit or onError
  local function scan(path, depth)
    local err, stat = async(uv.fs_lstat, path)
    if not stat then
      if err then
        onError(path, err)
      end
      return 0
    end
    local total = stat.size
    if stat.type == "directory" then
      local req
      err, req = async(uv.fs_scandir, path)
      if not req then
        if not err then
          error("Unknown problem scanning " .. path)
        end
        onError(path, err)
        return total
      end
      while true do
        local name = uv.fs_scandir_next(req)
        if not name then break end
        local subpath = pathjoin(path, name)
        local subtotal
        subtotal, err = scan(subpath, depth - 1)
        if subtotal then
          total = total + subtotal
        elseif err then
          onError(subpath, err)
        else
          error("Unknown problem scanning " .. subpath)
        end
      end
    end
    if depth >= 0 then
      onEntry(path, total)
    end
    return total
  end
  local err, stat = async(uv.fs_stat, rootPath)
  if not stat then
    if not err or err:match("^ENOENT:") then
      return false
    end
    error(err)
  end
  scan(rootPath, maxDepth)
  return true
end

if ffi.os ~= "Windows" then

  ffi.cdef[[
    typedef int uid_t;
    typedef int gid_t;
    struct passwd {
      char   *pw_name;
      char   *pw_passwd;
      uid_t   pw_uid;
      gid_t   pw_gid;
      char   *pw_gecos;
      char   *pw_dir;
      char   *pw_shell;
    };
    struct group {
      char   *gr_name;
      char   *gr_passwd;
      gid_t   gr_gid;
      char  **gr_mem;
    };
    struct passwd *getpwnam(const char *name);
    struct passwd *getpwuid(uid_t uid);
    struct group *getgrnam(const char *name);
    struct group *getgrgid(gid_t gid);
  ]]

  -- user (uid: Integer) -> (username: Optional(String))
  function platform.user(uid)
    local s = ffi.C.getpwuid(uid)
    if s == nil or s.pw_name == nil then return nil end
    return ffi.string(s.pw_name)
  end

  -- group (gid: Integer) -> (groupname: Optional(String))
  function platform.group(gid)
    local s = ffi.C.getgrgid(gid)
    if s == nil or s.gr_name == nil then return nil end
    return ffi.string(s.gr_name)
  end

  -- uid (username: String) -> (uid: Optional(Integer))
  function platform.uid(username)
    local s = ffi.C.getpwnam(username)
    if s == nil then return nil end
    return s.pw_uid
  end

  -- gid(groupname: String) -> (gid: Optional(Integer))
  function platform.gid(groupname)
    local s = ffi.C.getgrnam(groupname)
    if s == nil then return nil end
    return s.gr_gid
  end

end


local function attachReader(stream, onData, onError)
  local function onEvent(err, data)
    return coroutine.wrap(function()
      if err then
        return onError(err)
      end
      stream:read_stop()
      onData(data)
      stream:read_start(onEvent)
    end)()
  end
  stream:read_start(onEvent)
end

local function makeWriter(stream, onError)
  return function (chunk)
    local err
    if chunk then
      err = async(stream.write, stream, chunk)
    else
      err = async(stream.shutdown, stream)
      if not stream:is_closing() then
        stream:close()
      end
    end
    if err then
      onError(err)
    end
  end
end

local function makeKiller(child, handles)
  return function (signal)
    child:kill(signal)
    if not child:is_closing() then
      child:close()
    end
    for i = 1, #handles do
      if not handles[i]:is_closing() then
        handles[i]:close()
      end
    end
  end
end

function platform.exec(command, spawnOptions, stdin)

  local stdinpipe = uv.new_pipe(true)
  local stdoutpipe = uv.new_pipe(true)
  local stderrpipe = uv.new_pipe(true)

  local child
  local thread = coroutine.running()
  local stdout, stderr, exitCode, signal
  local function check()
    if stdout and stderr and exitCode and signal then
      if not stdinpipe:is_closing() then
        stdinpipe:close()
      end
      if not stderrpipe:is_closing() then
        stderrpipe:close()
      end
      if not stdoutpipe:is_closing() then
        stdoutpipe:close()
      end
      if not child:is_closing() then
        child:close()
      end
      assert(coroutine.resume(thread, stdout, stderr, exitCode, signal))
    end
  end


  spawnOptions.stdio = {stdinpipe, stdoutpipe, stderrpipe}

  child = uv.spawn(command, spawnOptions, function (code, sig)
    exitCode = code
    signal = sig
    check()
  end)


  if stdin then
    stdinpipe:write(stdin)
  end
  stdinpipe:shutdown()

  local outTable = {}
  stdoutpipe:read_start(function (err, data)
    if err then
      return assert(coroutine.resume(thread, nil, err))
    end

    if data then
      outTable[#outTable+1] = data
    else
      stdout = table.concat(outTable)
      check()
    end
  end)

  local errTable = {}
  stderrpipe:read_start(function (err, data)
    if err then
      return assert(coroutine.resume(thread, nil, err))
    end

    if data then
      errTable[#errTable+1] = data
    else
      stderr = table.concat(errTable)
      check()
    end
  end)

  return coroutine.yield()
end

function platform.spawn(command, options, onStdout, onStderr, onError, onExit)
  onStdout = onStdout.emit or onStdout
  onError = onError.emit or onError
  onExit = onExit.emit or onExit

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  options.stdio = {stdin, stdout, stderr}

  local child = uv.spawn(command, options, function (...)
    local args = {...}
    return coroutine.wrap(function ()
      return onExit(unpack(args))
    end)()
  end)

  attachReader(stdout, onStdout, onError)
  attachReader(stderr, onStderr, onError)

  return makeWriter(stdin, onError),
         makeKiller(child, {stdin, stderr, stdout})
end

if ffi.os == "OSX" or ffi.os == "Linux" then
  -- Define the bits of the system API we need.
  ffi.cdef[[
    struct winsize {
      unsigned short ws_row;
      unsigned short ws_col;
      unsigned short ws_xpixel;
      unsigned short ws_ypixel;
    };
    int openpty(int *amaster, int *aslave, char *name,
      void *termp, const struct winsize *winp);
    int ioctl(int fd, unsigned long request, struct winsize* size);
  ]]
  local TIOCSWINSZ
  if ffi.os == "OSX" then
    TIOCSWINSZ = 2148037735
  elseif ffi.os == "Linux" then
    TIOCSWINSZ = 21524
  end

  -- Load the system library that contains the symbol.
  local util = ffi.load("util")

  local function openpty(cols, rows)
    -- Lua doesn't have out-args so we create short arrays of numbers.
    local amaster = ffi.new("int[1]")
    local aslave = ffi.new("int[1]")
    local winp = ffi.new("struct winsize")
    winp.ws_row = rows
    winp.ws_col = cols
    if util.openpty(amaster, aslave, nil, nil, winp) < 0 then
      return nil, "Problem creating pty"
    end
    -- And later extract the single value that was placed in the array.
    return amaster[0], aslave[0]
  end


  -- type SpawnOptions = {
  --   args: Optional(Array(String))
  --   env: Optional(Array(String))
  --   cwd: Optional(String)
  --   uid: Optional(Integer)
  --   gid: Optional(Integer)
  --   user: Optional(String)
  --   group: Optional(String)
  -- }
  --
  -- type WinSize = (
  --   cols: Integer
  --   rows: Integer
  -- )
  --
  -- pty (
  --   shell: String
  --   size: Winsize
  --   options: SpawnOptions
  --   data: Emitter(data: Optional(Buffer)),
  --   error: Emitter(err: String),
  --   exit: Emitter(
  --     code: Integer
  --     signal: Integer
  --   )
  -- ) -> (
  --   data: Emitter(chunk: Optional(Buffer))
  --   kill: Emitter(signal: Integer)
  --   resize: Emitter(WinSize)
  -- )
  function platform.pty(shell, size, options, onData, onError, onExit)
    onData = onData.emit or onData
    onError = onError.emit or onError
    onExit = onExit.emit or onExit

    local master, slave = openpty(unpack(size))

    local uid = options.uid
    if options.user then
      uid = platform.uid(options.user)
    end
    local gid = options.gid
    if options.group then
      gid = platform.gid(options.group)
    end
    local write, kill, resize

    -- Spawn the child process that inherits the slave fd as it's stdio.
    local child = uv.spawn(shell, {
      stdio = {slave, slave, slave},
      env = options.env,
      args = options.args,
      cwd = options.cwd,
      uid = uid,
      gid = gid,
    }, function (...)
      local args = {...}
      coroutine.wrap(function ()
        return onExit(unpack(args))
      end)()
    end)

    local pipe = uv.new_pipe(false)
    pipe:open(master)
    attachReader(pipe, onData, onError)

    write = makeWriter(pipe, onError)
    kill = makeKiller(child, {pipe})

    local size_s = ffi.new("struct winsize")
    function resize(cols, rows)
      size_s.ws_col, size_s.ws_row = cols, rows
      if ffi.C.ioctl(slave, TIOCSWINSZ, size_s) < 0 then
        onError("Problem resizing pty")
      end
    end

    return write, kill, resize

  end
end

ffi.cdef[[
  int gethostname(char *name, size_t len);
]]
-- hostname() -> (host: Optional(String))
local lib = ffi.os == 'Windows' and ffi.load('ws2_32') or ffi.C
function platform.hostname()
  local buf = ffi.new("char[256]")
  if lib.gethostname(buf, 255) == 0 then
    return ffi.string(buf)
  end
  return nil
end

-- getenv(name: String) -> (value: Optional(String))
function platform.getenv(name)
  return os.getenv(name)
end

-- getos() -> (os: String)
function platform.getos()
  return ffi.os
end

-- getarch() -> (arch: String)
function platform.getarch()
  return ffi.arch
end

-- homedir() -> (home: String)
platform.homedir = uv.os_homedir

platform.getuid = uv.getuid

platform.getgid = uv.getgid

platform.getpid = uv.getpid

if ffi.os == 'Windows' then
  ffi.cdef[[
    bool GetUserNameA(
      char*  lpBuffer,
      size_t* lpnSize
    );
  ]]

  function platform.getusername()
    local buf = ffi.new('char[256]')
    local size = ffi.new('size_t[1]', 255)
    local l = ffi.load('Advapi32.dll')
    if l.GetUserNameA(buf, size) ~= 0 then
      return ffi.string(buf, size[0] - 1)
    end
    return nil
  end
else
  function platform.getusername()
    return platform.user(platform.getuid())
  end
end

platform.uptime = uv.uptime

function platform.loadavg()
  return {uv.loadavg()}
end

platform.freemem = uv.get_free_memory

platform.totalmem = uv.get_total_memory

platform.getrss = uv.resident_set_memory

platform.cpuinfo = uv.cpu_info

function platform.iaddr()
  local value = uv.interface_addresses()
  local returnValue = {}
  local i = 1
  -- flattening the table
  for interfaceName, interface in pairs(value) do
    for j=1, #interface do
      interface[j]["iname"]=interfaceName
      returnValue[i] = interface[j]
      i = i + 1
    end
  end

  return returnValue
end

local function readOnly(tab)
  return setmetatable({}, {
    __index = tab,
    __newindex = function ()
      error("ReadOnly")
    end
  })
end
platform.next = next
platform.pairs = pairs
platform.pcall = pcall
platform.select = select
platform.tonumber = tonumber
platform.tostring = tostring
platform.type = type
platform.unpack = unpack
platform.xpcall = xpcall
platform.coroutine = readOnly(coroutine)
platform.string = readOnly{
  byte = string.byte,
  char = string.char,
  find = string.find,
  format = string.format,
  gmatch = string.gmatch,
  gsub = string.gsub,
  len = string.len,
  lower = string.lower,
  match = string.match,
  rep = string.rep,
  reverse = string.reverse,
  sub = string.sub,
  upper = string.upper,
}
platform.table = readOnly{
  insert = table.insert,
  maxn = table.maxn,
  remove = table.remove,
  sort = table.sort,
  pack = table.pack,
  unpack = table.unpack,
}
platform.math = readOnly{
  abs = math.abs,
  acos = math.acos,
  asin = math.asin,
  atan = math.atan,
  atan2 = math.atan2,
  ceil = math.ceil,
  cos = math.cos,
  cosh = math.cosh,
  deg = math.deg,
  exp = math.exp,
  floor = math.floor,
  fmod = math.fmod,
  frexp = math.frexp,
  huge = math.huge,
  ldexp = math.ldexp,
  log = math.log,
  log10 = math.log10,
  max = math.max,
  min = math.min,
  modf = math.modf,
  pi = math.pi,
  pow = math.pow,
  rad = math.rad,
  random = math.random,
  sin = math.sin,
  sinh = math.sinh,
  sqrt = math.sqrt,
  tan = math.tan,
  tanh = math.tanh,
}
platform.os = readOnly{
  clock = os.clock,
  difftime = os.difftime,
  time = os.time,
}
local env = readOnly(platform)

platform.script = function (code)
  local fn, err = loadstring(code, "<inline-script>")
  if not fn then
    error("ESYNTAXERROR: " .. err)
  end
  setfenv(fn, env)
  local result = {pcall(fn)}
  if not result[1] then
    error("EEXCEPTION: " .. result[2])
  end
  return unpack(result, 2)
end

function platform.eval(name, lua)
  local fn, err = loadstring(lua, name)
  if not fn then
    error("ESYNTAXERROR: " .. err)
  end
  setfenv(fn, env)
  return
end

-- register(name: String, code: String) -> (success: Bool)
function platform.register(name, code)
  local registry = platform.registry
  local register = registry.register
  local Any = registry.Any

  local fn, err = loadstring(code, name)
  if not fn then
    error("ESYNTAXERROR: " .. err)
  end
  setfenv(fn, env)

  -- Expose to other scripts
  custom[name] = fn
  print("register", name)
  assert(register(name, "Custom user defined function", {
  }, {
    {"exports", Any},
  }, fn))

  return true
end

return platform
