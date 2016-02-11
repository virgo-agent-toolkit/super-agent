local p = require('pretty-print').prettyPrint
local uv = require('uv')

local function sleep(ms)
  local thread = coroutine.running()
  uv.new_timer():start(ms, 0, function ()
    return assert(coroutine.resume(thread))
  end)
  return coroutine.yield()
end

-- Simulates a socket with latency
-- writes to one end eventually can be read from the other end
local function channel(name1, name2)
  local queue = {}
  local writer = 1
  local reader = 1
  local function read()
    if writer > reader then
      local data = queue[reader]
      queue[reader] = nil
      p(name1, "<-", data)
      reader = reader + 1
      return data
    end
    queue[reader] = coroutine.running()
    reader = reader + 1
    return coroutine.yield()
  end
  local function write(data)
    p(name2, "->", data)
    sleep(10 + math.random(10))
    if reader > writer then
      local thread = queue[writer]
      queue[writer] = nil
      writer = writer + 1
      p(name1, "<-", data)
      assert(coroutine.resume(thread, data))
    else
      queue[writer] = data
      writer = writer + 1
    end
  end
  return read, write
end
-- Create a pair of cross-channels for testing between two virtual processes
local function pair(name1, name2)
  local rA, wB = channel(name1, name2)
  local rB, wA = channel(name2, name1)
  return rA, wA, rB, wB
end

-- Make read/write pairs for virtual client and server
local sread, swrite, cread, cwrite = pair("server", "client")

local client = require('rpc')(sread, swrite, function (name, ...)
  p("Call server:", name, ...)
  if name == "sub" then
    local a, b = ...
    sleep(10)
    return a - b
  end
  return nil, "No such method: " .. name
end, function (...)
  p("Server Log", ...)
end)
local server = require('rpc')(cread, cwrite, function (name, ...)
  p("Call client:", name, ...)
  if name == "add" then
    local a, b = ...
    sleep(1)
    return a + b
  end
  return nil, "No such method: " .. name
end, function (...)
  p("Client Log", ...)
end)

local split = require('coro-split')

coroutine.wrap(function ()
  split(function ()
    assert(client.add(1,2) == 3)
  end, function ()
    assert(server.sub(5,3) == 2)
  end)
  print("Done!")
end)()
