local postgresConnect = require('coro-postgres').connect

local gsub = string.gsub

local function quote(str)
  return "'" .. gsub(str, "'", "''") .. "'"
end

local function compileBlob(query)
  query = gsub(query, '_', '\\_') -- make sure we keep '_' character rather than use the sql any character
  query = gsub(query[1], '%', '\\%') -- make sure we keep '%' characters in the query
  query = gsub(query[1], '*', '%') -- convert wildcard to sql wildcard
  return query
end

return function (options)
  local psql

  local function query(...)
    if not psql then
      psql = postgresConnect(options)
    end
    return psql.query(...)
  end

  return {
    query = query,
    quote = quote,
    compileBlob = compileBlob,
    options = options,
  }
end
