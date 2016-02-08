local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("aep.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID

local psqlConnect = require('coro-postgres')
local getenv = require('os').getenv

local psqlQuery = psqlConnect.connect(
  {password=getenv("PASSWORD"),
  database=getenv("DATABASE")}).query


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
  local result = psqlQuery(
    string.format(
      "INSERT INTO aep ('id', 'hostname') VALUES ('%s', '%s')",
      id,
      aep['hostname']))
  if not result then
    error("Create aep failed: "..result[2])
  end
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Aep, function (id)
  local result = psqlQuery(
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
  local result = psqlQuery(
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
  local result = psqlQuery(
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
  {"query", Query},
  {"page", Page},
}, {
  Array(Aep),
  Page
}, function (query)
  -- TODO: Implement
end))
