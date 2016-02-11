
-- Request/Response is bidirectional and in the form:
--  request [id, name, args...]
--  response [-id, result]
--  error response [-id, nil, error]

-- Stream packets are bidirectional and in the form:
--  packet-from-owner [0, sid, chunk]
--  packet-from-client [0, -sid, chunk]
--  end-from-owner [0, sid]
--  end-from-client [0, -sid]
--  error-from-owner [0, sid, nil, error]
--  error-from-client [0, -sid, nil, error]

-- Global shutdown/errors are in the form:
--  global-error [0, 0, error]
--  global-end [0, 0]
--  and will then terminate the stream.

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
return function (call, log, read, write)
  assert(type(read) == "function", "read should be function")
  assert(type(write) == "function", "write should be function")
  assert(type(call) == "function", "call should be function")
  assert(type(log) == "function", "log should be function")

  -- Map of request id to waiting thread.  Used to route responses to caller.
  local waiting = {}

  -- Run the read loop in a background thread
  local graceful, error
  local function readLoop()
    local success, stack = xpcall(function ()
      for message in read do
        if not(type(message) == "table" and
               type(message[1]) == "number") then
          write {0, 0, "invalid message format"}
          break;
        end
        local id = message[1]

        -- Request from remote
        if id > 0 then
          local name = message[2]
          if type(name) ~= "string" then
            write {-id, nil, "name must be string in remote call"}
          else
            -- Call API function in background and continue processing
            coroutine.wrap(function ()
              local result, err
              local args = {}
              for i = 3, #message do
                args[i-2] = message[i]
              end
              local success, stack = xpcall(function ()
                result, err = call(name, unpack(args))
              end, debug.traceback)
              if not success then
                write {-id, nil, "Server Error"}
                log(0, stack)
              else
                write {-id, result, err}
              end
            end)()
          end

        -- Response from remote
        elseif id < 0 then
          id = -id
          local thread = waiting[id]
          if not thread then
            write {0, 0, "Unexpected response id"}
            break
          end
          waiting[id] = nil
          local args = {}
          for i = 2, #message do
            args[i - 1] = message[i]
          end
          local success, err = coroutine.resume(thread, unpack(args))
          if not success then
            log(1, err)
          end

        -- global error or stream message (id == 0)
        else
          local sid = message[2]
          if sid == 0 then
            graceful = true
            error = message[3]
            break
          end
          if type(sid) ~= "number" then
            write {0, 0, "stream id must be integer"}
            break
          else
            error("TODO: handle stream packets")
          end
        end

      end
      if graceful then
        write(0,0)
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

  -- Helper to make remote calls.  Blocks caller waiting for response.
  local nextId = 1
  local function callRemote(name, ...)
    local id = nextId
    nextId = nextId + 1
    write {id, name, ...}
    waiting[id] = coroutine.running()
    return coroutine.yield()
  end

  local function close()
    return write {0,0}
  end

  -- Return the api magic object
  return setmetatable({
    call = callRemote,
    name = false,
    readLoop = readLoop,
    close = close,
  }, magicMeta)
end
