local sha1 = require('sha1')
local codec = require('websocket-to-message')
local log = require('log').log

return function (config)

  local host = config.ip == '0.0.0.0' and 'localhost' or config.ip
  local prefix = string.format("%s://%s:%d",
    config.tls and "wss" or "ws", host, config.port)

  local clientHandlers = {}

  local function getClientHandler(agent_id)
    local clientHandler = clientHandlers[agent_id]
    if clientHandler then return clientHandler end
    return nil, "No such agent: " .. agent_id
  end


  local function newAgent(agent_id, read, write, socket)
    local address = socket:getpeername()
    local agentUrl = prefix .. "/request/" .. agent_id
    log(4, "new agent", agentUrl, address)

    local nextId = 1
    local rmappings = {}
    local waiting = {}
    local cmappings = setmetatable({}, {
      __mode = "k"
    })
    local clients = setmetatable({}, {
      __mode = "v"
    })

    clientHandlers[agent_id] = function (cread, cwrite, csocket)
      local caddress = csocket:getpeername()
      log(4, "new client", agent_id, caddress)
      local key = sha1(caddress.ip .. '-' .. caddress.port)
      clients[key] = cwrite
      local mappings = {}

      local function mapRequest(id)
        local nid = mappings[id]
        if nid then return nid end
        nid = nextId
        nextId = nextId + 1
        mappings[id] = nid
        rmappings[nid] = id
        cmappings[nid] = cwrite
        return nid
      end

      local function recursiveMap(value)
        if type(value) ~= "table" then return value end
        if next(value) ~= '' or next(value, '') then
          for k, v in pairs(value) do
            value[k] = recursiveMap(v)
          end
          return value
        end
        local id = value['']
        if id == 0 then
          return key
        else
          value[''] = mapRequest(id)
        end
        return value
      end

      for message in cread do
        if type(message) ~= "table" or type(message[1]) ~= "number" then
          cwrite {0, "Invalid message"}
          break
        end
        if message[1] > 0 and message[2] == 'key' then
          cwrite({-message[1],key})
        else
          if message[1] > 0 then
            message[1] = mapRequest(message[1])
          end
          recursiveMap(message)
          write(message)
        end
      end
      cwrite()
      clients[key] = nil
      log(4, "client disconnect", agent_id, caddress)
    end

    for message in read do
      if type(message) ~= "table" or type(message[1]) ~= "number" then
        write {0, "Invalid message"}
        break
      end
      local id = message[1]
      if id < 0 then
        id = -id
        local rmap = rmappings[id]
        if rmap then
          message[1] = -rmap
          local cwrite = cmappings[id]
          cwrite(message)
        else
          local thread = waiting[id]
          if thread then
            waiting[id] = nil
            assert(coroutine.resume(thread, unpack(message, 2)))
          else
            print("Unknown response id: " .. id)
          end
        end
      elseif id == 0 then
        if message[2] then
          print(message[2])
        end
        break
      elseif id > 0 then
        log(4, 'message from cli', message)
        local key = message[2]
        local cwrite = clients[key]
        cwrite({id, unpack(message, 3)})
      end
    end
    write()
    log(4, "agent disconnect", agent_id, address)
    for key, cwrite in pairs(clients) do
      log(5, "disconnecting agent", key, cwrite)
      cwrite {0, "Agent disconnected"}
      cwrite()
    end
  end


  require('weblit-websocket')
  local app = require('weblit-app')

  app.bind {
    host = config.ip,
    port = config.port,
    tls = config.tls
  }

  app.use(require('weblit-logger'))
  app.use(require('weblit-auto-headers'))

  app.websocket({
    path = "/enlist/:agent_id/:token",
    protocol = "schema-rpc"
  }, function (req, read, write)
    local agent_id = req.params.agent_id
    -- TODO: authenticate agent to account using provided token
    read, write = codec(read, write)
    return newAgent(agent_id, read, write, req.socket)
  end)
  log(4, "agent endpoint", prefix .. "/enlist/:agent_id/:token")

  if config.users then
    app.use(require('basic-auth')(config.users))
  end

  app.websocket({
    path = "/request/:agent_id",
    protocol = "schema-rpc"
  }, function (req, read, write)
    local agent_id = req.params.agent_id
    local newClient = assert(getClientHandler(agent_id))
    read, write = codec(read, write)
    newClient(read, write, req.socket)
  end)
  log(4, "client endpoint", prefix .. "/request/:agent_id")

  if config.webroot then
    app.use(require('weblit-etag-cache'))
    app.use(require('weblit-static')(config.webroot))
  end

  app.start()


end
