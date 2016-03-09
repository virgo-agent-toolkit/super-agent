local codec = require('websocket-to-message')
local getAgent = require('state').getAgent

return function (req, read, write)
  -- TODO: verify client's authentication and authorization
  local agent = assert(getAgent(req.params.agent_id))
  read, write = codec(read, write)
  agent.newClient(read, write, req.socket)
end
