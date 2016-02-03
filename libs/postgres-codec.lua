--[[lit-meta
name = "creationix/postgres-codec"
version = "0.1.0"
dependencies = {
  "creationix/coro-wrapper@2.0.0",
}
homepage = "https://github.com/virgo-agent-toolkit/super-agent/blob/master/libs/postgres-codec.lua"
description = "A pure lua implementation of the postgresql wire protocol.."
tags = {"coro", "postgres", "codec"}
license = "MIT"
authors = {
  { name = "Tim Caswell" },
  { name = "Adam Martinek" },
}
]]


-- Include binary encoding/decoding helpers
local bit = require('bit')
local coroWrapper = require('coro-wrapper')
local digest = require('openssl').digest.digest

-- Create local aliases for common builtins for performance gains.
local rshift = bit.rshift
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift
local concat = table.concat
local byte = string.byte
local char = string.char
local sub = string.sub


-- WRITERS

-- All writer functions accept a value and return a string

-- Write null terminated string
local function writeCstring(string)
  return string .. "\0"
end

-- Encode key/value pairs as pairs of null terminated strings with final null.
local function writeHash(hash)
  local parts = {}
  local i = 1
  for key, value in pairs(hash) do
    parts[i] = writeCstring(key) .. writeCstring(value)
    i = i + 1
  end
  return concat(parts) .. '\0'
end

-- Encode number as big-endian uint16_t (two-byte string)
local function writeUint16(int)
  return char(
    band(rshift(int, 8), 0xff),
    band(int, 0xff)
  )
end

-- Encode number as big-endian uint32_t (four-byte string)
local function writeUint32(int)
  return char(
    band(rshift(int, 24), 0xff),
    band(rshift(int, 16), 0xff),
    band(rshift(int, 8), 0xff),
    band(int, 0xff)
  )
end

local function writeUint32List(list)
  local parts = {}
  for i = 1, #list do
    parts[i] = writeUint32(list[i])
  end
  return concat(parts)
end


-- READERS

-- All read functions accept string and index (next byte to read)
-- They return value and index (byte after last consumed)

-- Consume a null terminated string of bytes
local function readCString(string, index)
  local start = index

  -- Skip over all non-null bytes (c-strings are null terminated)
  while byte(string, index) > 0 do
    index = index + 1
  end

  return sub(string, start, index - 1), index + 1
end

-- Consume many null-terminated strings till an extra empty null is found.
local function readCStringList(string, index)
  if byte(string, index) == 0 then
    return {}, index + 1
  end
  local list = {}
  local i = 1
  while byte(string, index) > 0 do
    list[i], index = readCString(string, index)
    i = i + 1
  end
  return list, index + 1
end

-- Consume a big-endian uint16_t
local function readUint16(string, index)
  return bor(
    lshift(byte(string, index), 8),
           byte(string, index + 1)
  ), index + 2
end

-- Consume a big-endian int16_t
local function readInt16(string, index)
  local raw = readUint16(string, index)
  return raw >= 0x8000 and raw - 0x10000 or raw, index + 2
end

-- Consume a big-endian int32_t
local function readInt32(string, index)
  return bor(
    lshift(byte(string, index), 24),
    lshift(byte(string, index + 1), 16),
    lshift(byte(string, index + 2), 8),
           byte(string, index + 3)
  ), index + 4
end

-- Consume a big-endian uint32_t
local function readUint32(string, index)
  local raw = readInt32(string, index)
  return raw < 0 and raw + 0x100000000 or raw, index + 4
end



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

