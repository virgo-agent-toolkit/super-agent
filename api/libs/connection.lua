local postgresConnect = require('coro-postgres').connect

local gsub = string.gsub
local format = string.format
local find = string.find
local concat = table.concat

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
  Given an even number of arguments in alternating name / value format
  this will build a SQL WHERE clause matching the values to the names.
  Any values containing `*` will be converted to a LIKE match query.
  Others will be matched using a simple `=`
  If none of the values are truthy, it will return an empty string.
]]
local function conditionBuilder(...)
  local index = 1
  local inputs = {...}
  local parts = {}
  for i = 1, select("#", ...), 2 do
    local name = inputs[i]
    local value = inputs[i + 1]
    if value then
      parts[index] = (find(value, "*", 1, true)
        and format("%s LIKE %s",
          name,
          quote(compileBlob(value)))
        or format("%s = %s",
          name,
          quote(value)))
      index = index + 1
    end
  end
  if index == 1 then
    return ""
  end
  return " WHERE " .. concat(parts, " AND ")
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
    conditionBuilder = conditionBuilder
  }
end
