require 'weblit-websocket'
local app = require 'weblit-app'
local p = require('pretty-print').prettyPrint
local split = require('coro-split')

local agents = {}

local function handleClient(req, read, write)
  local agent = agents[req.params.agent_id]
  if not agent then return end
  local aread, awrite = unpack(agent)
  split(function ()
    for message in aread do
      p("->", message)
      write(message)
    end
    p("Agent disconnected")
    write()
  end, function ()
    for message in read do
      p("<-", message)
      awrite(message)
    end
    p("Client disconnected")
    awrite()
  end)

end

local function handleAgent(req, read, write)
  -- TODO: verify agent token
  agents[req.params.agent_id] = {read, write, coroutine.running()}
  return coroutine.yield()
end

app.bind {
  port = 8000
}

app.use(require('weblit-logger'))
app.use(require('weblit-auto-headers'))

app.websocket({
  path = "/request/:agent_id",
  protocol = "schema-rpc"
}, handleClient)

app.websocket({
  path = "/enlist/:agent_id/:token",
  protocol = "schema-rpc"
}, handleAgent)

app.start()
