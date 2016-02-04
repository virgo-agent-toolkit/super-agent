local registry = require 'registry'
local functions = registry.functions
local aliases = registry.aliases

-- Register some API modules
require('./crud/aep')

-- Dump the markdown API docs
print("# API Registry\n\nThis document is automatically generated from type annotations in the source of each module.\n")
if next(aliases) then
  print("## Custom Types\n\nThe following type aliases are defined in this document:\n")
  local names = {}
  for name in pairs(aliases) do
    names[#names + 1] = name
  end
  table.sort(names)
  for i = 1, #names do
    local name = names[i]
    local docs, original = unpack(aliases[name])
    print("### `" .. name .. "` ← `" .. tostring(original) .. "`\n\n" .. docs)
  end
  print()
end
if next(functions) then
  print("## Functions\n\nThis server implements the following public functions:\n")
  local names = {}
  for name in pairs(functions) do
    names[#names + 1] = name
  end
  table.sort(names)
  for i = 1, #names do
    local name = names[i]
    local fn = functions[name]
    print("### `" .. tostring(fn) .. "`\n\n" .. fn.docs)
  end
  print()
end
