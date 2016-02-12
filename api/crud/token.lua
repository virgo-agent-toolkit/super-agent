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
  local conditionBuilder = db.conditionBuilder

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
    assert(query(
      string.format(
        "INSERT INTO token (id, account_id, description) VALUES (%s, %s, %s)",
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
        "SELECT id, account_id, description FROM token WHERE id = %s",
        quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  TODO: document me

  ]], {{"Token", Token}}, Bool, function (token)

    local result = assert(query(
      string.format(
        "UPDATE token SET account_id = %s, description = %s WHERE id = %s",
        quote(token['account_id']),
        quote(token['description']),
        quote(token['id']))))

    return result.summary == 'UPDATE 1'
  end))

  assert(register("delete", [[

  TODO: document me

  ]], {{"id", Uuid}}, Bool, function (id)
    local result = assert(query(
      string.format(
        "DELETE FROM token WHERE id = %s",
        quote(id))))

    return result.summary == 'DELETE 1'
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
    local where = conditionBuilder(
      'account_id', queryParameters.account_id,
      'description', queryParameters.description
    )
    local sql = 'SELECT id, account_id, description FROM token' .. where ..
      ' LIMIT ' .. limit ..
      ' OFFSET ' .. offset
    -- TODO: change to return total rows as well like other APIs
    return assert(query(sql)).rows
  end))
end
