local uv = require('uv')
-- local p = require('pretty-print').prettyPrint

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
  return path .. (path:match("\\") and  "\\" or "/") .. name
end

local platform = {}

-- echo (data: Emitter(value: Any)) -> (data: Emitter(value: Any))
function platform.echo(onData)
  return onData
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

--
-- chmod (
--   path: String
--   mode: Integer
-- ) -> ()
--
-- chown (
--   path: String
--   uid: Integer
--   gid: Integer
-- ) -> ()
--
-- utime (
--   path: String
--   atime: Number
--   mtime: Number
-- ) -> ()
--
-- rename (
--   path: String
--   newPath: String
-- ) -> ()
--
-- realpath (path: String) -> (fullPath: String)
--
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
-- ) -> (
--   exists: Bool
-- )
--
-- user (uid: Integer) -> (username: Optional(String))
--
-- group (gid: Integer) -> (groupname: Optional(String))
--
-- uid (username: String) -> (uid: Optional(Integer))
--
-- gid(groupname: String) -> (gid: Optional(Integer))
--
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
--   data: Stream
--   exit: Emitter(
--     code: Integer
--     signal: Integer
--   )
-- ) -> (
--   data: Stream
--   kill: Emitter(signal: Integer)
--   resize: Emitter(WinSize)
-- )

return platform
