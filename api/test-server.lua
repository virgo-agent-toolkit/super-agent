local p = require('pretty-print').prettyPrint
local request = require('coro-http').request
local jsonDecode = require('json').parse
local jsonEncode = require('json').stringify
local msgpackDecode = require('msgpack').decode
local msgpackEncode = require('msgpack').encode
local connect = require('websocket-client')

local function dump(...)
  local args = {...}
  for i = 1, select("#", ...) do
    p(args[i])
  end
end
local userAgent = "test-server.lua"

coroutine.wrap(function ()
  local aep = {
    hostname = "localhost"
  }
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"User-Agent", userAgent},
    {"Content-Type", "application/json"}
  }, jsonEncode{aep}))
  dump(request("POST", "http://localhost:8080/api/aep.create", {
    {"User-Agent", userAgent},
    {"Content-Type", "application/msgpack"}
  }, msgpackEncode{aep}))
  local read, write = connect("ws://localhost:8080/websocket", "schema-rpc", {
    {"User-Agent", userAgent}
  })

  write {
    opcode=1,
    payload=jsonEncode{1,"aep.create",aep}
  }
  dump("Result", read())
  write {
    opcode=2,
    payload=msgpackEncode{1,"aep.create",aep}
  }
  dump("result", read())

  local nextId = 2
  local waiters = {}
  coroutine.wrap(function ()
    for frame in read do
      local message
      if frame.opcode == 1 then
        message = assert(jsonDecode(frame.payload))
      elseif frame.opcode == 2 then
        message = assert(msgpackDecode(frame.payload))
      else
        error("Unexpected opcode: " .. frame.opcode)
      end
      p("<-", message)
      if message[1] < 0 then
        local waiter = waiters[-message[1]]
        assert(coroutine.resume(waiter, message[2]))
      elseif message[1] == 0 then
        local err = message[2]
        local id = message[3]
        if id > 0 then
          local waiter = waiters[id]
          assert(coroutine.resume(waiter, nil, err))
        else
          error("Error in rpc stream: " .. err)
        end
      end
    end
  end)()
  local function send(message)
    p("->", message)
    return write {
      opcode = 2,
      payload = msgpackEncode(message)
    }
  end

  local function call(name, ...)
    local id = nextId
    nextId = nextId + 1
    local message = {id, name, ...}
    send(message)
    waiters[id] = coroutine.running()
    return coroutine.yield()
  end

  local magicMeta
  magicMeta = {
    __index = function (self, name)
      return setmetatable({
        name = self.name and (self.name .. "." .. name) or name
      }, magicMeta)
    end,
    __call = function (self, ...)
      return call(self.name, ...)
    end
  }
  local api = setmetatable({name=false}, magicMeta)

  local AEP = api.aep

  local id = assert(AEP.create { hostname = "test.host" })

  assert(AEP.read(id))

  assert(AEP.update { id = id, hostname = "updated.host" })

  assert(AEP.read(id))

  AEP.query({})

  AEP.query({hostname="localhost"})

  AEP.query({hostname="local*"})


  assert(AEP.delete(id))

  assert(not AEP.read(id))

  write()

end)()
