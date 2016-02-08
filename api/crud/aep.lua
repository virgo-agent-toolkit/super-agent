local schema = require 'schema'
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("aep.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID
local query = require('connection').query
local quote = require('sql-helpers').quote


local Aep = alias("Aep", {id=Uuid,hostname=String},
  "This alias is for existing AEP entries that have an ID.")

local AepWithoutId = alias("AepWithoutId", {hostname=String},
  "This alias is for creating new AEP entries that don't have an ID yet")

local AepQuery = alias("AepQuery", {pattern=String},
    "Structure for valid query parameters")

local Page = require('shared-types').Page

assert(register("create", [[

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

]], {{"aep", AepWithoutId}}, Uuid, function (aep)
  local id = getUUID()
  assert(query(
    string.format(
      "INSERT INTO aep (id, hostname) VALUES (%s, %s)",
      quote(id),
      quote(aep['hostname']))))
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Aep, function (id)
  local result = query(
    string.format(
      "SELECT id, hostname FROM aep WHERE id = '%s'",
      id))
  if not result then
    error("Read aep information failed: ", result[2])
  end
  return {id='e108612e-7ade-41e8-80c6-f8da2681572c', hostname='something'}
end))

assert(register("update", [[

TODO: document me

]], {{"aep", Aep}}, Uuid, function (aep)
  local result = query(
    string.format(
      "UPDATE TABLE SET id = '%s', hostname = '%s' FROM aep WHERE id = '%s'",
      aep['id'],
      aep['hostname'],
      aep['id']))
  if not result then
    error("Update aep failed: ", result[2])
  end
end))

assert(register("delete", [[

TODO: document me

]], {{"id", Uuid}}, Uuid, function (id)
  local result = query(
    string.format(
      "DELETE FROM aep WHERE id = '%s'",
      id))
  if not result then
    error("Create aep failed: ", result[2])
  end
end))

assert(register("query", [[

TODO: document me

]], {
  {"query", AepQuery},
  {"page", Page},
}, {
  Array(Aep),
  Page
}, function (query)
  -- TODO: Implement
end))
