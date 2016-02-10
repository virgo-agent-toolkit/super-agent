local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("agent.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID
local query = require('connection').query
local quote = require('sql-helpers').quote
local cleanQuery = require('sql-helpers').cleanQuery

local Agent = alias("Agent", {id=Uuid, name=String},
  "This alias is for existing agent entries that have an ID.")

local AgentWithoutId = alias("AgentWithoutId", {name=String},
  "This alias creates a new agent")

local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")


-- create({description}})
-- update({uuid,name})
-- delete(uuid)
-- query({pattern}, {limit,offset})

assert(register("create", [[

This function creates a new agent entry in the database.
It will return the randomly generated UUID of the agent.
]], {{"AgentWithoutId", AgentWithoutId}}, Uuid, function (agent)
  local id = getUUID()
  local result = assert(query(
    string.format("INSERT INTO agent ('id', 'name') VALUES ('%s', '%s')",
      quote(id),
      quote(agent['name']))))
  if result then
    return id
  end
  return result
end))


assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Agent, function (id)
  local result = assert(query(
    string.format("SELECT id, name FROM agent WHERE id='%s'",
      quote(id))))
  return result
end))

assert(register("update", [[

TODO: document me

]], {{"Agent", Agent}}, Uuid, function (agent)
  local result = assert(query(
    string.format(
      "UPDATE TABLE SET id = '%s', name = '%s' FROM account WHERE id = '%s'",
      quote(agent['id']),
      quote(agent['name']),
      quote(agent['id']))))
  if result then
    return agent['id']
  end

  return result
end))

assert(register("delete", [[

Deletes an agent with a particular id

]], {{"id", Uuid}}, Uuid, function (id)
  local result = assert(query(
    string.format(
      "DELETE FROM agent WHERE id = '%s'",
      quote(id))))
  if result then
    return id
  end

  return result
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
