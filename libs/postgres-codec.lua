-- Include binary encoding/decoding helpers
local bodec = require('./bodec')

-- Create local aliases for common functions for performance gains.
local writeCstring = bodec.writeCstring
local writeHash = bodec.writeHash
local writeUint16 = bodec.writeUint16
local writeUint32 = bodec.writeUint32
local writeUint32List = bodec.writeUint32List
local readCString = bodec.readCString
local readCStringList = bodec.readCStringList
local readUint16 = bodec.readUint16
local readInt16 = bodec.readInt16
local readUint32 = bodec.readUint32
local readInt32 = bodec.readInt32
local concat = table.contat
local sub = string.sub
local byte = string.byte

local function frame (header, body)
  -- +4 is because the length header includes it's own space.
  return header .. writeUint32(#body + 4) .. body
end

-- http://www.postgresql.org/docs/8.3/static/protocol-message-formats.html
local encoders = {}

function encoders.CopyData()
  -- TODO: implement
end

function encoders.CopyDone()
  -- TODO: implement
end

function encoders.Describe(name, type)
  return frame('D',
    type ..
    writeCstring(name)
  )
end

function encoders.Execute(name, max_rows)
  return frame('E',
    writeCstring(name)..
    writeUint32(max_rows)
  )
end

function encoders.Flush()
  return frame('H', "")
end

function encoders.FunctionCall()
  -- TODO: implement
end

function encoders.Parse(name, query, var_types)
  assert(type(var_types) == "table")
  assert(type(name) == "string")
  assert(type(query) == "string")
  return frame('P', concat(
    writeCstring(name),
    writeCstring(query),
    writeUint16(#var_types),
    writeUint32List(var_types)
  ))
end

function encoders.PasswordMessage(password)
  assert(type(password) == "string")
  return frame('p',
    writeCstring(password)
  )
end

function encoders.Query(query)
  return frame('Q', writeCstring(query))
end

function encoders.SSLRequest()
  return frame('', writeUint32(80877103))
end

function encoders.StartupMessage(options)
  -- Protocol version number 3
  return frame('',
    writeUint32(196608) ..
    writeHash(options)
  )
end

function encoders.Sync()
  return frame('S', '')
end

function encoders.Terminate()
  return frame('X', '')
end

local function encode(message)
  -- message is a table with two values
  local request, data = message[1], message[2]
  local formatter = encoders[request]

  if not formatter then
    error('No such request type: ' .. request)
  end

  return formatter(data)
end


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

-- Input is (string, index) where index is the first byte to start reading at.
-- Output is (type, data...)
local parsers = {

  -- Parse the various Authentication* responses
  [byte('R', 1)] = function (string)
    local authCode = readUint32(string, 1)
    local authType = authRequests[authCode]
    if not authType then
      error('Unknown auth code: ' .. authCode)
    end
    if authType == "AuthenticationMD5Password" then
      local salt = sub(string, 5, 8)
      return authType, salt
    end
    return authType
  end,

  -- Parse an ErrorResponse
  [byte('E', 1)] = function (string)
    local list = readCStringList(string, 1)
    local map = {}
    for i = 1, #list do
      map[sub(list[i], 1, 1)] = sub(list[i], 2)
    end
    return 'ErrorResponse', map
  end,

  -- Parse a ParameterStatus message
  [byte('S', 1)] = function (string)
    return "ParameterStatus", (readCStringList(string, 1))
  end,

  -- Parse a BackendKeyData message
  [byte('K', 1)] = function (string)
    return 'BackendKeyData', readUint32(string, 1), (readUint32(string, 5))
  end,

  -- Parse a ReadyForQuery message
  [byte('Z', 1)] = function (string)
    return 'ReadyForQuery', sub(string, 1, 1)
  end,

  -- Parse a RowDescription message
  [byte('T', 1)] = function (string)
    local numFields, index = readUint16(string, 1)
    local data = {}
    local i = 1
    while i <= numFields do
      local entry = {}
      data[i] = entry
      entry.field, index = readCString(string, index)
      entry.tableId, index = readInt32(string, index)
      entry.columnId, index = readInt16(string, index)
      entry.typeId, index = readInt32(string, index)
      entry.typeSize, index = readInt16(string, index)
      entry.typeModifier, index = readInt32(string, index)
      entry.formatCode, index = readInt16(string, index)
      i = i + 1
    end
    return 'RowDescription', data
  end,

  -- Parse a DataRow message
  [byte('D', 1)] = function (string)
    local numFields, index = readUint16(string, 1)
    local data = {}
    local i = 1
    while i <= numFields do
      local size
      size, index = readInt32(string, index)
      -- negative size is null record.
      if size > 0 then
        local start = index
        index = index + size -- TODO: check if this size includes the 4 bytes for size itself
        data[i] = sub(string, start, index - 1)
      end
      i = i + 1
    end
    return 'DataRow', data
  end,

  -- Parse a CommandComplete message
  [byte('C', 1)] = function (string)
    return 'CommandComplete', (readCString(string, 1))
  end,

  -- Parse a NoticeResponse message
  [byte('N', 1)] = function (string)
    return 'NoticeResponse', (readCStringList(string, 1))
  end
}

local function decode (string)
  if #string < 5 then return end
  -- read bytes 2-5 decode as an integer and that will tell us the length
  local len, index = readUint32(string, 2)
  if #string < len + 1 then return end
  len = len - 4

  --grab the first value. Which tells us which table/thing we are doing
  local parse = parsers[byte(string, 1)]
  if not parse then
    error('Unhandled response code: ' .. sub(string, 1, 1))
  end

  local data = sub(string, index, index + len - 1) .. "\0"
  local extra = sub(string, index + len)

  return {parse(data)}, extra
end

return {
  decode = decode,
  encode = encode,
  encoders = encoders
}
