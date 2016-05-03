local p = require('pretty-print').prettyPrint
local codec = require('websocket-to-message')

--[[
 - Agents have a name/uuid that allows client to request them.  This works
   similar to the DNS system used to resolve domain names to IP addresses.
 - When an agent connects to a proxy, it declared it's name and is assigned an
   address on the local network. (star topology with proxy server in center)
 - When a client connects to a proxy, it requests an agent by name/uuid.  The
   proxy then assigns a local address to the client and tells it the address of
   the requested agent.
 - Every message in the system is prefixed with dest/source so that the proxy
   knows where to route messages.
 - An empty message is sent or synthesized when a connection is broken.  So if
   an agent dies or looses it's connection with the proxy, the proxy will send
   empty messages to all clients who were interested in that agent as if they
   came from the agent.

This means we need the following mappings in a proxy:
]]
-- Agent name/uuid -> agent address
local agentAddresses = {}
-- agent address -> list of client addresses
local clientLists = {}
-- client address -> agent address
local clientTargets = {}
-- address -> write function
local writeFunctions = {}

-- This is used to store a write function at a unique slot
local nextAddress = 1
local function allocateAddress(write, agentName, isAgent)
  while writeFunctions[nextAddress] do
    nextAddress = nextAddress + 1
  end
  local address = nextAddress
  writeFunctions[address] = write
  if isAgent then
    clientLists[address] = {}
    agentAddresses[agentName] = address
    return address, 0
  end
  local agentAddress = agentAddresses[agentName]
  clientTargets[address] = agentAddress
  clientLists[agentAddress][address] = true
  local agentWrite = writeFunctions[agentAddress]
  agentWrite {agentAddress,address,true}
  return address, agentAddress
end

local function freeAddress(address, agentName, isAgent)
  if isAgent then
    agentAddresses[agentName] = nil
    for client in pairs(clientLists[address]) do
      local clientWrite = writeFunctions[client]
      if clientWrite then
        clientWrite{client,address,false}
        clientWrite()
      end
    end
    clientLists[address] = nil
  else
    local agent = clientTargets[address]
    local agentWrite = writeFunctions[agent]
    if agentWrite then
      agentWrite{agent,address,false}
    end
    clientTargets[address] = nil
  end
  writeFunctions[address] = nil
end

local floor = math.floor
local function isInteger(num)
  return type(num) == "number" and floor(num) == num
end

local function routeMessage(message)
  assert(type(message) == "table", "Invalid message format, expected list")
  local to = message[1]
  assert(isInteger(to), "To field must be integer")
  local from = message[2]
  assert(isInteger(from), "From field must be integer")
  local write = assert(writeFunctions[to], "No such target")
  write(message)
end


local function handle(read, write, socket, agentName, isAgent)
  local socketAddress = socket:getpeername()
  p("CONNECT", {isAgent=isAgent,net=socketAddress})
  read, write = codec(read, write)
  local address, target = allocateAddress(write, agentName, isAgent)
  write {address, target}
  for message in read do
    local success, err = pcall(routeMessage, message)
    if not success then
      write {nil, err}
      break
    end
  end
  freeAddress(address, agentName, isAgent)
  p("DISCONNECT", {isAgent=isAgent,net=socketAddress})
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
    return handle(read, write, req.socket, req.params.uuid, false)
  end)

  .websocket({
    path = "/enlist/:uuid",
    protocol = "schema-rpc",
  }, function (req, read, write)
    return handle(read, write, req.socket, req.params.uuid, true)
  end)

  .start()
