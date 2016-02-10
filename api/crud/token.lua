local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local Optional = schema.Optional
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("token.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID
local query = require('connection').query
local quote = require('sql-helpers').quote
local cleanQuery = require('sql-helpers').cleanQuery


local Token = alias("Token", {id=Uuid, account_id=Uuid, description=String},
  "This alias is for existing Token entries that has an ID.")

local TokenWithoutId = alias("TokenWithoutId", {account_id=Uuid, description=String},
  "This alias is for creating new Token entries that don't have an ID yet")

  local TokenQuery = alias("AepQuery", {
      account_id = Optional(String),
      description = Optional(String),
      start = Optional(Int),
      count = Optional(Int),
    },
    "Structure for valid query parameters")
assert(register("create", [[

This function creates a new token entry in the database associated with a
  particular users account.  It will return the randomly generated UUID.

]], {{"TokenWithoutId", TokenWithoutId}}, Uuid, function (token)
  local id = getUUID()
  local result = assert(query(
    string.format(
      "INSERT INTO token ('id', 'account_id', 'description') VALUES ('%s', '%s', '%s')",
      quote(id),
      quote(token['account_id']),
      quote(token['description']))))
  if result then
    return id
  end
  return result
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Token, function (id)
  local result = assert(query(
    string.format(
      "SELECT id, account_id, description FROM token WHERE id = '%s'",
      quote(id))))
  return result
end))

assert(register("update", [[

TODO: document me

]], {{"Token", Token}}, Uuid, function (token)
  local result = assert(query(
    string.format(
      "UPDATE TABLE SET id = '%s', account_id = '%s', description = '%s' FROM token WHERE id = '%s'",
      quote(token['id']),
      quote(token['account_id']),
      quote(token['hostname']),
      quote(token['id']))))
  if result then
    return token['id']
  end
  return result
end))

assert(register("delete", [[

TODO: document me

]], {{"id", Uuid}}, Uuid, function (id)
  local result = assert(query(
    string.format(
      "DELETE FROM token WHERE id = '%s'",
      quote(id))))
  if result then
    return id
  end

  return result
end))

assert(register("query", [[

TODO: document me

]], {
  {'query', TokenQuery}
}, {
  Array(Token),
}, function (queryParameters)
  local offset = queryParameters.start or 0
  local limit = queryParameters.count or 20
  local pattern

  if queryParameters.account_id or queryParameters.description then
    pattern = 'WHERE '

    if queryParameters.account_id then
      pattern = pattern ..('account_id LIKE '..cleanQuery(queryParameters.account_id)..' ')
    end
    if queryParameters.account_id and queryParameters.description then
      pattern = pattern..'AND '
    end
    if queryParameters.description then
      pattern = pattern .. 'description LIKE '..cleanQuery(queryParameters.description)
    end

  end
  local sql = 'SELECT id, account_id, description FROM aep '..
    pattern ..
    'LIMIT '..
    limit..
    ' OFFSET '..
    offset

  return assert(query(sql))
end))
