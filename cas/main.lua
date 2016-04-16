local success, luvi = pcall(require, 'luvi')
if success then
  loadstring(luvi.bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
else
  dofile('luvit-loader.lua')
end

local connect = require('redis-client')
local p = require('pretty-print').prettyPrint
local sha1 = require('sha1')
local json = require('json')
local msgpack = require('msgpack')

local q
local function query(...)
  if not q then
    q = connect()
  end
  return q(...)
end

require('weblit-app')

  .use(require('weblit-logger'))
  .use(require('weblit-auto-headers'))
  .use(require('weblit-etag-cache'))

  .route({
    method = "GET",
    path = "/:hash"
  }, function (req, res)
    local data = query("get", req.params.hash)
    p("data", data)
    if not data then return end
    res.code = 200
    res.body = data
  end)

  .route({
    method = "POST",
    path = "/"
  }, function (req, res)
    local body = assert(req.body, "missing request body")
    local message
    local contentType = req.headers["Content-Type"]
    if contentType == "application/json" then
      message = assert(json.parse(body))
    elseif contentType == "application/msgpack" then
      message = assert(msgpack.decode(body))
    else
      message = assert(json.parse(body) or msgpack.decode(body), "Can't decode body")
    end

    p("message", message)
    local data = msgpack.encode(message)
    local key = sha1(data)
    res.body = query("set", key, data)
    res.code = 201
    res.headers["X-Key"] = key
  end)

  .start()

require('uv').run()
