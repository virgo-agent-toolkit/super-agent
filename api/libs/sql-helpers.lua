local gsub = string.gsub
local function quote(str)
  return "'" .. str:gsub("'", "''") .. "'"
end

local function cleanQueryPattern(query)
  query = gsub(query, '_', '\\_') -- make sure we keep '_' character rather than use the sql any character
  query = gsub(query[1], '%', '\\%') -- make sure we keep '%' characters in the query
  query = gsub(query[1], '*', '%') -- convert wildcard to sql wildcard
  return query
end

return {
  quote = quote,
  cleanQuery = cleanQueryPattern,
}
