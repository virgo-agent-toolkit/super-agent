local connect = require('websocket-client')
local registry = require('types')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')
local log = require('log').log

-- config.id - agent id
-- config.token - agent auth token
-- config.proxy - ws(s):// url to proxy server without path
-- config.cert - cert used to verify proxy server (in place of public root certs)
return function(config)
  local url = config.proxy .. "/enlist/" .. config.id .. "/" .. config.token
  log(4, "Connecting to aep", url)
  local options = {}
  if config.cert then
    log(5, "Using custom cert", options.cert)
    options.tls = { cert = config.cert }
  end
  log(5, "options", options)
  local read, write, socket = assert(connect(url, "schema-rpc", options))
  log(4, "connected", socket:getpeername())

  read, write = codec(read, write)
  local api = makeRpc(registry.call, log, read, write)
  api.readLoop()
  log(4, "disconnecting...")
  write()
  if not socket:is_closing() then
    socket:close()
  end
end
