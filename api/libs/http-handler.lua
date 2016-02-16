local jsonDecode = require('json').parse
local jsonEncode = require('json').stringify
local msgpackDecode = require('msgpack').decode
local msgpackEncode = require('msgpack').encode

local function fail(res, message)
  res.code = 400
  res.headers["Content-Type"] = "text/plain"
  res.body = message .. "\n"
end

return function (call)
  return function (req, res)
    local name = req.params.path
    local body = req.body or ""
    local args

    local contentType = req.headers["content-type"]
    if contentType == "application/msgpack" then
      local success, result = pcall(msgpackDecode, body)
      if not success then
        return fail(res, result)
      end
      args = result
    else
      contentType = "application/json"
      local _, err
      args, _, err = jsonDecode(body)
      if not args then
        return fail(res,
          "Invalid JSON: " .. err)
      end
    end
    if type(args) ~= "table" or #args == 0 then
      return fail(res,
        "Arguments in post body must be wrapped in an array")
    end
    local result, err = call(name, args)
    if err then
      return fail(res, err)
    end
    res.code = 200
    res.headers["Content-Type"] = contentType
    if contentType == "application/msgpack" then
      res.body = msgpackEncode(result)
    else
      res.body = jsonEncode(result)
    end
  end
end
