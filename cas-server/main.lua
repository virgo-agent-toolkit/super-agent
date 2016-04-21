local uv = require('uv')
local getenv = require('os').getenv
local success, luvi = pcall(require, 'luvi')
if success then
  loadstring(luvi.bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()
else
  dofile('luvit-loader.lua')
end

local connect = require('redis-client')
local p = require('pretty-print').prettyPrint
local sha1 = require('sha1')
local json = require('json')
local msgpack = require('msgpack')
local S = require('schema')
local Array = S.Array
local String = S.String
local Optional = S.Optional
local Int = S.Int
local CustomString = S.CustomString
local addSchema = S.addSchema

local Hash = CustomString("Hash", function (str)
  return #str == 40 and str:match("^[0-9a-fA-F]+$")
end)
local Email = CustomString("Email", function (str)
  return str:match(".@.")
end)
-- String representation of module public interface in schema format.
local Type = CustomString("Type", function (str)
  -- TODO: compile type interface
  return str
end)

local q
local function query(...)
  if not q then
    q = connect()
  end
  return q(...)
end

local function exists(hash)
  return assert(query("exists", hash)) ~= 0
end

-- hashes are put in this table with an associated timeout timestamp
-- If they are still in here when the timestamp expires, the corresponding
-- key is deleted from the database.
local temps = {}
local interval = uv.new_timer()
interval:start(1000, 1000, function ()
  local now = uv.now()
  local expired = {}
  for key, ttl in pairs(temps) do
    if ttl < now then
      expired[key] = true
    end
  end
  for key in pairs(expired) do
    temps[key] = nil
    print("Ejecting timed out value", key)
    coroutine.wrap(function ()
      query("del", key)
    end)()
  end
end)
interval:unref()


local function validateHash(hash, name)
  if not exists(hash) then
    error(name .. " points to missing hash: " .. hash)
  end
  temps[hash] = nil
end

local function validatePairsHashes(list, group)
  for i = 1, #list do
    local name, hash = unpack(list[i])
    validateHash(hash, name .. group)
  end
end

local publish = assert(addSchema("publish", {
  {"message", {
    name = String, -- single word name
    code = Hash, -- Source code to module as a single file.
    description = Optional(String), -- single-line description
    interface = Optional(Type), -- type signature of module's exports.
    docs = Optional(Hash), -- Markdown document with full documentation
    dependencies = Optional(Array({String,Hash})), -- Mapping from local aliases to hash.
    assets = Optional(Array({String,Hash})), -- Mapping from name to binary data.
    tests = Optional(Array({String, Hash})), -- Unit tests as array of named files.
    owners = Optional(Array(Email)), -- List of users authorized to publish updates
    changes = Optional{ -- Fine grained data about change history
      parent = Hash, -- Parent module
      level = Optional(Int), -- 0 - metadata-only, 1 - backwards-compat, 2 - breaking
      meta = Optional(Array(String)), -- metadata related changes
      fixes = Optional(Array(String)), -- bug fixes
      additions = Optional(Array(String)), -- New features
      changes = Optional(Array(String)), -- breaking changes
    },
    license = Optional(String)
  }},
}, {
  {"hash", Hash},
}, function (message)
  local data = msgpack.encode(message)
  local hash = sha1(data)
  if exists(hash) then return hash end
  validateHash(message.code, "code")
  if message.docs then
    validateHash(message.docs, "docs")
  end
  if message.dependencies then
    validatePairsHashes(message.dependencies, " dependency")
  end
  if message.assets then
    validatePairsHashes(message.assets, " asset")
  end
  if message.tests then
    validatePairsHashes(message.tests, " test")
  end
  if message.changes then
    validateHash(message.changes.parent, "changes.parent")
  end
  query("set", hash, data)
  return hash
end))


require('weblit-app')

  .use(require('weblit-logger'))
  .use(require('weblit-auto-headers'))
  .use(require('weblit-etag-cache'))

  .route({
    method = "GET",
    path = "/:hash"
  }, function (req, res)
    local hash = req.params.hash
    assert(#hash == 40, "hash param must be 40 characters long")
    local data = query("get", hash)
    if not data then return end
    res.code = 200
    res.headers["Content-Type"] = "application/octet-stream"
    res.body = data
  end)

  .route({
    method = "PUT",
    path = "/:hash"
  }, function (req, res)
    local hash = req.params.hash
    assert(#hash == 40, "hash param must be 40 characters long")
    local body = assert(req.body, "missing request body")
    assert(sha1(body) == hash, "hash mismatch")

    if exists(hash) then
      res.code = 200
      -- TODO: find out if we can cancel upload in case value already exists.
    else
      assert(query("set", hash, body))
      res.code = 201
      temps[hash] = uv.now() + (5 * 60 * 1000)
    end

    res.body = nil
    res.headers["ETag"] = '"' .. hash .. '"'
  end)


  .route({
    method = "POST",
    path = "/"
  }, function (req, res)
    local body = assert(req.body, "missing request body")
    local message
    local contentType = assert(req.headers["Content-Type"], "Content-Type header missing")
    if contentType == "application/json" then
      message = assert(json.parse(body))
    elseif contentType == "application/msgpack" then
      message = assert(msgpack.decode(body))
    else
      error("Supported content types are application/json and application/msgpack")
    end
    local hash = assert(publish(message))
    res.code = 201
    res.body = hash
    res.headers["Refresh"] = '/' .. hash
    res.headers["Content-Type"] = 'text/plain'
  end)

  .bind {
    host = getenv('HOST') or '127.0.0.1',
    port = getenv('PORT') or 4000
  }

  .start()

require('uv').run()
