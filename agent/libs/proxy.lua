local sha1 = require('sha1')
--[[

- agent has api endpoints
- aep has api endpoints
- agent connects to aep
- aep also forwards requests from and responses to clients

Example:

  Client1 sends request 1 -> aep maps to 1
  Client2 sends request 1 -> aep maps to 2
  Aep forwards requests to agent as 1 and 2
  Agent responds with -1 and -2
  Aep forwards responses as -1 on to client1 and -1 to client2

  Client 1 sends [2,"echo",{"":3}]
    aep maps 2 to 3 and 3 to 4
  aep sends [3,"echo",{"":4}] to agent
  agent responds with [-3,1]
  aep maps to [-2,1] and forwards to client 1.
      note: there is no need to map the agent's stream IDs
]]


-- config.ip
-- config.port
-- config.tls
-- config.users
return function (config)

  local clientHandlers = {}
  local requestHandlers = {}

  local function getClientHandler(agent_id)
    local clientHandler = clientHandlers[agent_id]
    if clientHandler then return clientHandler end
    return nil, "No such agent: " .. agent_id
  end

  local function getRequestHandler(agent_id)
    local requestHandler = requestHandlers[agent_id]
    if requestHandler then return requestHandler end
    return nil, "No such agent: " .. agent_id
  end

  local function newAgent(agent_id, read, write, socket)
    local address = socket:getpeername()
    p("Agent connect", agent_id, address)

    local nextId = 1
    local rmappings = {}
    local waiting = {}
    local cmappings = setmetatable({}, {
      __mode = "k"
    })
    local clients = setmetatable({}, {
      __mode = "v"
    })

    requestHandlers[agent_id] = function (name, ...)
      p("Request", name, ...)
      local id = nextId
      nextId = nextId + 1
      waiting[id] = coroutine.running()
      write{id,name,...}
      return coroutine.yield()
    end

    clientHandlers[agent_id] = function (cread, cwrite, csocket)
      local caddress = csocket:getpeername()
      p("new client", agent_id, caddress)
      local key = sha1(caddress.ip .. '-' .. caddress.port)
      clients[key] = cwrite
      local mappings = {}

      local function mapRequest(id)
        local nid = mappings[id]
        if nid then return nid end
        nid = nextId
        nextId = nextId + 1
        mappings[id] = nid
        rmappings[nid] = id
        cmappings[nid] = cwrite
        return nid
      end

      local function recursiveMap(value)
        if type(value) ~= "table" then return value end
        if next(value) ~= '' or next(value, '') then
          for k, v in pairs(value) do
            value[k] = recursiveMap(v)
          end
          return value
        end
        local id = value['']
        if id == 0 then
          return key
        else
          value[''] = mapRequest(id)
        end
        return value
      end

      for message in cread do
        if type(message) ~= "table" or type(message[1]) ~= "number" then
          cwrite {0, "Invalid message"}
          break
        end
        if message[1] > 0 and message[2] == 'key' then
          cwrite({-message[1],key})
        else
          if message[1] > 0 then
            message[1] = mapRequest(message[1])
          end
          recursiveMap(message)
          write(message)
        end
      end
      cwrite()
      clients[key] = nil
      p("Client disconnect", agent_id, caddress)
    end

    for message in read do
      if type(message) ~= "table" or type(message[1]) ~= "number" then
        write {0, "Invalid message"}
        break
      end
      local id = message[1]
      if id < 0 then
        id = -id
        local rmap = rmappings[id]
        if rmap then
          message[1] = -rmap
          local cwrite = cmappings[id]
          cwrite(message)
        else
          local thread = waiting[id]
          if thread then
            waiting[id] = nil
            assert(coroutine.resume(thread, unpack(message, 2)))
          else
            print("Unknown response id: " .. id)
          end
        end
      elseif id == 0 then
        if message[2] then
          print(message[2])
        end
        break
      elseif id > 0 then
        local key = message[2]
        local cwrite = clients[key]
        cwrite({id, unpack(message, 3)})
      end
    end
    write()
    p("Agent disconnect", agent_id, address)
    for key, cwrite in pairs(clients) do
      p(key, cwrite)
      cwrite {0, "Agent disconnected"}
      cwrite()
    end
  end

end
