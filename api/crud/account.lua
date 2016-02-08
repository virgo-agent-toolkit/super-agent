local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("account.")
local alias = registry.alias

local account = alias("account", {id=Uuid, name=String},
  "This alias is for existing account entries that have an ID.")

local accountWithoutId = alias("accountWithoutId", {name=String},
  "This alias creates a new account")

local updateAccountName = alias("updateAccountName", {id=Uuid, name=String},
  "This alias updates a particular account to have a new name")

local deleteAccount = alias("deleteAccount", {id=Uuid},
  "This alias delets an account with a particular uuid")

local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")


-- create({description}})
-- update({uuid,name})
-- delete(uuid)
-- query({pattern}, {limit,offset})

assert(register("create", [[

This function creates a new account entry in the database.
It will return the randomly generated UUID of the account.
]], {{"accountWithoutId", accountWithoutId}}, Uuid, function (account)
  local id = getUUID()
  local result = psqlQuery(
    string.format("INSERT INTO account ('id', 'name') VALUES ('%s', '%s')",
      id,
      account['name']))
  if not result then
    error('Create account failed: '..result[2])
  end
  return id
end))


assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Account, function (id)
  local id = getUUID()
  local result = psqlQuery(
    string.format("SELECT id, name FROM account WHERE id='%s'",
      id))
  if not result then
    error('Create account failed: '..result[2])
  end
  return result
end))

assert(register("update", [[

TODO: document me

]], {{"account", Account}}, Uuid, function (account)
  local result = psqlQuery(
    string.format(
      "UPDATE TABLE SET id = '%s', name = '%s' FROM account WHERE id = '%s'",
      account['id'],
      account['hostname'],
      account['id']))
  if not result then
    error("Update account failed: ", result[2])
  end

  return id
end))

assert(register("delete", [[

Deletes an account with a particular id

]], {{"id", Uuid}}, Uuid, function (id)
  local result = psqlQuery(
    string.format(
      "DELETE FROM account WHERE id = '%s'",
      id))
  if not result then
    error("Create account failed: ", result[2])
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
