-- Database connection setup
local getenv = require('os').getenv
local db = require('connection')({
  password = getenv('PASSWORD'),
  database = getenv('DATABASE'),
})

-- API endpoints setup
local registry = require('registry')()
require('./crud/account')(db, registry.section("account"))
require('./crud/aep')(db, registry.section("aep"))
require('./crud/agent')(db, registry.section("agent"))


-- HTTP setup
require 'weblit-websocket'
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
}, require('websocket-handler')(registry.call))

.route({
  method = "POST",
  path = "/api/:path:"
}, require('http-handler')(registry.call))

.start()
