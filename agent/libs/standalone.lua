local registry = require('types')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')
local log = require('log').log
local sha1 = require('sha1')

-- This is a simple unauthenticated standalone agent
-- It typically listens on 127.0.0.1 and clients can connect
-- directly to it without the aide of an AEP.
--
-- config.ip - the local interface to bind to
-- config.port - the local port to listen on
return function(config)

  require('weblit-websocket')
  local app = require('weblit-app')

  app.bind {
    host = config.ip,
    port = config.port,
    tls = config.tls
  }

  app.use(require('weblit-logger'))
  app.use(require('weblit-auto-headers'))

  if config.users then
    app.use(require('basic-auth')(config.users))
  end

  local clients = setmetatable({}, {
    __mode = "k"
  })

  local keyToClient = setmetatable({}, {
    __mode = "v"
  })

  local url = (config.tls and "wss" or "ws") .. "://" .. config.ip .. ":" .. config.port .. '/'
  log(4, "Creating local rpc server", url)

  app.websocket({
    path = "/",
    protocol = "schema-rpc",
  }, function (req, read, write)
    local socket = req.socket
    local addr = socket:getpeername()
    local key = sha1(addr.ip .. ':' .. addr.port)
    keyToClient[key] = socket
    log(4, "new client", addr)
    read, write = codec(read, write)
    local function wrappedRead()
      while true do
        local message = read()
        if message and #message == 2 and message[1] > 0 and message[2] == 'key' then
          write{-message[1], key}
        else
          return message
        end
      end
    end
    local readLoop, callRemote, close = makeRpc(registry.call, log, wrappedRead, write)
    local api = {
      readLoop = readLoop,
      call = callRemote,
      close = close
    }
    clients[socket] = api;
    api.readLoop()
    log(4, "client disconnected", addr)
    if not socket:is_closing() then socket:close() end
  end)

  if config.webroot then
    app.use(require('weblit-etag-cache'))
    app.use(require('weblit-static')(config.webroot))
  end

  local function onCommand(key, command, ...)
    log(5, "got command", key, command, ...)
    local socket = keyToClient[key]
    if not socket then
      log(2, "No such client key", key)
      return
    end
    local api = clients[socket]
    if not api then
      log(2, "Client missing API", socket)
      return
    end
    api.call(command, ...)
  end

  require('command-sock')(config.localSock, onCommand)

  app.start()

end
