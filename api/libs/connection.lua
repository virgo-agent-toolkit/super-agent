local postgresConnect = require('coro-postgres').connect

local gsub = string.gsub

local function quote(str)
  return "'" .. gsub(str, "'", "''") .. "'"
end

local function compileBlob(query)
  -- Escape any special characters that we don't want to interpret special.
  return gsub(query, '[\\_%%*]', function (x)
    if x == '*' then
      return '%'
    else
     return '\\' .. x
   end
  end)
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
