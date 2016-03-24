local createServer = require('coro-net').createServer
local websocketCodec = require('websocket-codec')
local wrapIo = require('coro-websocket').wrapIo
local httpCodec = require('http-codec')
local base64Decode = require('base64').decode
local sha1 = require('sha1')

return function (options, onConnection)
  options.encode = httpCodec.encoder()
  options.decode = httpCodec.decoder()
  createServer(options, function (read, write, socket, updateDecoder, updateEncoder)
    local function abort(message)
      write {
        code = 400,
        {"Content-Length", #message},
        {"Content-Type", "text/plain"},
      }
      write(message)
      return write()
    end
    local req = read()
    if not req then
      return write()
    end
    -- look for GET request
    -- with 'Upgrade: websocket'
    -- and 'Connection: Upgrade' headers
    local headers = {}
    for i = 1, #req do
      local key, value = unpack(req[i])
      headers[key:lower()] = value
    end

    -- If there is a list of authorized users, check them using HTTP Basic Auth
    local users = options.users
    if users then
      local authed = false
      local auth = headers.authorization
      if auth then
        local plain = base64Decode(auth:match("Basic ([^ ]*)"))
        for i = 1, #users do
          local type, value = users[i]:match("^([^:]*):(.*)$")
          if (type == "plain" and value == plain) or
             (type == "sha1" and value == sha1(plain)) then
            authed = true
            break
          end
        end
      end
      if not authed then
        local message = "Please enter valid username/password\n"
        write {
          code = 401,
          {"WWW-Authenticate", 'Basic realm="RAX Agent"'},
          {"Content-Length", #message},
        }
        write(message)
        return
      end
    end

    local connection = headers.connection
    local upgrade = headers.upgrade
    if not (
      req.method == "GET" and
      upgrade and upgrade:lower():find("websocket", 1, true) and
      connection and connection:lower():find("upgrade", 1, true)
    ) then
      return abort "Wesocket only\n"
    end

    -- If there is a sub-protocol specified, filter on it.
    local protocol = options.protocol
    if protocol then
      local list = headers["sec-websocket-protocol"]
      local foundProtocol
      if list then
        for item in list:gmatch("[^, ]+") do
          if item == protocol then
            foundProtocol = true
            break
          end
        end
      end
      if not foundProtocol then
        return abort("Only " .. protocol .. " subprotocol allowed\n")
      end
    end

    -- Make sure it's a new client speaking v13 of the protocol
    if tonumber(headers["sec-websocket-version"]) < 13 then
      return abort "sec-websocket-version >= 13 required\n"
    end

    -- Get the security key
    local key = headers["sec-websocket-key"]
    if not key then
      return abort "sec-websocket-key required\n"
    end

    local res = {
      code = 101,
      {"Upgrade", "websocket"},
      {"Connection", "Upgrade"},
      {"Sec-WebSocket-Accept", (websocketCodec.acceptKey(key))}
    }
    if protocol then
      res[#res + 1] = {"Sec-WebSocket-Protocol", protocol}
    end

    for chunk in read do
      if #chunk == 0 then break end
    end

    write(res)
    updateDecoder(websocketCodec.decode)
    updateEncoder(websocketCodec.encode)
    read, write = wrapIo(read, write, {
      mask = false,
      heartbeat = options.heartbeat
    })
    onConnection(read, write, socket)
  end)
end
