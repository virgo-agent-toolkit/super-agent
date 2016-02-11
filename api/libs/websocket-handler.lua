local p = require('pretty-print').prettyPrint
local codec = require('websocket-to-message')
local makeRpc = require('rpc')


return function (call)

  return function (req, read, write)
    local peer = req.socket:getpeername()
    local peerName = peer.ip .. ":" .. peer.port
    local userAgent = req.headers["user-agent"]
    if userAgent then
      peerName = peerName .. ' ' .. userAgent
    end
    print("UPGRADE " .. peerName)
    makeRpc(call, log, codec(read, write))

    print("DISCONNECT " .. peerName)

  end
end
