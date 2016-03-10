
-- Request/Response is bidirectional and in the form:
--  request [id, name, args...]
--  response [-id, result...]
--  end-of-stream [0, context...]

local magicMeta
magicMeta = {
  __index = function (self, name)
    assert(name ~= "call")
    return setmetatable({
      name = self.name and (self.name .. "." .. name) or name,
      call = self.call,
    }, magicMeta)
  end,
  __call = function (self, ...)
    return self.call(self.name, ...)
  end
}

-- Read reads a decoded message
-- Write writes a to-be-encoded message
-- Call is a function for provided APIs the other side can call.
--   it's in the form: (name, {args}) -> result
--   and should probably be runtime typechecked by the schema lib.
-- log is called with (severity, message) where severity is:
--   1 - fatal - This message should always be shown and probably reported
--   2 - error - This is a real problem and should not be ignored
--   3 - warning - This is probably a problem, but maybe not.
--   4 - notice - This is for informational purposes only
--   5 - debug - This message is super chatty, but useful for debugging
return function (call, log, rawRead, rawWrite)
  assert(type(rawRead) == "function", "read should be function")
  assert(type(rawWrite) == "function", "write should be function")
  assert(type(call) == "function", "call should be function")
  assert(type(log) == "function", "log should be function")

  -- Map of request id to waiting thread.  Used to route responses to caller.
  local waiting = {}

  local freeze, unfreeze

  local idToFn = setmetatable({}, {
    __mode = "v"
  })
  local fnToId = setmetatable({}, {
    __mode = "k"
  })

  local function read()
    local value, err = rawRead()
    return unfreeze(value), err
  end

  local function write(value)
    return rawWrite(freeze(value))
  end

  -- Run the read loop in a background thread
  local graceful, error, closed

  local function close(err)
    closed = true
    graceful = true
    if err then
      log(1, err)
    end

    return write {0,err}
  end

  local function readLoop()
    local success, stack = xpcall(function ()
      for message in read do
        if not(type(message) == "table" and
               type(message[1]) == "number") then
          close "invalid message format"
          break;
        end
        local id = message[1]

        -- Request from remote
        if id > 0 then
          local name = message[2]
          if type(name) ~= "string" then
            log(1, "invalid message format")
            close "name must be string in remote call"
            break
          end
          -- Call API function in background and continue processing
          coroutine.wrap(function ()
            local results
            local success, stack = xpcall(function ()
              results = {call(name, unpack(message, 3))}
            end, debug.traceback)
            if not success then
              local e = stack:match("(E[A-Z]+:[^\n]+)\n")
              write {-id, nil, e or "Server Error"}
              if not e then log(0, stack) end
            else
              write {-id, unpack(results)}
            end
          end)()

        -- Response from remote
        elseif id < 0 then
          id = -id
          local thread = waiting[id]
          local fn
          if not thread then
            fn = idToFn[id]
            if not fn then
              close "Unexpected response id"
              break
            end
          end
          waiting[id] = nil
          local success, err
          if thread then
            success, err = coroutine.resume(thread, unpack(message, 2))
          else
            success, err = pcall(fn, unpack(message, 2))
          end
          if not success then
            log(1, err)
          end

        -- End of RPC stream (id == 0)
        else
          graceful = true
          error = message[2]
          break
        end
      end
      if graceful and not closed then
        close()
      end
    end, debug.traceback)
    -- Close the socket, ignore any errors
    pcall(write)
    -- Log uncaught exceptions as fatal
    if not success then
      pcall(log, 0, stack)
    end
    -- Log global errors received on socket
    if error then
      pcall(log, 1, error)
    end
    -- Log ungraceful connection closes
    if not graceful then
      pcall(log, 2, "unexpected socket close")
    end
  end

  local nextId = 1

  local function registerFunction(fn)
    local id = fnToId[fn]
    if id then return id end
    id = nextId
    nextId = nextId + 1
    fnToId[fn] = id
    idToFn[id] = fn
    return id
  end

  local function isCallable(fn, t)
    if t == "function" then return true end
    if t ~= "table" then return false end
    local meta = getmetatable(fn)
    return meta and meta.__call
  end

  function freeze(val)
    local t = type(val)
    if isCallable(val, t) then
      return { [""] = registerFunction(val) }
    end
    if t ~= "table" then return val end
    local copy = {}
    for k, v in pairs(val) do
      copy[k] = freeze(v)
    end
    return copy
  end

  function unfreeze(val)
    local t = type(val)
    if t ~= "table" then return val end
    local id = val[""]
    if type(id) == "number" and next(val) == "" and next(val, "") == nil then
      return function (...)
        return write {-id, ...}
      end
    end
    local copy = {}
    for k, v in pairs(val) do
      copy[k] = unfreeze(v)
    end
    return copy
  end

  -- Helper to make remote calls.  Blocks caller waiting for response.
  local function callRemote(name, ...)
    local id = nextId
    nextId = nextId + 1
    write {id, name, ...}
    waiting[id] = coroutine.running()
    return coroutine.yield()
  end

  -- Return the api magic object
  return setmetatable({
    call = callRemote,
    name = false,
    readLoop = readLoop,
    close = close,
  }, magicMeta)
end
