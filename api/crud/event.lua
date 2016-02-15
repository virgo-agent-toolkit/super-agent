local json = require('json')

return function (db, registry)
  local alias = registry.alias
  local register = registry.register
  local Optional = registry.Optional
  local String = registry.String
  local Int = registry.Int
  local Bool = registry.Bool
  local Array = registry.Array
  local query = db.query
  local quote = db.quote
  local conditionBuilder = db.conditionBuilder
  local toTable = db.toTable

  local Row = alias("Row",
    "This alias is for existing AEP entries that have an ID.",
    {event=String,timestamp=Int})

  local Query = alias("Query",
    "Structure for valid query parameters",
    {
      event = Optional(String),
      timestamp = Optional(Int),
      start = Optional(Int),
      count = Optional(Int),
    })


  assert(register("log", [[

  TODO: document me

  ]], {{"Event", Row}}, Bool, function (event)
    local eventTable = assert(json.parse(event['event']))
    if eventTable then
      assert(query(
        string.format(
          "INSERT INTO event (timestamp, event) VALUES (to_timestamp(%i), %s)",
          event['timestamp'],
          quote(event['event']))))

      -- INSERT's return null from the db so if we get here
      -- assume that it succeeded and return true
      return true
    end

    return
  end))

  assert(register("query", [[

  TODO: document me

  ]], { {"query", Query} }, {
    Array(Row)
  }, function (queryParameters)
    local offset = queryParameters.start or 0
    local limit = queryParameters.count or 20
    local eventPattern = queryParameters.event
    local timePattern = queryParameters.timestamp
    -- this is not going to work for this because we have a timestamp and we
    local where = conditionBuilder('event', eventPattern, 'timestamp', timePattern)

    local sql = "SELECT count(*) FROM event" .. where
    local result = assert(query(sql))
    local count = result.rows[1].count

    sql = 'SELECT event, timestamp FROM event' .. where ..
      ' ORDER BY timestamp, event' ..
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
