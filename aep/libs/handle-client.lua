local p = require('pretty-print').prettyPrint
local split = require('coro-split')
local agents = require('agents')

return function (req, read, write)
  local agent = agents[req.params.agent_id]
  if not agent then return end
  local aread, awrite = unpack(agent)
  split(function ()
    p("Agent connected")
    for message in aread do
      p("->", message)
      write(message)
    end
    p("Agent disconnected")
    write()
  end, function ()
    p("Client connected")
    for message in read do
      p("<-", message)
      awrite(message)
    end
    p("Client disconnected")
    awrite()
  end)
end
