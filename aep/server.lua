
require 'weblit-websocket'
require 'weblit-app'

  .bind {
    port = 8000
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
  }, require 'handle-client')

  .start()
