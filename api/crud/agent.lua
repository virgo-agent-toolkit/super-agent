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


  local Agent = alias("Agent",
  "This alias is for existing agent entries that have an ID.",
  {
    id=Uuid,
    name=String,
    aep_id=Uuid,
    token=Uuid,
    account_id=Uuid
  })

  local AgentWithoutId = alias("AgentWithoutId",
  "This alias creates a new agent",
  {
    name=String,
    aep_id=Uuid,
    token=Uuid,
    account_id=Uuid
  })

  local Query = alias("Query",
    "Structure for valid query parameters",
    {
      account_id = Optional(String),
      name = Optional(String),
      aep_id = Optional(String),
      token = Optional(String),
      start = Optional(Int),
      count = Optional(Int),
    })

  -- create({description}})
  -- update({uuid,name})
  -- delete(uuid)
  -- query({pattern}, {limit,offset})

  assert(register("create", [[

  This function creates a new agent entry in the database.
  It will return the randomly generated UUID of the agent.
  ]], {{"AgentWithoutId", AgentWithoutId}}, Uuid, function (agent)
    local id = getUUID()
    assert(query(
      string.format("INSERT INTO agent (id, name, token, account_id, aep_id) VALUES (%s, %s, %s, %s, %s)",
        quote(id),
        quote(agent.name),
        quote(agent.token),
        quote(agent.account_id),
        quote(agent.aep_id))))

    return id
  end))


  assert(register("read", [[

  TODO: document me

  ]], {{"id", Uuid}}, Agent, function (id)
    local result = assert(query(
      string.format("SELECT id, name, account_id, aep_id, token FROM agent WHERE id=%s",
        quote(id))))
    return result.rows and result.rows[1]
  end))

  assert(register("update", [[

  TODO: document me

  ]], {{"Agent", Agent}}, Bool, function (agent)
    local result = assert(query(
      string.format(
        "UPDATE agent SET name = %s, "..
        "account_id = %s, token = %s, aep_id = %s WHERE id = %s",
        quote(agent.name),
        quote(agent.account_id),
        quote(agent.token),
        quote(agent.aep_id),
        quote(agent.id))))
        -- are there other things we want to set?

    return result.summary == 'UPDATE 1'
  end))

  assert(register("delete", [[

  Deletes an agent with a particular id

  ]], {{"id", Uuid}}, Bool, function (id)
    local result = assert(query(
      string.format(
        "DELETE FROM agent WHERE id = %s",
        quote(id))))

    return result.summary == 'DELETE 1'
  end))

  assert(register("query", [[

  TODO: document me

  ]], {
    {"query", Query}},
    {Columns,Rows,Stats}, function (queryParameters)
      queryParameters = queryParameters or {}
      local offset = queryParameters.start or 0
      local limit = queryParameters.count or 20
      local where = conditionBuilder(
        'account_id', queryParameters.account_id,
        'name', queryParameters.name,
        'aep_id', queryParameters.aep_id,
        'token', queryParameters.token
      )
      local sql = "SELECT count(*) from agent" .. where
      local result = assert(query(sql))
      local count = result.rows[1].count
      sql = 'SELECT id, name, token, account_id, aep_id FROM agent' .. where ..
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
