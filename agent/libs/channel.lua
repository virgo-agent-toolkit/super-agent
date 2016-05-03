return function ()
  local data
  local thread
  local function put(message)
    assert(not data, "Data already in queue")
    if thread then
      local t = thread
      thread = nil
      return coroutine.resume(t, message)
    end
    data = message
    thread = coroutine.running()
    return coroutine.yield()
  end
  local function get()
    if data then
      local d, t
      d, t, data, thread = data, thread, nil, nil
      coroutine.resume(t)
      return d
    end
    thread = coroutine.running()
    return coroutine.yield()
  end
  return {
    put = put,
    get = get
  }
end
