
local bit = require 'bit'
local rshift = bit.rshift
local lshift = bit.lshift
local bor = bit.bor
local band = bit.band
local char = string.char
local byte = string.byte
local codes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
local map = {}
for i = 1, #codes do
  map[byte(codes, i)] = i - 1
end

local function base64Decode(data)
  local bytes = {}
  local j = 1
  for i = 1, #data, 4 do
    local a = map[byte(data, i)]
    local b = map[byte(data, i + 1)]
    local c = map[byte(data, i + 2)]
    local d = map[byte(data, i + 3)]

    -- higher 6 bits are the first char
    -- lower 2 bits are upper 2 bits of second char
    bytes[j] = bor(lshift(a, 2), rshift(b, 4))

    -- if the third char is not padding, we have a second byte
    if c < 64 then
      -- high 4 bits come from lower 4 bits in b
      -- low 4 bits come from high 4 bits in c
      bytes[j + 1] = bor(lshift(band(b, 0xf), 4), rshift(c, 2))

      -- if the fourth char is not padding, we have a third byte
      if d < 64 then
        -- Upper 2 bits come from Lower 2 bits of c
        -- Lower 6 bits come from d
        bytes[j + 2] = bor(lshift(band(c, 3), 6), d)
      end
    end
    j = j + 3
  end
  return char(unpack(bytes))
end

assert(base64Decode("") == "")
assert(base64Decode("Zg==") == "f")
assert(base64Decode("Zm8=") == "fo")
assert(base64Decode("Zm9v") == "foo")
assert(base64Decode("Zm9vYg==") == "foob")
assert(base64Decode("Zm9vYmE=") == "fooba")
assert(base64Decode("Zm9vYmFy") == "foobar")

return base64Decode
