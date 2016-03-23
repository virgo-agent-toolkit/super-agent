
require 'weblit-websocket'
local loadResource = require('resource').load
require 'weblit-app'

  .bind {
    host = "0.0.0.0",
    port = 8000
  }

-- so now the aep should have the key and cert
-- now it needs to also be given to the agent and have it send along the cert in the wss
  .bind {
    host = "0.0.0.0",
    port = 8443,
    tls= {
      key = assert(loadResource("./agent-cert/new.cert.key")),
      cert = assert(loadResource("./agent-cert/new.cert.cert"))
    }
  }

  .use(require 'weblit-logger')
  .use(require 'weblit-auto-headers')

  .websocket({
    path = "/request/:agent_id",
    protocol = "schema-rpc"
  }, require 'handle-client')

  .websocket({
    path = "/enlist/:agent_id/:token",
    protocol = "schema-rpc"
  }, require 'handle-agent')

  .route({
    method = "POST",
    path = "/request/:agent_id/:name"
  }, require 'handle-request')

  .start()
