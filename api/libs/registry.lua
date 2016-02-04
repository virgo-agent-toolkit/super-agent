local addSchema = require('schema').addSchema

-- Custom type for database UUIDs
local Uuid = setmetatable({}, {
  __tostring = function(_)
    return "Uuid"
  end,
  __call = function (_, name, value)
    local t = type(value)
    if t == "string"
        and #value == 36
        and value:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
        return name, "Uuid"
    end
    return name, "Uuid", t:gsub("^%l", string.upper)
  end
})


local fns = {}

local function register(name, docs, args, output, fn)
  if not args then -- Allow creating prefixed groups
    return function (newName, ...)
      return register(name .. newName, ...)
    end
  end

  local err
  fn, err = addSchema(name, args, output, fn)
  if not fn then return nil, err end
  fn.docs = docs:match "^%s*(.-)%s*$"
  fns[name] = fn
  return tostring(fn)
end

local function call(name, args)
  local fn = fns[name]
  if not fn then
    return nil, "No such API function: " .. name
  end
  local result, error = fn(unpack(args))
  if not result then
    return nil, error
  end
  return result
end

local function dump()
  local defs = {}
  for key in pairs(fns) do
    defs[#defs + 1] = key
  end
  table.sort(defs)
  for i = 1, #defs do
    local key = defs[i]
    local fn = fns[key]
    defs[i] = "## " .. tostring(fn) .. "\n\n" .. fn.docs
  end
  return defs
end

return {
  Uuid = Uuid,
  register = register,
  call = call,
  dump = dump,
}
