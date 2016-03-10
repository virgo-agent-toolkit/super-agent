local p = require('pretty-print').prettyPrint
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

local clientHandlers = {}

local function getClientHandler(agent_id)
  local clientHandler = clientHandlers[agent_id]
  if clientHandler then return clientHandler end
  return nil, "No such agent: " .. agent_id
end

local function newAgent(agent_id, read, write, socket)
  local address = socket:getpeername()
  p("Agent connect", agent_id, address)

  local nextId = 1
  local rmappings = {}
  local cmappings = setmetatable({}, {
    __mode = "k"
  })
  local clients = {}

  clientHandlers[agent_id] = function (cread, cwrite, csocket)
    local caddress = csocket:getpeername()
    p("new client", agent_id, caddress)
    clients[cwrite] = true
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
      if type(value) ~= "table" then return end
      if next(value) ~= '' or next(value, '') then
        for _, v in pairs(value) do
          recursiveMap(v)
        end
        return
      end
      value[''] = mapRequest(value[''])
    end

    for message in cread do
      if type(message) ~= "table" or type(message[1]) ~= "number" then
        cwrite {0, "Invalid message"}
        break
      end
      if message[1] > 0 then
        message[1] = mapRequest(message[1])
        recursiveMap(message)
      end
      write(message)
    end
    cwrite()
    clients[cwrite] = nil
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
      message[1] = -rmappings[id]
      local cwrite = cmappings[id]
      cwrite(message)
    elseif id == 0 then
      if message[2] then
        print(message[2])
      end
      break
    elseif id > 0 then
      p("Handle requests from agent", message)
    end
  end
  write()
  p("Agent disconnect", agent_id, address)
  for cwrite in pairs(clients) do
    p(cwrite)
    cwrite {0, "Agent disconnected"}
    cwrite()
  end
end

return {
  getClientHandler = getClientHandler,
  newAgent = newAgent,
}
