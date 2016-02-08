local schema = require 'schema'
local Int = schema.Int
local String = schema.String
local Array = schema.Array
local registry = require 'registry'
local Uuid = registry.Uuid
local register = registry.section("token.")
local alias = registry.alias
local getUUID = require('uuid4').getUUID

local psqlConnect = require('coro-postgres')
local getenv = require('os').getenv

local psqlQuery = psqlConnect.connect(
  {password=getenv("PASSWORD"),
  database=getenv("DATABASE")}).query


local Query = alias("Query", {pattern=String},
  "Structure for valid query parameters")
local Page = alias("Page", {Int,Int},
  "This alias is s tuple of `limit` and `offset` for tracking position when paginating")

assert(register("log"), [[

TODO: document me

]], {{"Event", Json}}, boolean, function (event)
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
