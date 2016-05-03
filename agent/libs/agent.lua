local codec = require('websocket-to-message')
local makeRpc = require('rpc2')
local log = require('log').log
local makeCall = require('make-call')
local proxyServer = require('tunnel').server


-- Proxy support
--   options.proxy - url of proxy server
-- Standalone support
--   options.host
--   options.port
--   options.tls
-- Expose API
--   options.api - high level call wrapper
--   options.call(name, ...) - raw call function
--     1 - fatal - This message should always be shown and probably reported
--     2 - error - This is a real problem and should not be ignored
--     3 - warning - This is probably a problem, but maybe not.
--     4 - notice - This is for informational purposes only
--     5 - debug - This message is super chatty, but useful for debugging
-- the onClient function will be given (rpc, socket) for each client
return function (options, onClient)
  if not options then options = {} end
  -- Use or generate call function for RPC integration
  local call = makeCall(options.call, options.api)

  local function onConnection(read, write, socketOrId)
    local rpc = makeRpc(call, log, read, write)
    onClient(rpc, socketOrId)
  end

  if options.proxy then
    local connect = require('websocket-client')
    local url = options.proxy
    coroutine.wrap(function ()
      log(4, "Connecting to proxy", url)
      local read, write, socket = assert(connect(url, "schema-rpc-tunnel"))
      log(4, "Listening for clients through proxy")
      proxyServer(read, write, socket, onConnection)
    end)()
  else
    require('weblit-websocket')
    require('weblit-app')
      .bind {
        host = options.host,
        port = options.port,
        tls = options.tls
      }
      .use(require('weblit-logger'))
      .use(require('weblit-auto-headers'))
      .websocket({
        path = "/",
        protocol = "schema-rpc"
      }, function (req, read, write)
        read, write = codec(read, write)
        return onConnection(read, write, req.socket)
      end)
      .start()
  end

end
