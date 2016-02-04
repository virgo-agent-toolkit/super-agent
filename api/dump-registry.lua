-- Register some API modules
require('./crud/aep')
local fns, typs = require('registry').dump()
-- Dump the markdown API docs
print("# API Registry\n\nThis document is automatically generated from type annotations in the source of each module.\n")
if #typs > 0 then
  print("## Custom Types\n\nThe following type aliases are defined in this document:\n")
  print(table.concat(typs, "\n\n"))
end
if #fns > 0 then
  print("## Functions\n\nThis server implements the following public functions:\n")
  print(table.concat(fns, "\n\n"))
end
