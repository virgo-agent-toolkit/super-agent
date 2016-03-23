local success, luvi = pcall(require, 'luvi')
if success then
  loadstring(luvi.bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
else
  dofile('luvit-loader.lua')
end

local uv = require('uv')
local msgpackEncode = require('msgpack').encode
local msgpackDecode = require('msgpack').decode
local connect = require('coro-net').connect
local pathJoin = require('pathjoin').pathJoin
local getenv = require('os').getenv
local fs = require('coro-fs')
local cwd = require('uv').cwd()
local function resolve(path)
  return pathJoin(cwd, path)
end
require('log').level = 4

local localSock = {
  path = "/tmp/rax.sock"
  -- host = "127.0.0.1",
  -- port = 2325
}
local meta = require('./package')
local key = getenv('RAX_CLIENT_KEY')
local args = table.pack(...)
local log = require('log').log

print(string.format("%s v%s", meta.name, meta.version))
coroutine.wrap(function ()

  -- Command mode when running inside agent pty session.
  if key then
    if key == '' then
      log(5, 'Rax pty session in standalone agent detected')
    else
      log(5, 'Rax pty session proxied for client ' .. key .. ' detected')
    end
    -- Running as client helper inside pty session
    if not args[1] then
      print("\nUsage:\n\trax command ...args")
      os.exit(-1)
    end
    log(4, "Connecting to local agent", localSock)
    local _, write = assert(connect(localSock))
    log(4, "Sending '" .. args[1] .. "' command to client...")
    for i = 2, args.n do
      if args[i]:sub(1,1) ~= "-" then
        args[i] = resolve(args[i])
      end
    end
    local message = {key, unpack(args)}
    log(5, "message", unpack(message))
    write((msgpackEncode(message)))
    write()
    os.exit(0)
  end

  -- Agent mode when running outside in normal environment.
  do
    -- Make sure the agent isn't already running
    do
      local read, write = connect(localSock)
      if read then
        local data = ""
        for chunk in read do
          data = data .. chunk
        end
        local pid = msgpackDecode(data)
        log(1, "Agent already running at pid", pid)
        write()
        os.exit(-7)
      end
    end

    -- Load rax config
    local config = {}
    do
      local configFile
      local lua
      log(4, 'RAX daemon mode detected.')
      if args[1] then
        configFile = resolve(args[1])
        lua = fs.readFile(configFile)
        if not lua then
          log(3, 'No such file', configFile)
        end
      else
        configFile = resolve('rax.conf')
        lua = fs.readFile(configFile)
        if not lua then
          configFile = '/etc/rax.conf'
          lua = fs.readFile(configFile)
        end
        if not lua then
          log(3, "Cannot file rax.conf in " .. cwd .. " or /etc/")
        end
      end
      if not lua then
        print("\nUsage:\n\trax path/to/rax.conf")
        os.exit(-2)
      end
      log(5, 'Loading config file', configFile)
      local fn, err = loadstring(lua, configFile)
      if not fn then
        log(1, err)
        os.exit(-3)
      end
      _G.setfenv(fn, config)
      fn()
      config.localSock = localSock
    end

    -- Switch behavior based on the mode in the config file
    local mode = config.mode
    if mode == "standalone" then
      if not (type(config.ip) == 'string' and type(config.port) == 'number') then
        log(1, "Standalone mode config requires string for ip and number for port.")
        os.exit(-4)
      end
      if config.ip ~= "127.0.0.1" then
        if not config.users then
          log(3, "listening on public port, but no user authentication!")
        end
        if not config.tls then
          log(3, "listening on public port, but no tls encryption!")
        end
      end
      require('standalone')(config)
    elseif mode == "remote" then
      if not (type(config.proxy) == 'string' and
              type(config.id) == 'string' and
              type(config.token) == 'string') then
        log(1, "Remote mode config requires proxy, id, and token string fields.")
        os.exit(-5)
      end
      require('remote')(config)
    elseif mode == "proxy" then
      if not (type(config.ip == 'string') and
              type(config.port == 'number')) then
        log(1, "Proxy mode config requires ip and port fields.")
        os.exit(-5)
      end
      require('proxy')(config)
    else
      log(1, "config.mode must be one of 'standalone', 'proxy', or 'remote'.")
      os.exit(-4)
    end
  end

end)()

uv.run()
