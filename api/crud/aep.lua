local schema = require 'schema'
local String = schema.String
local Int = schema.Int
local Array = schema.Array
local Optional = schema.Optional
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("aep.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID
local query = require('connection').query
local quote = require('sql-helpers').quote
local cleanQuery = require('sql-helpers').cleanQuery

local Aep = alias("Aep", {id=Uuid,hostname=String},
  "This alias is for existing AEP entries that have an ID.")

local AepWithoutId = alias("AepWithoutId", {hostname=String},
  "This alias is for creating new AEP entries that don't have an ID yet")

local AepQuery = alias("AepQuery", {
    hostname = Optional(String),
    start = Optional(Int),
    count = Optional(Int),
  },
  "Structure for valid query parameters")

assert(register("create", [[

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

]], {{"aep", AepWithoutId}}, Uuid, function (aep)
  local id = getUUID()
  local result = assert(query(
    string.format(
      "INSERT INTO aep (id, hostname) VALUES (%s, %s)",
      quote(id),
      quote(aep['hostname']))))
  if result then
    return id
  end
  return result
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Aep, function (id)
  local result = assert(query(
    string.format(
      "SELECT id, hostname FROM aep WHERE id = '%s'",
      quote(id))))
  return result
end))

assert(register("update", [[

TODO: document me

]], {{"aep", Aep}}, Uuid, function (aep)
  local result = assert(query(
    string.format(
      "UPDATE TABLE SET id = %s, hostname = %s FROM aep WHERE id = %s",
      quote(aep['id']),
      quote(aep['hostname']),
      quote(aep['id']))))

  if result then
    return aep['id']
  end

  return result
end))

assert(register("delete", [[

TODO: document me

]], {{"id", Uuid}}, Uuid, function (id)
  local result = assert(query(
    string.format(
      "DELETE FROM aep WHERE id = '%s'",
      id)))
  if result then
    return id
  end

  return result
end))

assert(register("query", [[

Query for existing AEP rows

]], { {"query", AepQuery} }, Array(Aep), function (queryParameters)
  local offset = queryParameters.start or 0
  local limit = queryParameters.count or 20
  local pattern
  if not queryParameters.query then
    pattern = ''
  else
    pattern = ('WHERE hostname LIKE '..cleanQuery(queryParameters.query)..' ')
  end
  local sql = 'SELECT id, hostname FROM aep '..
    pattern ..
    'LIMIT '..
    limit..
    ' OFFSET '..
    offset

  return assert(query(sql))
end))
