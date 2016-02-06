require 'weblit-websocket'
require './crud/aep'
require('weblit-app')

.bind {
  host = "127.0.0.1",
  port = 8080
}

.use(require('weblit-logger'))
.use(require('weblit-auto-headers'))

.websocket({
  path = "/websocket",
  protocol = "schema-rpc"
}, require('websocket-handler'))

.route({
  method = "POST",
  path = "/api/:path:"
}, require('http-handler'))

.start()
