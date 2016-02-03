local bit = require('bit')

-- Create local aliases for common builtins for performance gains.
local rshift = bit.rshift
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift
local tobit = bit.tobit
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


-- Export all functions as module
return {
  writeCstring = writeCstring,
  writeHash = writeHash,
  writeUint16 = writeUint16,
  writeUint32 = writeUint32,
  writeUint32List = writeUint32List,

  readCString = readCString,
  readCStringList = readCStringList,
  readUint16 = readUint16,
  readInt16 = readInt16,
  readUint32 = readUint32,
  readInt32 = readInt32,
}
