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

--[[
queryBuilder takes an array of tables
each table should be in the following format
{tableName=String, pattern=String}
]]
local function parameterBuilder(input)
  if not input then
    return ''
  end
  local index = 1
  local query = {''}
  for i=1, #input do
    if input[i].pattern then
      if i ~= 1 then
        query[index] = 'AND'
        index = index + 1
      else
        query = {' WHERE'}
        index = index + 1
      end
      query[index] = input[i].tableName..' LIKE '..quote(compileBlob(input[1].pattern))
      index = index + 1
    end
  end

  return table.concat(query, ' ')
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
    parameterBuilder = parameterBuilder
  }
end
