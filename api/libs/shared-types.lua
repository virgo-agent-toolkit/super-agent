local schema = require 'schema'
local Int = schema.Int
local alias = require('registry').alias

return {
  Page = alias("Page", {Int,Int},
    "This alias is s tuple of `limit` and `offset` for tracking position when paginating")
}
