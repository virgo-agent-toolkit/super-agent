local createServer = require('websocket-server')
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

  local serverConfig = {
    host = config.ip,
    port = config.port,
    users = config.users,
    tls = config.tls,
    protocol = "schema-rpc",
  }

  local clients = setmetatable({}, {
    __mode = "k"
  })

  local keyToClient = setmetatable({}, {
    __mode = "v"
  })

  local url = (config.tls and "wss" or "ws") .. "://" .. config.ip .. ":" .. config.port .. '/'
  log(4, "Creating local rpc server", url)
  createServer(serverConfig, function (read, write, socket)
    local addr = socket:getpeername()
    local key = sha1(addr.ip .. ':' .. addr.port)
    keyToClient[key] = socket
    log(4, "new client", addr)
    print("Starting RPC protocol.")
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
    local api = makeRpc(registry.call, log, wrappedRead, write)
    clients[socket] = api;
    api.readLoop()
    log(4, "client disconnected", socket:getpeername())
    if not socket:is_closing() then socket:close() end
  end)

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

end
