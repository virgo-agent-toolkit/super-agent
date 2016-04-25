local success, luvi = pcall(require, 'luvi')
if success then
  loadstring(luvi.bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
else
  dofile('luvit-loader.lua')
end
local uv = require('uv')
local sha1 = require('sha1')
local msgpack = require('msgpack')
local p = require('pretty-print').prettyPrint
local request = require('coro-http').request

local function upload(data) --> sha1 hash
  local hash = sha1(data)
  local res, body = assert(request("PUT", "https://cas.luvit.io/" .. hash, {}, data))
  if res.code < 200 or res.code >= 300 then
    p(res, body)
    error("Invalid HTTP response code from CAS server: " .. res.code)
  end
  return hash
end

local function download(hash) --> data
  local res, body = assert(request("GET", "https://cas.luvit.io/" .. hash))
  if res.code < 200 or res.code >= 300 then
    p(res, body)
    error("Invalid HTTP response code from CAS server: " .. res.code)
  end
  return body
end

-- module.file is a string that gets converted to a sha1
--
local function publish(module)
  if module.code then
    module.code = upload(module.code)
  end
  p(module)
  local encoded = msgpack.encode(module)
  local res, body = assert(request("POST", "https://cas.luvit.io/", {
    {"Content-Type", "application/msgpack"}
  }, encoded))
  if res.code == 500 then
    error(body)
  end
  p(res, body)

end

coroutine.wrap(function ()
  publish {
    code = [[
      return function (a, b)
        if type(a) == "string" then
          return a .. b
        else
          return a + b
        end
      end
    ]],
    name = "addem",
    description = "Adds two values together, even strings!",
    tags = {"add", "concat"},
  }
end)()


uv.run()
