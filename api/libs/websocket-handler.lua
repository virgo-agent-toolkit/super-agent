local jsonDecode = require('json').parse
local jsonEncode = require('json').stringify
local msgpackDecode = require('msgpack').decode
local msgpackEncode = require('msgpack').encode
local p = require('pretty-print').prettyPrint

local function isArray(value)
  if type(value) ~= "table" then return end
  local i = 1
  for k in pairs(value) do
    if i ~= k then return end
    i = i + 1
  end
  return true
end

return function (call)
  -- Incoming requests are in the form:
  -- [id, name, args...]
  -- Outgoing responses are in the form:
  -- [-id, result]
  -- Outgoing stream chunks are in the form:
  -- [sid, chunk]
  -- Incoming stream chunks are in the form:
  -- [-sid, chunk]
  -- errors are in the format:
  -- [0, err, (s)id?]
  local function handleMessage(message, send, peerName)
    local id = message[1]
    if type(id) ~= "number" then
      return send(0, "Invalid message format")
    end
    if id == 0 then
      return p("Error message", unpack(message))
    end
    if id > 0 then
      local name = message[2]
      if type(name) ~= "string" then
        return send(0, "Request name must be string", id)
      end
      print("REQUEST " .. name .. " " .. peerName)
      local args = {}
      for i = 3, #message do
        args[i - 2] = message[i]
      end
      local result, err = call(name, args)
      if not err then
        return send(-id, result)
      end
      return send(0, err, id)
    end
    error("TODO: handle stream packets from client")
  end


  return function (req, read, write)
    local peer = req.socket:getpeername()
    local peerName = peer.ip .. ":" .. peer.port
    local userAgent = req.headers["user-agent"]
    if userAgent then
      peerName = peerName .. ' ' .. userAgent
    end
    print("UPGRADE " .. peerName)
    local encode = jsonEncode
    local function send(...)
      return write {
        opcode = encode == jsonEncode and 1 or 2,
        payload = encode {...}
      }
    end

    for frame in read do
      local message
      if frame.opcode == 1 then
        message = jsonDecode(frame.payload)
        encode = jsonEncode
      elseif frame.opcode == 2 then
        message = msgpackDecode(frame.payload)
        encode = msgpackEncode
      else
        send(0, "Unexpected frame type: " .. frame.opcode)
      end
      if message then
        if isArray(message) then
          handleMessage(message, send, peerName)
        else
          send(0, "Invalid message format")
        end
      end
    end
    write()
    print("DISCONNECT " .. peerName)

  end
end
