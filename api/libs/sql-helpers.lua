
local function quote(str)
  return "'" .. str:gsub("'", "''") .. "'"
end

return {
  quote = quote
}
