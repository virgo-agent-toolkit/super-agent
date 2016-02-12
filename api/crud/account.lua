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

  local Row = alias("Row",
    "This alias is for existing Account entries that have an ID.",
    {id=Uuid,name=String})

  local RowWithoutId = alias("RowWithoutId",
    "This alias is for creating new Account entries that don't have an ID yet",
    {name=String})

  local Query = alias("Query",
    "Structure for valid query parameters",
    {
      name = Optional(String),
      start = Optional(Int),
      count = Optional(Int),
    })

  assert(register("create", [[

  This function creates a new Account entry in the database.  It will return
  the randomly generated UUID so you can reference the Account.

  ]], {{"row", RowWithoutId}}, Uuid, function (row)
    local id = getUUID()
    assert(query(string.format(
      "INSERT INTO account (id, name) VALUES (%s, %s)",
      quote(id),
      quote(row['name']))))
    return id
  end))

  assert(register("read", [[

  Given a UUID, return the corresponding row.

  ]], {{"id", Uuid}}, Optional(Row), function (id)
    local result = assert(query(string.format(
      "SELECT id, name FROM account WHERE id = %s",
      quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  Update an Account row in the database.

  ]], {{"row", Row}}, Bool, function (row)
    local result = assert(query(string.format(
      "UPDATE account SET name = %s WHERE id = %s",
      quote(row['name']),
      quote(row['id']))))
    return result.summary == 'UPDATE 1'
  end))

  assert(register("delete", [[

  Remove an Account row from the database by UUID.

  ]], {{"id", Uuid}}, Bool, function (id)
    local result = assert(query(string.format(
      "DELETE FROM account WHERE id = '%s'",
      id)))
    return result.summary == 'DELETE 1'
  end))

  assert(register("query", [[

  Query for existing Account rows.
  Optionally you can specify a filter and/or pagination parameters.

  ]], { {"query", Query} }, {Array(Row),Int}, function (queryParameters)
    queryParameters = queryParameters or {}
    local offset = queryParameters.start or 0
    local limit = queryParameters.count or 20
    local where = conditionBuilder('name', queryParameters.name)
    local sql = "SELECT count(*) from account" .. where
    local result = assert(query(sql))
    local count = result.rows[1].count
    sql = 'SELECT id, name FROM account' .. where ..
      ' ORDER BY name, id' ..
      ' LIMIT ' .. limit ..
      ' OFFSET ' .. offset
    result = assert(query(sql))
    local rows = result.rows
    return {rows, count}
  end))

end
