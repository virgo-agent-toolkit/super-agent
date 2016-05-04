
local function isCallable(fn, t)
  if t == "function" then return true end
  if t ~= "table" then return false end
  local meta = getmetatable(fn)
  return meta and meta.__call
end

return function (rawread, rawwrite, register, call)

  local freeze, thaw

  local function read()
    return thaw(rawread())
  end

  local function write(message)
    return rawwrite(freeze(message))
  end

  function freeze(val)
    local t = type(val)
    if isCallable(val, t) then
      return { [""] = register(val) }
    end
    if t ~= "table" then return val end
    local copy = {}
    for k, v in pairs(val) do
      copy[k] = freeze(v)
    end
    return copy
  end

  function thaw(val)
    local t = type(val)
    if t ~= "table" then return val end
    local id = val[""]
    if type(id) == "number" and next(val) == "" and next(val, "") == nil then
      return setmetatable({
        emit = function (...)
          return write {-id, ...}
        end
      }, {
        __call = function (_, ...)
          return call(id, ...)
        end
      })
    end
    local copy = {}
    for k, v in pairs(val) do
      copy[k] = thaw(v)
    end
    return copy
  end

  return read, write
end
