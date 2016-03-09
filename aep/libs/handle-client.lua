local codec = require('websocket-to-message')
local getClientHandler = require('proxy').getClientHandler

return function (req, read, write)
  -- TODO: verify client's authentication and authorization
  local newClient = assert(getClientHandler(req.params.agent_id))
  read, write = codec(read, write)
  newClient(read, write, req.socket)
end
