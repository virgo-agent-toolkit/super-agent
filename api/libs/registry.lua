local schema = require 'schema'
local addSchema = schema.addSchema
local checkType = schema.checkType
local makeAlias = schema.makeAlias

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


local functions = {}
local aliases = {}

local function register(name, docs, args, output, fn)
  local err
  fn, err = addSchema(name, args, output, fn)
  if not fn then return nil, err end
  fn.docs = docs:match "^%s*(.-)%s*$"
  functions[name] = fn
  return tostring(fn)
end

local function section(prefix)
  return function (name, ...)
    return register(prefix .. name, ...)
  end
end

local function call(name, args)
  local fn = functions[name]
  if not fn then
    return nil, "No such API function: " .. name
  end
  local result, error = fn(unpack(args))
  if not result then
    return nil, error
  end
  return result
end

local function alias(name, typ, docs)
  typ = checkType(typ)
  aliases[name] = {docs:match "^%s*(.-)%s*$", typ}
  return makeAlias(name, typ)
end

return {
  Uuid = Uuid,
  alias = alias,
  section = section,
  register = register,
  call = call,
  functions = functions,
  aliases = aliases
}
