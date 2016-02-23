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
  local Stats = registry.Stats
  local query = db.query
  local quote = db.quote
  local conditionBuilder = db.conditionBuilder
  local toTable = db.toTable


  local Columns = alias("Columns", "Column field names for query results.",
    {String,String})
  local Rows = alias("Rows", "Raw rows for query results.",
    Array({String,String}))

  local Account = alias("Account",
    "This alias is for existing Account entries that have an ID.",
    {id=Uuid,name=String})

  local AccountWithoutId = alias("AccountWithoutId",
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

  ]], {{"account", AccountWithoutId}}, Uuid, function (account)
    local id = getUUID()
    assert(query(string.format(
      "INSERT INTO account (id, name) VALUES (%s, %s)",
      quote(id),
      quote(account.name))))
    return id
  end))

  assert(register("read", [[

  Given a UUID, return the corresponding row.

  ]], {{"id", Uuid}}, Optional(Account), function (id)
    local result = assert(query(string.format(
      "SELECT id, name FROM account WHERE id = %s",
      quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  Update an Account row in the database.

  ]], {{"account", Account}}, Bool, function (account)
    local result = assert(query(string.format(
      "UPDATE account SET name = %s WHERE id = %s",
      quote(account.name),
      quote(account.id))))
    return result.summary == 'UPDATE 1'
  end))

  assert(register("delete", [[

  Remove an Account row from the database by UUID.

  ]], {{"id", Uuid}}, Bool, function (id)
    local result = assert(query(string.format(
      "DELETE FROM account WHERE id = %s",
      quote(id))))
    return result.summary == 'DELETE 1'
  end))

  assert(register("query", [[

  Query for existing Account rows.
  Optionally you can specify a filter and/or pagination parameters.

  ]], { {"query", Query} }, {Columns,Rows,Stats}, function (queryParameters)
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
    local columns, rows = toTable(result)
    local stats = {
      offset,
      limit,
      count
    }
    return {columns,rows,stats}
  end))

end
