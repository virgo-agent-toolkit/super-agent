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
  if module.docs then
    module.docs = upload(module.docs)
  end
  if module.dependencies then
    for i = 1, #module.dependencies do
      module.dependencies[i][2] = upload(module.dependencies[i][2])
    end
  end
  if module.assets then
    for i = 1, #module.assets do
      module.assets[i][2] = upload(module.assets[i][2])
    end
  end
  if module.tests then
    for i = 1, #module.tests do
      module.tests[i][2] = upload(module.tests[i][2])
    end
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
    name = "addem",
    description = "Adds two values together, even strings!",
    docs = [[
      This simple module lets you add two non-nil values together.
      If either one is detected to be a string, they will be concatenated.
    ]],
    code = [[
      return function (a, b)
        if type(a) == "string" or type(b) == "string" then
          return a .. b
        else
          return a + b
        end
      end
    ]],
    tests = {
      {"adds number", [[
        assert(self(1, 2) == 3)
      ]]},
      {"adds strings", [[
        assert(self("1", "2") == "12")
      ]]},
      {"adds mixed", [[
        assert(self("1", 2) == "12")
        assert(self(1, "2") == "12")
      ]]},
      {"nil should fail", [[
        assert(not pcall(self, nil, 42))
      ]]},
    },
    owners = { "tim@creationix.com" },
    tags = {"add", "concat"},
    license = "Public Domain"
  }
end)()


uv.run()
