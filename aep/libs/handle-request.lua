local getRequestHandler = require('proxy').getRequestHandler
local jsonEncode = require('json').encode

return function (req, res)
  local agentId = req.params.agent_id
  local requestHandler, err = getRequestHandler(agentId)
  if not requestHandler then
    res.code = 404
    res.body = err .. "\n"
    return
  end
  local args = {}
  for part in req.params.args:gmatch("[^/]+") do
    args[#args + 1] = part
  end
  local result, error = requestHandler(unpack(args))
  if result then
    res.code = 200
    res.headers["Content-Type"] = "application/json"
    res.body = jsonEncode(result) .. "\n"
  else
    res.code = 500
    res.body = error
  end
end
