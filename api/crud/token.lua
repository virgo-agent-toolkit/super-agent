local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("token.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID

local psqlConnect = require('coro-postgres')
local getenv = require('os').getenv

local psqlQuery = psqlConnect.connect(
  {password=getenv("PASSWORD"),
  database=getenv("DATABASE")}).query


local Token = alias("Token", {id=Uuid, account_id=Uuid, description=String},
  "This alias is for existing Token entries that has an ID.")

local TokenWithoutId = alias("TokenWithoutId", {account_id=Uuid, description=String},
  "This alias is for creating new Token entries that don't have an ID yet")

local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")

assert(register("create", [[

This function creates a new token entry in the database associated with a
  particular users account.  It will return the randomly generated UUID.

]], {{"TokenWithoutId", TokenWithoutId}}, Uuid, function (token)
  local id = getUUID()
  local result = psqlQuery(
    string.format(
      "INSERT INTO token ('id', 'account_id', 'description') VALUES ('%s', '%s', '%s')",
      id,
      token['account_id'],
      token['description']))
  if not result then
    error("Create token failed: "..result[2])
  end
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Token, function (id)
  local result = psqlQuery(
    string.format(
      "SELECT id, account_id, description FROM token WHERE id = '%s'",
      id))
  if not result then
    error("Read token information failed: ", result[2])
  end
  return result
end))

assert(register("update", [[

TODO: document me

]], {{"Token", Token}}, Uuid, function (token)
  local result = psqlQuery(
    string.format(
      "UPDATE TABLE SET id = '%s', account_id = '%s', description = '%s' FROM token WHERE id = '%s'",
      token['id'],
      token['account_id'],
      token['hostname'],
      token['id']))
  if not result then
    error("Update token failed: ", result[2])
  end
  return token['id']
end))

assert(register("delete", [[

TODO: document me

]], {{"id", Uuid}}, Uuid, function (id)
  local result = psqlQuery(
    string.format(
      "DELETE FROM token WHERE id = '%s'",
      id))
  if not result then
    error("Create token failed: ", result[2])
  end

  return id
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
