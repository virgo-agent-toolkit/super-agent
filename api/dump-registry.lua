-- Register some API modules
require('./crud/aep')

local dump = require('registry').dump

print("# API Registry\n\nThis document is automatically generated from type annotations in the source of each module.\n")
print(table.concat(dump(), "\n"))
