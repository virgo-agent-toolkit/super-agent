local codec = require('websocket-to-message')
local makeRpc = require('rpc')

local severityTable = {
  "Fatal",
  "Error",
  "Warning",
  "Notice",
  "Debug"
}

return function (call)

  return function (req, read, write)
    local peer = req.socket:getpeername()
    local peerName = peer.ip .. ":" .. peer.port
    local userAgent = req.headers["user-agent"]
    if userAgent then
      peerName = peerName .. ' ' .. userAgent
    end
    print("UPGRADE " .. peerName)

    local function log(severity, ...)
      print(severityTable[severity], ...)
    end

    local rpc = makeRpc(call, log, codec(read, write))
    rpc.readLoop()

    print("DISCONNECT " .. peerName)

  end
end
