local connect = require('websocket-client')
local codec = require('websocket-to-message')
local makeRpc = require('rpc2')
local log = require('log').log
local makeCall = require('make-call')
local proxyClient = require('tunnel').client

-- options.url - the url we wish to connect to
-- HTTP basic auth
--   options.auth - username:password
-- Proxy support
--   options.proxy - true if going through rpc-routing-proxy node
-- Expose API
--   options.api - high level call wrapper
--   options.call(name, ...) - raw call function
--     1 - fatal - This message should always be shown and probably reported
--     2 - error - This is a real problem and should not be ignored
--     3 - warning - This is probably a problem, but maybe not.
--     4 - notice - This is for informational purposes only
--     5 - debug - This message is super chatty, but useful for debugging
-- returns the rpc handle
return function (options)
  if not options then options = {} end
  -- Use or generate call function for RPC integration
  local call = makeCall(options.call, options.api)

  local url = options.url
  assert(url, "Target url missing")

  -- TODO: embed auth data if found in options
  log(4, "Connecting to " .. (options.proxy and "proxy" or "agent"), url)
  local protocol = options.proxy and "schema-rpc-tunnel" or "schema-rpc"
  local read, write, socket = assert(connect(url, protocol))
  read, write = codec(read, write)

  if options.proxy then
    read, write = proxyClient(read, write)
  end

  return makeRpc(call, log, read, write), socket

end
