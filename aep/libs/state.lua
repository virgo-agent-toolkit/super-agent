local p = require('pretty-print').prettyPrint
--[[

- agent has api endpoints
- aep has api endpoints
- agent connects to aep
- aep also forwards requests from and responses to clients
- TODO: figure out how streams will multiplex between multiple clients.

Example:

  Client1 sends request 1 -> aep maps to 1
  Client2 sends request 1 -> aep maps to 2
  Aep forwards requests to agent as 1 and 2
  Agent responds with -1 and -2
  Aep forwards responses as -1 on to client1 and -1 to client2

  Client 1 sends [2,"echo",3]
  *** Somehow aep needs to know `3` needs mapping
      so that 2 become 3 and 3 becomes 4 ***
  aep sends [3,"echo",4] to agent
  agent responds with [-3,1]
  aep maps to [-2,1] and forwards to client 1.
      note: there is no need to map the agent's stream IDs


]]

--[[
agent = {
  id = "145174859", -- agent_id
  clients = {} -- set of clients
  write = write -- send message to this agent
  nextId = 1 -- nextId for allocating mappings
  mappings = {} -- mapping from agent req id to client and client id
}

client = {
  mappings = {} -- map from client req id to agent req id
  write = write -- send message to client
}
]]

local agents = {}

local function getAgent(agent_id)
  local agent = agents[agent_id]
  if agent then return agent end
  return nil, "No such agent: " .. agent_id
end

local function newAgent(agent_id, read, write, socket)
  local address = socket:getpeername()
  local agent = {}
  agents[agent_id] = agent
  p("Agent connect", agent_id, address)

  local nextId = 10
  local rmappings = {}
  local cmappings = setmetatable({}, {
    __mode="k"
  })

  function agent.newClient(cread, cwrite, csocket)
    local caddress = csocket:getpeername()
    p("new client", agent_id, caddress)
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
      p("TODO: disconnect all clients")
    elseif id > 0 then
      p("Handle requests from agent", message)
    end
  end
  write()
  p("Agent disconnect", agent_id, address)
end

return {
  getAgent = getAgent,
  newAgent = newAgent,
}
--
-- local p = require('pretty-print').prettyPrint
--
-- local agents = {}
--
-- local function agentConnect(agent)
--   agents[agent.id] = agent
--   p("New agent connected", agent.id, agent.socket:getpeername())
-- end
--
-- local function clientDisconnect(agent, client)
--   agent.clients[client] = nil
--   client.write()
--   p("Client disconnect", client)
-- end
--
-- local function agentDisconnect(agent)
--   agents[agent.id] = nil
--   agent.write()
--   p("Agent disconnect", agent.id)
--   local list = agent.clients[agent.id]
--   if list then
--     for client in pairs(list) do
--       clientDisconnect(agent, client)
--     end
--   end
-- end
--
-- local function getAgent(id)
--   return agents[id]
-- end
--
-- local function clientConnect(client)
--   local clientList = clients[client.agent_id]
--   if not clientList then
--     clientList = {}
--     clients[client.agent_id] = clientList
--   end
--   clientList[client] = true
--   p("New client connected", client.agent_id, client.socket:getpeername())
-- end
--
-- return {
--   agentConnect = agentConnect,
--   agentDisconnect = agentDisconnect,
--   agentMessage = agentMessage,
--   getAgent = getAgent,
--   clientConnect = clientConnect,
--   clientDisconnect = clientDisconnect,
--   clientMessage = clientMessage,
-- }
