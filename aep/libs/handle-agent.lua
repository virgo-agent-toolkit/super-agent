local agents = require('agents')

return function (req, read, write)
  -- TODO: verify agent token
  agents[req.params.agent_id] = {read, write, coroutine.running()}
  return coroutine.yield()
end
