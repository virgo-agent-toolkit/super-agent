local getUUID = require('uuid4').getUUID

return function (db, registry)
  local alias = registry.alias
  local register = registry.register
  local Optional = registry.Optional
  local String = registry.String
  local Int = registry.Int
  local Array = registry.Array
  local Uuid = registry.Uuid
  local query = db.query
  local quote = db.quote
  local compileBlob = db.compileBlob

  local Row = alias("Row",
    "This alias is for existing AEP entries that have an ID.",
    {id=Uuid,hostname=String})

  local RowWithoutId = alias("RowWithoutId",
    "This alias is for creating new AEP entries that don't have an ID yet",
    {hostname=String})

  local Query = alias("Query",
    "Structure for valid query parameters",
    {
      hostname = Optional(String),
      start = Optional(Int),
      count = Optional(Int),
    })

  assert(register("create", [[

  This function creates a new AEP entry in the database.  It will return
  the randomly generated UUID so you can reference the AEP.

  ]], {{"row", RowWithoutId}}, Uuid, function (row)
    local id = getUUID()
    assert(query(string.format(
      "INSERT INTO aep (id, hostname) VALUES (%s, %s)",
      quote(id),
      quote(row['hostname']))))
    return id
  end))

  assert(register("read", [[

  Given a UUID, return the corresponding row.

  ]], {{"id", Uuid}}, Optional(Row), function (id)
    local result = assert(query(string.format(
      "SELECT id, hostname FROM aep WHERE id = %s",
      quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  Update an AEP row in the database.

  ]], {{"row", Row}}, Uuid, function (row)
    assert(query(string.format(
      "UPDATE aep SET hostname = %s WHERE id = %s",
      quote(row['hostname']),
      quote(row['id']))))
    return row['id']
  end))

  assert(register("delete", [[

  Remove an AEP row from the database by UUID.

  ]], {{"id", Uuid}}, Uuid, function (id)
    assert(query(string.format(
      "DELETE FROM aep WHERE id = '%s'",
      id)))
    return id
  end))

  assert(register("query", [[

  Query for existing AEP rows.
  Optionally you can specify a filter and/or pagination parameters.

  ]], { {"query", Query} }, Array(Row), function (queryParameters)
    local offset = queryParameters.start or 0
    local limit = queryParameters.count or 20
    local pattern
    if queryParameters.query then
      pattern = ' WHERE hostname LIKE' .. compileBlob(queryParameters.query) .. ' '
    else
      pattern = ''
    end
    local sql = 'SELECT id, hostname FROM aep' .. pattern ..
      ' LIMIT ' .. limit ..
      ' OFFSET ' .. offset
    local result = assert(query(sql))
    return result.rows
  end))

end
