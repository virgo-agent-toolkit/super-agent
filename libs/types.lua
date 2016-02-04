local concat = table.concat

local function capitalize(name)
  return (name:gsub("^%l", string.upper))
end

--------------------------------------

-- Ensure a value is an integer
local Int = setmetatable({}, {
  __tostring = function (_)
    return "Int"
  end,
  __call = function (_, name, value)
    local t = type(value)
    if t ~= "number" then
      return name, "Int", capitalize(t)
    end
    if value % 1 ~= 0 then
      return name, "Int", "Float"
    end
    return name, "Int"
  end
})

local Number = setmetatable({}, {
  __tostring = function(_)
    return "Number"
  end,
  __call = function (_, name, value)
    local t = type(value)
    if t ~= "number" then
      return name, "Number", capitalize(t)
    end
    return name, "Number"
  end
})

local String = setmetatable({}, {
  __tostring = function(_)
    return "String"
  end,
  __call = function (_, name, value)
    local t = type(value)
    if t ~= "string" then
      return name, "String", capitalize(t)
    end
    return name, "String"
  end
})

local Bool = setmetatable({}, {
  __tostring = function(_)
    return "Bool"
  end,
  __call = function (_, name, value)
    local t = type(value)
    if t ~= "boolean" then
      return name, "Bool", capitalize(t)
    end
    return name, "Bool"
  end
})

local recordMeta = {
  __tostring = function (self)
    local parts = {}
    local i = 1
    for k, v in pairs(self.struct) do
      parts[i] = k .. ": " .. tostring(v)
      i = i + 1
    end
    return "{" .. concat(parts, ", ") .. "}"
  end,
  __call = function (self, name, value)
    local t = type(value)
    if t ~= "table" then
      return name, tostring(self), capitalize(t)
    end
    for k, subType in pairs(self.struct) do
      local v = value[k]
      local subName, expected, actual = subType(name .. "." .. k, v)
      if actual then
        return subName, expected, actual
      end
    end
    return name, tostring(self)
  end
}
local function Record(struct)
  return setmetatable({struct = struct}, recordMeta)
end

local tupleMeta = {
  __tostring = function (self)
    local parts = {}
    for i = 1, #self.list do
      parts[i] = tostring(self.list[i])
    end
    return "[" .. concat(parts, ", ") .. "]"
  end,
  __call = function (self, name, value)
    local t = type(value)
    if t ~= "table" then
      return name, tostring(self), capitalize(t)
    end
    if #value ~= #self.list then
      local parts = {}
      for i = 1, #value do
        parts[i] = capitalize(type(value[i]))
      end
      return name, tostring(self), "[" .. concat(parts, ", ") .. "]"
    end
    for i = 1, #self.list do
      local subType = self.list[i]
      local v = value[i]
      local subName, expected, actual = subType(name .. "[" .. i .. "]", v)
      if actual then
        return subName, expected, actual
      end
    end
    return name, tostring(self)
  end
}
local function Tuple(list)
  return setmetatable({list = list}, tupleMeta)
end

local function checkRecord(value)
  if getmetatable(value) then
    return value
  elseif type(value) == "table" then
    local i = 1
    local isRecord = true
    local isTuple = true
    for k in pairs(value) do
      if k ~= i then
        isTuple = false
      elseif type(k) ~= "string" then
        isRecord = false
      end
      i = i + 1
    end
    if isRecord then
      return Record(value)
    elseif isTuple then
      return Tuple(value)
    end
  end
  p(value)
  error("Invalid schema type, record, or tuple: ", type(value))
end

local arrayMeta = {
  __tostring = function (self)
    return "Array<" .. tostring(self.subType) .. ">"
  end,
  __call = function (self, name, value)
    local t = type(value)
    if t ~= "table" then
      return name, tostring(self), capitalize(t)
    end
    local i = 1
    for k, v in pairs(value) do
      if k ~= i then
        return name, tostring(self), "Table"
      end
      local subName, expected, actual = self.subType(name .. "[" .. i .. "]", v)
      if actual then
        return subName, expected, actual
      end
      i = i + 1
    end
    return name, tostring(self)
  end
}
local function Array(subType)
  return setmetatable({subType = checkRecord(subType)}, arrayMeta)
end


local function test(shouldPass, typ, value)
  typ = checkRecord(typ)
  local name, expected, actual = typ("arg", value)
  if shouldPass then
    if actual then
      p(unpack{name, expected, value, actual})
      error("Should pass, but did not: " .. tostring(typ))
    -- else
    --   print("Should pass and did: " .. tostring(typ))
    end
  else
    if not actual then
      p(unpack{name, expected, value, actual})
      error("Should not pass, but did: " .. tostring(typ))
    -- else
    --   print("Should not pass and did not: " .. tostring(typ))
    end
  end
end

-- Inline unit tests
test(true, Int, 4)
test(false, Int, 4.5)
test(true, Number, 4.5)
test(false, Number, false)
test(true, String, "Hello")
test(false, String, 100)
test(true, Bool, true)
test(false, Bool, 0)
test(true, Array(Int), {})
test(true, Array(Int), {1,2})
test(false, Array(Int), {1, false})
test(false, Array(Int), {name="Tim"})
test(false, Array(Int), 42)
test(true, {String,Int}, {"Hello",42})
test(false, {String,Int}, {"Hello",false})
test(false, {String,Int}, {"Hello",100,true})
test(true, {}, {})
test(true, {name=String,age=Int}, {name="Tim",age=33,isProgrammer=true})
test(true, Array({name=String}), {{name="Tim",age=33}})
test(false, Array({name=String}), {{name="Tim",age=33}, 10})
test(false, {name=String,age=Int}, {name="Tim",age="old"})
test(false, {name=String,age=Int}, {1,2,3})
test(false, {name=String,age=Int}, 757)

return {
  Int = Int,
  Number = Number,
  String = String,
  Bool = Bool,
  Array = Array,
  Record = Record,
  checkRecord = checkRecord,
}
