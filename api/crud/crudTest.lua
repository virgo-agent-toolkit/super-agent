local registry = require 'registry'
local functions = registry.functions
local aliases = registry.aliases

-- should register the API modules
local aep = require './aep'
local getUUID = require('uuid4').getUUID

--p(registry.functions)
p(registry.call("aep.read", {'e108612e-7ade-41e8-80c6-f8da2681572c'}))

-- functions.aep[read]('e108612e-7ade-41e8-80c6-f8da2681572c')

-- registry.functions.foo(...) to call one of the functions
-- registry.call("foo", {...}) -- gives a nice error message if it doesn't work
