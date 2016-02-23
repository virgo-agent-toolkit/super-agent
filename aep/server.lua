require 'weblit-websocket'
local app = require 'weblit-app'
local p = require('pretty-print').prettyPrint

app.use(require('weblit-logger'))
app.use(require('weblit-auto-headers'))

app.websocket({
  path = "/agent/:agent_id",
  protocol = "schema-rpc"
}, function (req, read, write)
	p(req)
  for message in read do
    write {
      opcode = message.opcode,
      payload = message.payload
    }
  end
  write()


end)

app.start()
