local p = require('pretty-print').prettyPrint

local codec = require('websocket-to-message')

local floor = math.floor
local function isInteger(num)
  return type(num) == "number" and floor(num) == num
end

-- The server is always ID 0
-- Connections are {write,socket} indexed by id
local connections = {}
local next_id = 1

-- Mapping from uuid to socket
local utos = setmetatable({}, {
  __mode = "v"
})

-- Mapping from socket to id
local stoi = setmetatable({}, {
  __mode = "k"
})

-- Mapping from agent sockets to client socket
local clients = setmetatable({}, {
  __mode = "k"
})

local function get_id()
  while connections[next_id] do
    next_id = next_id + 1
  end
  return next_id
end

local function route(message)
  assert(type(message) == "table", "Invalid message format, expected list")
  local to = message[1]
  assert(isInteger(to), "To field must be integer")
  local from = message[2]
  assert(isInteger(from), "From field must be integer")
  local connection = assert(connections[to], "No such target")
  local write = unpack(connection)
  write(message)
end

local function on_connection(target, read, write, socket)
  local id = get_id()
  if target == 0 then
    print("New agent: " .. id)
    p(socket:getpeername())
  else
    print("New client: " .. id .. "-" .. target)
    p(socket:getpeername())
  end
  stoi[socket] = id
  local connection = {write, socket}
  connections[id] = connection
  if target ~= 0 then
    local agent = assert(connections[target])
    clients[agent][connection] = id
  else
    clients[connection] = {}
  end
  write {id,target}
  for message in read do
    local success, err = pcall(route, message)
    if not success then
      write {nil, err}
      break
    end
  end
  if not socket:is_closing() then
    socket:close()
  end
  -- TODO: handle cleanup hooks registered with session
  connections[id] = nil
  local list = clients[connection]
  if list then
    for client, cid in pairs(list) do
      local cwrite = unpack(client)
      cwrite{cid,id}
      cwrite()
    end
  end
end

require('weblit-websocket')
require('weblit-app')

  .bind {
    port = 9000
  }

  .use(require('weblit-logger'))

  .use(require('weblit-auto-headers'))

  .websocket({
    path = "/agent/:uuid",
    protocol = "schema-rpc",
  }, function (req, read, write)
    local id = stoi[utos[req.params.uuid]]
    if not id then
      write {
        opcode = 1,
        payload = "No such agent: " .. req.params.uuid .. "\n"
      }
      write()
      return
    end
    read, write = codec(read, write)
    on_connection(id, read, write, req.socket)
  end)

  .websocket({
    path = "/enlist/:uuid",
    protocol = "schema-rpc",
  }, function (req, read, write)
    p(clients)
    local old = utos[req.params.uuid]
    if old then
      -- TODO: if the entry already exists, we should do something to prevent leaks.
      p("OLD!!!!", old)
    end
    utos[req.params.uuid] = req.socket
    read, write = codec(read, write)
    on_connection(0, read, write, req.socket)
  end)

  .start()
