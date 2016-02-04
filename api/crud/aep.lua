local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("aep.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID


local Aep = alias("Aep", {id=Uuid,hostname=String},
  "This alias is for existing AEP entries that have an ID.")

local AepWithoutId = alias("AepWithoutId", {hostname=String},
  "This alias is for creating new AEP entries that don't have an ID yet")

local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")

assert(register("create", [[

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

]], {{"aep", AepWithoutId}}, Uuid, function (aep)
  local id = getUUID()
  -- TODO: Implement
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Aep, function (id)
  -- TODO: Implement
end))

assert(register("update", [[

TODO: document me

]], {{"aep", Aep}}, Uuid, function (id)
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
  {"query", Query},
  {"page", Page},
}, {
  Array(Aep),
  Page
}, function (query)
  -- TODO: Implement
end))
