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

  local Aep = alias("Aep",
    "This alias is for existing AEP entries that have an ID.",
    {id=Uuid,hostname=String})

  local AepWithoutId = alias("AepWithoutId",
    "This alias is for creating new AEP entries that don't have an ID yet",
    {hostname=String})

  local Query = alias("Query",
    "Structure for valid query parameters",
    {
      hostname = Optional(String),
      offset = Optional(Int),
      limit = Optional(Int),
    })

  assert(register("create", [[

  This function creates a new AEP entry in the database.  It will return
  the randomly generated UUID so you can reference the AEP.

  ]], {{"aep", AepWithoutId}}, Uuid, function (aep)
    local id = getUUID()
    assert(query(string.format(
      "INSERT INTO aep (id, hostname) VALUES (%s, %s)",
      quote(id),
      quote(aep.hostname))))
    return id
  end))

  assert(register("read", [[

  Given a UUID, return the corresponding row.

  ]], {{"id", Uuid}}, Optional(Aep), function (id)
    local result = assert(query(string.format(
      "SELECT id, hostname FROM aep WHERE id = %s",
      quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  Update an AEP row in the database.

  ]], {{"aep", Aep}}, Bool, function (aep)

    local result = assert(query(string.format(
      "UPDATE aep SET hostname = %s WHERE id = %s",
      quote(aep.hostname),
      quote(aep.id))))
    return result.summary == 'UPDATE 1'
  end))

  assert(register("delete", [[

  Remove an AEP row from the database by UUID.

  ]], {{"id", Uuid}}, Bool, function (id)

    local result = assert(query(string.format(
      "DELETE FROM aep WHERE id = %s",
      quote(id)))) -- something is going on and for some reason breaks when I try to quote this id

    return result.summary == 'DELETE 1'
  end))

  assert(register("query", [[

  Query for existing AEP rows.
  Optionally you can specify a filter and/or pagination parameters.

  ]], { {"query", Query} }, {Columns,Rows,Stats}, function (queryParameters)
    queryParameters = queryParameters or {}
    local offset = queryParameters.offset or 0
    local limit = queryParameters.limit or 20
    local pattern = queryParameters.hostname
    local where = conditionBuilder('hostname', pattern)
    local sql = "SELECT count(*) from aep" .. where
    local result = assert(query(sql))
    local count = result.rows[1].count
    sql = 'SELECT id, hostname FROM aep' .. where ..
      ' ORDER BY id' ..
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
