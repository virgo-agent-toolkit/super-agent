--[[
I am really not sure what the equivalent lua packages are for these

local crypto = require('crypto'),
    net = require("net"),
    sys = require("sys"),
    sqllib = require('./sql'),
    url = require('url');
require('./buffer_extras');
]]
local bit = require('bit')

--[[
So the tricky part of a decoder is that we are going to have to deal with Partial
messages. TCP reframes everything


network is big endian ... generally! So we can try big endian and if that doesnt
work



The simple way is that we have a bunch of function that we hand a number and return a string
Just regular flat functions.

local int32Write
]]

local rshift = bit.rshift
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift

local concat = table.concat

local byte = string.byte
local char = string.char

local function readInt32(buffer, offset)
  return bor(
    lshift(byte(buffer, offset), 24),
    lshift(byte(buffer, offset+1), 16),
    lshift(byte(buffer, offset+2), 8),
    lshift(byte(buffer, offset+3), 0)
  )
end



--[[
returns a big endian non signed 32 int
]]
local function fromInt32 (number)
  -- so we are just returning a byte string
  return char(
    band(rshift(number, 24), 0xFF),
    band(rshift(number, 16), 0xFF),
    band(rshift(number, 8), 0xFF),
    band(rshift(number, 0), 0xFF)
    )
end

local function fromInt16 (number)
  -- so we are just returning a byte string
  return char(
    band(rshift(number, 8), 0xFF),
    band(rshift(number, 0), 0xFF)
    )
end

--[[
utf8 encode this and then append a null byte
ignore utf8 encoding because we just assume that is the case

in js strings are 16 bit code points. encoding is something like ucs-16?
Most unicode can fit in 16 bit. node and js will translate a lot of utf8 and unicode

in lua we just assume everything is utf8
]]
local function toCstring (string)
  return string.."\0"
end

--[[
header + length of message + length  + message

we always know that length is an integer hence + 4

]]
local integerSize = 4
local function frame (header, body)
  return header .. fromInt32(#body + integerSize) .. body-- length of body
end

local function fromHash (input)
  local tempTable = {}
  local i = 0
  for key,value in pairs(input) do
    i = i + 1
    tempTable[i] = toCstring(key) .. toCstring(value)
  end
  return concat(tempTable)..'\0'
end

local function fromInt32List (input)
  local tempTable = {}
  for i = 1, #input do
    tempTable[i] = fromInt32(input[i])
  end
  return concat(tempTable)
end





-- http://www.postgresql.org/docs/8.3/static/protocol-message-formats.html
local formatter = {
  CopyData = function ()
    -- TODO: implement
  end,
  CopyDone = function ()
    -- TODO: implement
  end,
  Describe = function (name, type)
    return frame ('D',
      type ..
      toCstring(name)
    )
  end,
  Execute = function (name, max_rows)
    return frame ('E',
      toCstring(name)..
      fromInt32(max_rows)
    )
  end,
  Flush = function ()
    return frame('H', "")
  end,
  FunctionCall = function ()
    -- TODO: implement
  end,
  Parse = function (name, query, var_types)
    assert(type(var_types) == "table")
    assert(type(name) == "string")
    assert(type(query) == "string")
    return frame('P',
      toCstring(name) ..
      toCstring(query) ..
      fromInt16(#var_types) ..
      fromInt32List(var_types)
    )
  end,
  PasswordMessage = function (password)
    assert(type(password) == "string")
    return frame('p',
      toCstring(password)
    )
  end,
  Query = function (query)
    return frame('Q', toCstring(query))
  end,
  SSLRequest = function ()
    return frame('', fromInt32(80877103))
  end,
  StartupMessage = function (options)
    -- Protocol version number 3
    return frame('',
      fromInt32(196608) ..
      fromHash(options)
    )
  end,
  Sync = function ()
    return frame('S', '')
  end,
  Terminate = function ()
    return frame('X', '')
  end
}


--[[have a function that takes the current buffer. We don know how manay messages we have
first thingw e do is find out if there is enough data to read one message. As fast as possible
If not enough data for a message return nothing. We are done. Signals to the consumer to wait for more data
and concatinate things together until we have a full message.

Lets us ignore whether or not we have a full message.

So once we parse it then we get two things. The full message and probably a partial message.

]]


-- Parse response streams from the server

--we are going to assume that the server has given us good data
-- we can fix this with a table

-- use this to get the string from the number and then a single if for things that need extra data


local authRequests = {
  [0] = "AuthenticationOk",
  [2] = "AuthenticationKerberosV5",
  [3] = "AuthenticationCleartextPassword",
  [4] = "AuthenticationCryptPassword",
  [5] = "AuthenticationMD5Password",
  [6] = "AuthenticationSCMCredential",
  [7] = "AuthenticationGSS",
  [8] = "AuthenticationGSSContinue",
  [9] = "AuthenticationSSPI"
}
local sub = string.sub

local function multicstring(buffer, offset)
  local stringList = {}
  local i = 1
  while byte(buffer, offset) > 0 do
    -- read one or more bytes... scan for next 0
    local start = offset
    repeat
      offset = offset + 1
    until byte(buffer, offset) == 0

    stringList[i] = sub(buffer, start, offset-1)
    offset = offset + 1
    i = i + 1
  end
  return offset, stringList
end

-- return format: offset, type, extra arguments
local responses = {
  [byte('R', 1)] = function (buffer)
    local authCode = readInt32(buffer, 6)
    local authType = authRequests[authCode]
    if not authType then error('Unknown auth type: ' .. authCode) end

    if authType == "AuthenticationMD5Password" then
      local salt = char(
        byte(buffer, 10),
        byte(buffer, 11),
        byte(buffer, 12),
        byte(buffer, 13))
      -- why are we returning 14? because the authtype
      -- takes up 10 bytes and the salt takes up 4?
      return 14, authType, salt
    end

    return 10, authType
  end,
  [byte('E', 1)] = function (buffer)
    p(buffer)
    local offset, list = multicstring(buffer, 6)

    local returnValues = {}
    for i = 1, #list do
      returnValues[sub(list[i], 1, 1)] = sub(list[i], 2)
    end

    return offset, 'ErrorResponse', returnValues
  end,
  [byte('S', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('K', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('Z', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('T', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('D', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('C', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end,
  [byte('N', 1)] = function (buffer)
    error("TODO: parse me:\t" .. buffer)
  end
}

local function decode (buffer)
  if #buffer < 5 then return end
  -- read bytes 2-5 decode as an integer and that will tell us the length
  local len = readInt32(buffer, 2)
  if #buffer < len+1 then return end

  --grab the first value. Which tells us which table/thing we are doing
  local handler = responses[byte(buffer, 1)]
  if not handler then error('unhandled response code: ' .. buffer:sub(1,1)) end

  return handler(buffer)
end

return {
  decode = decode,
  formatter = formatter
}
