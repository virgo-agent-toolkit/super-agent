local jsonDecode = require('json').parse
local jsonEncode = require('json').stringify
local msgpackDecode = require('msgpack').decode
local msgpackEncode = require('msgpack').encode

return function (read, write, jsonFirst)
  local encode = jsonFirst and jsonEncode or msgpackEncode
  return function ()
    local frame = read()
    local message
    if frame.opcode == 1 then
      message = jsonDecode(frame.payload)
      encode = jsonEncode
    elseif frame.opcode == 2 then
      message = msgpackDecode(frame.payload)
      encode = msgpackEncode
    end
    return message
  end, function (message)
    return write {
      opcode = encode == jsonEncode and 1 or 2,
      payload = encode(message),
    }
  end
end
