local codec = require('websocket-to-message')
local log = require('log').log
local makeChannel = require('channel')

local function proxyServer(read, write, socket, onConnection)
  local socketAddress = socket:getpeername()
  log(4, "Connecting to proxy", socketAddress)
  read, write = codec(read, write)
  local channels = {}
  local address = unpack(read())
  log(5, "Received local address", address)
  for message in read do
    if message[1] ~= address then
      log(3, "Unexpected message", message)
    elseif message[3] == true then
      local clientAddress = message[2]
      log(4, "New client connected", clientAddress)
      local channel = makeChannel()
      channels[clientAddress] = channel
      coroutine.wrap(function ()
        onConnection(channel.get, function (data)
          if not data then return write() end
          return write{clientAddress,address,unpack(data)}
        end, clientAddress)
      end)()
    elseif message[3] == false then
      local clientAddress = message[2]
      log(4, "client disconnected", clientAddress)
      write()
    else
      local clientAddress = message[2]
      local channel = channels[clientAddress]
      channel.put{table.unpack(message, 3)}
    end
  end
end

local function proxyClient(read, write)
  local from, to = unpack(read())
  return function ()
    while true do
      local message = read()
      if not message then return end
      if message[1] == from and message[2] == to then
        return {unpack(message, 3)}
      end
      log(3, "unexpected mesh message", message)
    end
  end, function (message)
    if not message then return write() end
    return write {to, from, unpack(message)}
  end
end

return {
  server = proxyServer,
  client = proxyClient,
}
