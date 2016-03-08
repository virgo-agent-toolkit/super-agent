local agents = require('agents')

-- Token to account mapping
local tokenMap = {
  ["d8e92bcf-2adf-4bd7-b570-b6548e2f6d5f"] = "81fe0418-6049-437c-8fe3-c86bd9fd5dc2"
}
-- Agent to account mapping
local agentMap = {
  ["fc1eb9f7-69f0-4079-9e74-25ffd091022a"] = "81fe0418-6049-437c-8fe3-c86bd9fd5dc2"
}

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

return function (req, read, write)
  local agent_id = req.params.agent_id
  local token = req.params.token
  local account_id = agentMap[agent_id]
  assert(tokenMap[token] == account_id, "Agent authentication error")
  print("New agent connected", agent_id)
  agents[agent_id] = {read, write, coroutine.running()}
  coroutine.yield()
  print("agent disconnected", agent_id)
end
