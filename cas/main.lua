local uv = require('uv')
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
local makeAlias = S.makeAlias
local addSchema = S.addSchema

local Hash = makeAlias("Hash", String)
local Version = makeAlias("Version", String)
local Email = makeAlias("Email", String)
-- Hash to local file, server will request file content if needed.
local File = makeAlias("File", Hash)
-- String representation of module public interface in schema format.
local Type = makeAlias("Type", String)

local q
local function query(...)
  if not q then
    q = connect()
  end
  return q(...)
end

local publish = assert(addSchema("publish", {
  {"message", {
    code = File, -- Source code to module as a single file.
    interface = Type, -- type signature of module's exports.
    tests = Optional(Array({String,File})), -- Unit tests as array of named files.
    name = Optional(String), -- single word name
    description = Optional(String), -- single-line description
    docs = Optional(File), -- Markdown document with full documentation
    owners = Optional(Array(Email)), -- List of users authorized to publish updates
    parent = Optional(Hash), -- Parent module
    changes = Optional{ -- Fine grained data about change history
      level = Optional(Int), -- 0 - metadata-only, 1 - backwards-compat, 2 - breaking
      meta = Optional(Array(String)), -- metadata related changes
      fixes = Optional(Array(String)), -- bug fixes
      additions = Optional(Array(String)), -- New features
      changes = Optional(Array(String)), -- breaking changes
    },
    dependencies = Optional(Array({String,Hash})), -- Mapping from local aliases to hash
    license = Optional(String)
  }},
}, {
  {"result", {
    hash = Hash,
    version = Version,
  }},
}, function (message)
  local version = "1.0.2"
  message.version = version
  local data = msgpack.encode(message)
  local key = sha1(data)
  query("set", key, message)
  return {
    hash = key,
    version = version
  }
end))


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

    if assert(query("exists", hash)) ~= 0 then
      res.code = 200
      -- TODO: find out if we can cancel upload in case value already exists.
    else
      assert(query("set", hash, body))
      res.code = 201
      temps[hash] = uv.now() + (10 * 1000)
    end


    res.body = ''
    res.headers["ETag"] = '"' .. hash .. '"'
  end)


  .route({
    method = "POST",
    path = "/"
  }, function (req, res)
    local body = assert(req.body, "missing request body")
    local message
    local contentType = assert(req.headers["Content-Type"], "Content-Type header missing")
    local encode
    if contentType == "application/json" then
      message = assert(json.parse(body))
      encode = json.stringify
    elseif contentType == "application/msgpack" then
      message = assert(msgpack.decode(body))
      encode = msgpack.encode
    else
      error("Supported content types are application/json and application/msgpack")
    end
    p(message)
    local key = assert(publish(message))
    res.body = encode(key)
    res.code = 200
    res.headers["Content-Type"] = contentType
  end)

  .start()

require('uv').run()
