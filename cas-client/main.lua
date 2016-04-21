local success, luvi = pcall(require, 'luvi')
if success then
  loadstring(luvi.bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
else
  dofile('luvit-loader.lua')
end
local uv = require('uv')
local sha1 = require('sha1')
local msgpack = require('msgpack')


-- module.file is a string that gets converted to a sha1
--

local function upload(data) --> sha1 hash
end

local function publish(module)
end


uv.run()
