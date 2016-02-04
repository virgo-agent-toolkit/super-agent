local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.register("aep.")
local getUUID = require('uuid4').getUUID

assert(register("create", [[

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

]], {{"aep", {hostname=String}}}, Uuid, function (aep)
  local id = getUUID()
  -- TODO: Implement
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, {id=Uuid,hostname=String}, function (id)
  -- TODO: Implement
end))

assert(register("update", [[

TODO: document me

]], {{"aep", {id=Uuid,hostname=String}}}, Uuid, function (id)
  -- TODO: Implement
end))

assert(register("delete", [[

TODO: document me

]], {{"id", Uuid}}, Uuid, function (id)
  -- TODO: Implement
end))

assert(register("query", [[

TODO: document me

]], {
  {"query", {pattern=String,limit=Int,offset=Int}}
}, {
  results = Array({id = Uuid, hostname = String}),
  limit = Int,
  offset = Int,
}, function (query)
  -- TODO: Implement
end))
