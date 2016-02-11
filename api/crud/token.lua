local getUUID = require('uuid4').getUUID

return function (db, registry)
  local alias = registry.alias
  local register = registry.register
  local Optional = registry.Optional
  local String = registry.String
  local Int = registry.Int
  local Bool = registry.Bool
  local Array = registry.Array
  local Uuid = registry.Uuid
  local query = db.query
  local quote = db.quote
  local parameterBuilder = db.parameterBuilder


local Token = alias("Token",
"This alias is for existing Token entries that has an ID.",
{id=Uuid, account_id=Uuid, description=String})

local TokenWithoutId = alias("TokenWithoutId",
"This alias is for creating new Token entries that don't have an ID yet",
{account_id=Uuid, description=String})

  local TokenQuery = alias("TokenQuery",
  "Structure for valid query parameters",
  {
      account_id = Optional(String),
      description = Optional(String),
      start = Optional(Int),
      count = Optional(Int),
    })

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
  return id
end))

assert(register("read", [[

TODO: document me

]], {{"id", Uuid}}, Token, function (id)
  local result = assert(query(
    string.format(
      "SELECT id, account_id, description FROM token WHERE id = '%s'",
      quote(id))))
  return result.rows and result.rows[1]
end))

assert(register("update", [[

TODO: document me

]], {{"Token", Token}}, Bool, function (token)
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
  local pattern = parameterBuilder({{tableName='account_id'}})

  local sql = 'SELECT id, account_id, description FROM aep '..
    pattern ..
    'LIMIT '..
    limit..
    ' OFFSET '..
    offset

  return assert(query(sql)).rows
end))
