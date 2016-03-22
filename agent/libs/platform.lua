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

local platform = {}

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
  local i = 0
  local chunks = {}
  local exists = platform.readstream(path, function (chunk)
    i = i + 1
    chunks[i] = chunk
  end)
  if not exists then return nil end
  return table.concat(chunks)
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
  return {
    stat.mtime.sec,
    stat.atime.sec,
    stat.size,
    stat.type,
    stat.mode,
    stat.uid,
    stat.gid
  }
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
      detached = true
    }, function (...)
      write, kill, resize = write, kill, resize

      local args = {...}
      coroutine.wrap(function ()
        return onExit(unpack(args))
      end)()
    end)

    local pipe = uv.new_pipe(false)
    pipe:open(master)
    pipe:read_start(function (err, data)
      coroutine.wrap(function ()
        if err then
          return onError(err)
        else
          return onData(data)
        end
      end)()
    end)

    function write(chunk)
      local err
      if chunk then
        err = async(pipe.write, pipe, chunk)
      else
        err = async(pipe.shutdown, pipe)
        pipe:close()
      end
      -- TODO: handle err in own callback
      if err then
        onError(err)
      end
    end

    function kill(signal)
      child:kill(signal)
    end

    local size_s = ffi.new("struct winsize")
    function resize(cols, rows)
      size_s.ws_col, size_s.ws_row = cols, rows
      if ffi.C.ioctl(slave, TIOCSWINSZ, size_s) < 0 then
        onError("Problem resizing pty")
      end
    end

    return {write, kill, resize}

  end
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


if ffi.os ~= "Windows" then

  -- getuser() -> (username: Optional(String))
  function platform.getuser()
    return platform.user(uv.getuid())
  end

end

-- homedir() -> (home: String)
platform.homedir = uv.os_homedir

platform.getuid = uv.getuid

platform.getgid = uv.getgid

platform.getpid = uv.getpid

platform.uptime = uv.uptime

function platform.loadavg()
  return {uv.loadavg()}
end

platform.freemem = uv.get_free_memory

platform.totalmem = uv.get_total_memory

platform.getrss = uv.resident_set_memory

platform.cpuinfo = uv.cpu_info

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
  local fn, err = loadstring(code)
  if not fn then
    error("ESYNTAXERROR: " .. err)
  end
  setfenv(fn, env)
  local success, result = pcall(fn)
  if not success then
    error("EEXCEPTION: " .. result)
  end
  return result
end

return platform
