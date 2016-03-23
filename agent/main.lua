local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
local msgpackEncode = require('msgpack').encode
local connect = require('coro-net').connect
local pathJoin = require('pathjoin').pathJoin
local getenv = require('os').getenv

local cwd = require('uv').cwd()
local function resolve(path)
  return pathJoin(cwd, path)
end


local function parseArgs(command, ...)
  if not command then
    print "Usage:"
    print "\trax command [args...]"
    os.exit(-1)
  end
  if command == "connect" then
    return require('daemon')(false, ...)
  end
  if command == "serve" then
    return require('daemon')(true, ...)
  end
  local args = table.pack(...)
  for i = 1, args.n do
    if args[i]:sub(1,1) ~= "-" then
      args[i] = resolve(args[i])
    end
  end
  coroutine.wrap(function ()
    local key = getenv("RAX_CLIENT_KEY")
    print("Sending '" .. command .. "' command to client")
    local _, write = assert(connect({
      host = "127.0.0.1",
      port = 13377,
    }))
    write(msgpackEncode{key, command, unpack(args)})
  end)()
end

parseArgs(...)


require('uv').run()