-- Input is read/write pair for raw data stream and options table
-- Output is query function for sending queries
local function wrap(read, write, options)
  assert(options.username, "options.username is required")
  assert(options.database, "options.database is required")

  -- Apply the codec to the stream
  read = coroWrapper.reader(read, decode)
  write = coroWrapper.writer(write, encode)

  -- Send the StartupMessage
  write {'StartupMessage', {
    user = options.username,
    database = options.database
  }}

  -- Handle authentication state machine using a simple loop
  while true do
    local message = read()
    if message[1] == 'AuthenticationOk' then
      break
    elseif message[1] == 'AuthenticationMD5Password' then
      assert(options.password, "options.password is needed")

      local salt = message[2]
      local inner = digest('md5', options.password .. options.username)
      write { 'PasswordMessage',
        'md5'.. digest('md5', inner .. salt)
      }
    elseif message[1] == 'AuthenticationCleartextPassword' then
      write {'PasswordMessage', options.password}

    elseif message[1] == 'AuthenticationKerberosV5' then
      error("TODO: Implement AuthenticationKerberosV5 authentication")
    elseif message[1] == 'AuthenticationSCMCredential' then
      -- only possible for local unix domain connections
      error("TODO: Implement AuthenticationSCMCredential authentication")
    elseif message[1] == 'AuthenticationGSS' then
      -- frontend initiates GSSAPI negotiation
      error("TODO: Implement AuthenticationGSS authentication")
      -- write({'PasswordMessage', ''--[[First part of GSSAPI data stream]]})
    elseif message[1] == 'AuthenticationSSPI' then
      -- frontend has to initiate a SSPI negotiation
      error("TODO: Implement AuthenticationSSPI authentication")
      -- write({'PasswordMessage', ''--[[First part of SSPI data stream]]})
    elseif message[1] == 'AuthenticationGSSContinue' then
      -- continuation of SSPI and GSS or a previous GSSContinue...
      error("TODO: Implement AuthenticationGSSContinue authentication")
      -- repeat
      --   --[[
      --   message contains response from previous step
      --
      --   if the message indications more data is needed to complete
      --   the authentication, then the frontend must sund that data
      --   as another PasswordMessage
      --   ]]
      --   write({'PasswordMessage', ''--[[more of this stream]]})
      --   message = read()
      -- until message[1] ~= 'AuthenticationGSSContinue'
    elseif message[1] == 'ErrorResponse' then
      p(message)
      error("Authentication error:" .. message[2].M)
    else
      error("Unexpected response type: " .. message[1])
    end
  end

  local params = {}

  while true do
    local message = read()
    if message[1] == 'ReadyForQuery' then
      break
    elseif message[1] == 'ParameterStatus' then
      params[ message[2][1] ] = message[2][2]
    elseif message[1] == 'BackendKeyData' then
      params.backend_key_data = {
        pid = message[2],
        secret = message[3]
      }
    else
      p(message)
      error("Unexpected message: " .. message[1])
    end
  end


  local waiting

  coroutine.wrap(function ()
    local description
    local rows
    local summary
    for message in read do
      if message[1] == "ErrorResponse" then
        p(message)
        error("Server Error: " .. message[2].M)
      elseif message[1] == "RowDescription" then
        description = message[2]
        rows = {}
      elseif message[1] == "DataRow" then
        local row = {}
        rows[#rows + 1] = row
        for i = 1, #description do
          local column = description[i]
          local field = column.field
          local value = message[2][i]
          -- TODO: do type conversions so not everything is strings
          row[field] = value
        end
      elseif message[1] == "CommandComplete" then
        summary = message[2]
      elseif message[1] == "ReadyForQuery" and waiting then
        local t, r, d, s
        t, waiting = waiting, nil
        r, rows = rows, nil
        d, description = description, nil
        s, summary = summary, nil
        assert(coroutine.resume(t, r, d, s))
      else
        p(message)
        error("Unexpected message from server: " .. message[1])
      end
    end
  end)()

  local function query(sql)
    write {'Query', sql}
    waiting = coroutine.running()
    return coroutine.yield()
  end

  return {
    params = params,
    query = query,
  }
end

return {
  decode = decode,
  encode = encode,
  encoders = encoders,
  wrap = wrap,
}
