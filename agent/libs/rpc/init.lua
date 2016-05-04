local makeFreezer = require('./freeze')

-- Proxy tunnel protocol

-- [from,to] - initial assignment
-- [from,to,true] - client connected (only for servers)
-- [from,to,...] - data payload
-- [from,to,false] - virtual socket disconnected

-- RPC protocol

-- [reqId,fn,....] - CALL (fn can be string or id)
-- [-reqId,....] - return value / exception (also for emitters)

-- Accepts:
--   call(name, ...)
--   log(severity, message, ...)
--   read() -> message or nil
--   write(message or nil)
-- Returns:
--   readLoop()
--   callRemote(name, ...)
--   close()
return function (call, log, read, write)

  -- Map of request id to waiting thread.  Used to route responses to caller.
  local waiting = {}

  local idToFn = setmetatable({}, {
    -- TODO: find out how to prevent this weak mapping from loosing refs elsewhere.
    -- __mode = "v"
  })
  local fnToId = setmetatable({}, {
    __mode = "k"
  })

  local nextId = 1

  local function getId()
    local id = nextId
    while idToFn[id] or waiting[id] do
      id = id + 1
    end
    nextId = id + 1
    return id
  end

  local function registerFunction(fn)
    local id = fnToId[fn]
    if id then return id end
    id = getId()
    fnToId[fn] = id
    idToFn[id] = fn
    return id
  end

  -- Helper to make remote calls.  Blocks caller waiting for response.
  local function callRemote(name, ...)
    local id = getId()
    write {id, name, ...}
    waiting[id] = coroutine.running()
    return coroutine.yield()
  end

  read, write = makeFreezer(read, write, registerFunction, callRemote)

  local closed = false
  local function close(err)
    if closed then return end
    closed = true
    if err then
      write{0,err}
    end
    write()
  end

  local function readLoop()
    local success, stack = xpcall(function ()
      for message in read do
        collectgarbage()
        collectgarbage()
        if not(type(message) == "table" and
               type(message[1]) == "number") then
          close "invalid message format"
          break;
        end
        local id = message[1]

        -- Request from remote
        if id > 0 then
          -- Call API function in background and continue processing
          coroutine.wrap(function ()
            local results
            local success, stack = xpcall(function ()
              local name = message[2]
              if type(name) == "number" then
                local fn = assert(idToFn[name], "Invalid fn id")
                results = {fn(unpack(message, 3))}
              elseif type(name) == "string" then
                results = {call(name, unpack(message, 3))}
              else
                log(2, "invalid message format")
                error "ETYPEERROR: name must be string or number in remote call"
              end
            end, debug.traceback)
            if not success then
              log(2, stack)
              local e = stack:match("(E[A-Z]+:[^\n]+)\n")
              write {-id, nil, e or "Server Error"}
              if not e then log(2, stack) end
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
          nextId = id

          if thread then
            local success, err = coroutine.resume(thread, unpack(message, 2))
            if not success then
              log(2, err or "problem")
            end
          else
            -- Call function in background and continue processing
            coroutine.wrap(function ()
              local success, err = xpcall(function ()
                return fn(unpack(message, 2))
              end, debug.traceback)
              if not success then
                log(2, err or "problem")
              end
            end)()
          end


        -- End of RPC stream (id == 0)
        else
          break
        end
      end
    end, debug.traceback)
    -- Log uncaught exceptions as fatal
    if not success then
      pcall(log, 1, stack)
    end
    -- Log global errors received on socket
    if error then
      pcall(log, 2, error)
    end
  end

  return readLoop, callRemote, close
end
