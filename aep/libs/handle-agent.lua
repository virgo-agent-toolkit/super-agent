local codec = require('websocket-to-message')
local newAgent = require('proxy').newAgent

-- -- Token to account mapping
-- local tokenMap = {
--   ["d8e92bcf-2adf-4bd7-b570-b6548e2f6d5f"] = "81fe0418-6049-437c-8fe3-c86bd9fd5dc2"
-- }
-- -- Agent to account mapping
-- local agentMap = {
--   ["fc1eb9f7-69f0-4079-9e74-25ffd091022a"] = "81fe0418-6049-437c-8fe3-c86bd9fd5dc2"
-- }

return function (req, read, write)
  local agent_id = req.params.agent_id
  -- local token = req.params.token
  -- local account_id = agentMap[agent_id]
  -- -- assert(tokenMap[token] == account_id, "Agent authentication error")
  read, write = codec(read, write)
  return newAgent(agent_id, read, write, req.socket)
end
