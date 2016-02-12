local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local Bool = schema.Bool
local Json = schema.Json
local registry = require 'registry'
local register = registry.section("token.")
local alias = registry.alias

local psqlConnect = require('coro-postgres')
local getenv = require('os').getenv

local psqlQuery = psqlConnect.connect(
  {password=getenv("PASSWORD"),
  database=getenv("DATABASE")}).query

-- TODO: convert file to new registry format

local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")

assert(register("log"), [[

TODO: document me

]], {{"Event", Json}}, Bool, function (event)
  local result = psqlQuery(
    string.format(
      "INSERT INTO event (timestamp, event) VALEUS (NOW(), '%s')",
      event['event']))


  return result
end)

assert(register("query", [[

TODO: document me

]], {
  {"query", Query},
  {"page", Page},
}, {
  Array(Aep),
  Page
}, function (query)
  -- TODO: Implement
end))
