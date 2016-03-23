local connect = require('websocket-client')
local registry = require('types')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')
local log = require('log').log

-- config.aep
-- config.id
-- config.token
return function(config)

  -- In standalone mode we need to assign clients keys for rax commands.
  -- assert(register("key", "dummy key for direct connection", {
  -- }, {
  --   {"key", String}
  -- }, function () return '' end))

  local serverConfig = {
    host = config.ip,
    port = config.port,
    protocol = "schema-rpc",
  }

  local clients = setmetatable({}, {
    __mode = "k"
  })

  local keyToClient = setmetatable({}, {
    __mode = "v"
  })

  local url = "ws://" .. config.ip .. ":" .. config.port .. '/'
  log(4, "Creating local rpc server", url)
  log(5, "server config", serverConfig)
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
        if message[1] > 0 and message[2] == 'key' then
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
  end

  require('command-sock')(config.localSock, onCommand)

end
-- local function handleSocket(read, write)
--   print("Starting RPC protocol.")
--   api = makeRpc(registry.call, log, codec(read, write))
--   api.readLoop()
-- end
--
-- local function connect()
--   print("Connecting to AEP: " .. url)
--   local read, write = assert(wsConnect(
--     url ,
--     "schema-rpc",
--     {
--       tls = {ca = assert(loadResource("./../agent-cert/new.cert.cert"))}
--     }
--     ))
--   print("Connected!")
--   handleSocket(read, write)
--   print("Exiting!")
-- end
--
