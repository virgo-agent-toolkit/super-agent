
return function (call, api)
  if call then return call end
  if api then
    return function (name, ...)
      local fn = api[name]
      if not fn then
        error("No such function " .. name)
      end
      return fn(...)
    end
  end
  return function ()
    error "This endpoint does not expose any API functions"
  end
end
