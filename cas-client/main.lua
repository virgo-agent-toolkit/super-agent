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

-- module.file is a string that gets converted to a sha1
--

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

local function publish(module)
end

coroutine.wrap(function ()
  for i = 1, 10 do
    local hash = upload("Hello World: " .. i)
    local body = download(hash)
    p(hash, body)
  end
end)()


uv.run()
