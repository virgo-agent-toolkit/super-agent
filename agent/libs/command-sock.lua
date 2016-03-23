local uv = require('uv')
local msgpackDecode = require('msgpack').decode
local msgpackEncode = require('msgpack').encode
local createServer = require('coro-net').createServer
local fs = require('coro-fs')
local log = require('log').log

return function (localSock, onCommand)
  if localSock.path then
    fs.unlink(localSock.path)
  end
  log(4, "listening on local socket for cli clients", localSock)
  local server = assert(createServer(localSock, function (read, write)
    write(msgpackEncode(uv.getpid()))
    write()
    local data = ""
    for chunk in read do
      data = data .. chunk
    end
    if #data > 0 then
      local message = msgpackDecode(data)
      onCommand(unpack(message))
    end
  end))
  -- Don't hold the event loop open for just this socket
  server:unref()
end
