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

  ]], {{"aep", RowWithoutId}}, Uuid, function (aep)
    local id = getUUID()
    local result = assert(query(
      string.format(
        "INSERT INTO aep (id, hostname) VALUES (%s, %s)",
        quote(id),
        quote(aep['hostname']))))
    if result then
      return id
    end
    return result
  end))

  assert(register("read", [[

  TODO: document me

  ]], {{"id", Uuid}}, Row, function (id)
    local result = assert(query(
      string.format(
        "SELECT id, hostname FROM aep WHERE id = '%s'",
        quote(id))))
    return result
  end))

  assert(register("update", [[

  TODO: document me

  ]], {{"aep", Row}}, Uuid, function (aep)
    local result = assert(query(
      string.format(
        "UPDATE TABLE SET id = %s, hostname = %s FROM aep WHERE id = %s",
        quote(aep['id']),
        quote(aep['hostname']),
        quote(aep['id']))))

    if result then
      return aep['id']
    end

    return result
  end))

  assert(register("delete", [[

  TODO: document me

  ]], {{"id", Uuid}}, Uuid, function (id)
    local result = assert(query(
      string.format(
        "DELETE FROM aep WHERE id = '%s'",
        id)))
    if result then
      return id
    end

    return result
  end))

  assert(register("query", [[

  Query for existing AEP rows

  ]], { {"query", Query} }, Array(Row), function (queryParameters)
    local offset = queryParameters.start or 0
    local limit = queryParameters.count or 20
    local pattern
    if queryParameters.query then
      pattern = 'WHERE hostname LIKE ' .. compileBlob(queryParameters.query) .. ' '
    else
      pattern = ''
    end
    local sql = 'SELECT id, hostname FROM aep '..
      pattern ..
      'LIMIT '..
      limit..
      ' OFFSET '..
      offset

    return assert(query(sql))
  end))

end
