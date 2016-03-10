local uv = require('uv')

local pack = table.pack

-- Function to make it easy to consume callback-based APIs in a coroutine world.
--
--     local err, result = async(asyncThing, arg1, arg2...)
--
local function async(fn, ...)
  local thread = coroutine.running()
  local args = pack(...)
  args[args.n + 1] = function (...)
    return coroutine.resume(thread, ...)
  end
  fn(unpack(args))
  return coroutine.yield()
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

--
-- writefile (
--   path: String
--   data: Buffer
-- ) -> (created: Boolean)
--
-- symlink (
--   path: String
--   target: String
-- ) -> (created: Boolean)
--
-- mkdir (
--   path: String
--   recursive: Boolean
-- ) -> (created: Boolean)
--
-- unlink (path: String) -> (existed: Boolean)
--
-- rmdir (path: String) -> (existed: Boolean)
--
-- rm (
--   path: String
--   recursive: Boolean
-- ) -> (existed: Boolean)
--
-- lstat (path: String) -> (
--   mtime: Number
--   atime: Number
--   size: Integer
--   type: String
--   mode: Integer
--   uid: Integer
--   gid: Integer
-- )
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
