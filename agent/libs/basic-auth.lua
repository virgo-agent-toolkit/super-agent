local base64Decode = require('base64').decode
local sha1 = require('sha1')

return function (users, realm)
  return function (req, res, go)
    local auth = req.headers.authorization
    if auth then
      local plain = base64Decode(auth:match("Basic ([^ ]*)"))
      for i = 1, #users do
        local type, value = users[i]:match("^([^:]*):(.*)$")
        if (type == "plain" and value == plain) or
           (type == "sha1" and value == sha1(plain)) then
          return go()
        end
      end
    end
    local message = "Please enter valid username/password\n"
    res.code = 401
    res.headers["WWW-Authenticate"] =
      string.format('Basic realm=%q', realm)
    res.body = message
  end
end
