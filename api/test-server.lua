local p = require('pretty-print').prettyPrint
local request = require('coro-http').request

local connect = require('websocket-client')
local makeRpc = require('rpc')
local codec = require('websocket-to-message')

local function dump(...)
  local args = {...}
  for i = 1, select("#", ...) do
    p(args[i])
  end
end
local userAgent = "test-server.lua"

coroutine.wrap(function ()
  local aep = {
    hostname = "localhost"
  }
  -- dump(request("POST", "http://localhost:8080/api/aep.create", {
  --   {"User-Agent", userAgent},
  --   {"Content-Type", "application/json"}
  -- }, jsonEncode{aep}))
  -- dump(request("POST", "http://localhost:8080/api/aep.create", {
  --   {"User-Agent", userAgent},
  --   {"Content-Type", "application/msgpack"}
  -- }, msgpackEncode{aep}))
  local read, write = connect("ws://localhost:8080/websocket", "schema-rpc", {
    {"User-Agent", userAgent}
  })

  local severityTable = {
    "Fatal",
    "Error",
    "Warning",
    "Notice",
    "Debug"
  }


  local api = makeRpc(p, function (severity, ...)
    print(severityTable[severity], ...)
  end, codec(read, write))

  coroutine.wrap(api.readLoop)()


-- AEP section
  local AEP = api.aep

  local id = assert(AEP.create { hostname = "test.host" })

  assert(AEP.read(id))

  assert(AEP.update { id = id, hostname = "updated.host" })

  assert(AEP.read(id))

  AEP.query({})

  AEP.query({hostname="localhost"})

  AEP.query({hostname="local*"})

  assert(AEP.delete(id))

  assert(not AEP.read(id))

  AEP.delete("6050BE6B-A8BC-4BF8-A55C-11D616679CBC")

  AEP.update { id = "6050BE6B-A8BC-4BF8-A55C-11D616679CBC", hostname = "updated.host" }

-- account section
  local Account = api.account

  id = assert(Account.create {name = 'testAccount'})

  assert(Account.read(id))

  assert(Account.update { id = id, name = "updateAccountName" })

  assert(Account.read(id))

  Account.query({})

  Account.query({name="updateAccountName"})

  Account.query({name="update*"})

  assert(Account.delete(id))

  assert(not Account.read(id))

  Account.delete("6050BE6B-A8BC-4BF8-A55C-11D616679CBC")

  Account.update { id = "6050BE6B-A8BC-4BF8-A55C-11D616679CBC", name = "updateAccount" }

-- token section

  -- Token setup. We need to get an account
  local accountId = assert(Account.create {name = 'testAccount'})
  -- end Token setup

  local Token = api.token

  id = assert(Token.create {account_id = accountId, description = 'This token is for testing'})

  assert(Token.read(id))

  assert(Token.update {
    id = id,
    account_id=accountId,
    description = "Update token testing" })

  assert(Token.read(id))

  Token.query({})

  Token.query({description="Update token testing"})

  Token.query({description="Update*"})

  Token.query({account_id=accountId})

  -- Token.query({account_id='*'}) wildcards aren't allowed for uuid columns

  Token.query({account_id=accountId, description='Update token testing'})

  Token.query({account_id=accountId, descrption='Update*'})

  assert(Token.delete(id))

  assert(not Token.read(id))

  Token.delete("6050BE6B-A8BC-4BF8-A55C-11D616679CBC")

  Token.update { id = "6050BE6B-A8BC-4BF8-A55C-11D616679CBC", name = "updateAccount" }

  -- clean up section
  Account.delete(accountId)

  -- agent section
  Token = api.token

  Account = api.account

  -- agent setup
  accountId = assert(Account.create {name = 'testAccount'})

  local aepId = assert(AEP.create {hostname = 'test.host'})

  local tokenId = assert(Token.create {account_id=accountId, description='Test token for test agent'})
  -- end of agent setup

  local Agent = api.agent

  id = assert(Agent.create({
    account_id=accountId,
    name = "test agent",
    aep_id = aepId,
    token = tokenId}))

  assert(Agent.read(id))

  assert(Agent.update {
    id = id,
    account_id=accountId,
    name = "update test agent",
    aep_id = aepId,
    token = tokenId
   })

  assert(Agent.read(id))

  Agent.query({})

  Agent.query({name="Update token testing"})

  Agent.query({name="Update*"})

  Agent.query({account_id=accountId})

  Agent.query({aep_id=aepId})

  Agent.query({token=tokenId})

  -- Token.query({account_id='*'}) wildcards aren't allowed for uuid columns

  Agent.query({account_id=accountId, name=''})

  Agent.query({account_id=accountId, name='Update*'})

  assert(Agent.delete(id))

  assert(not Agent.read(id))

  Agent.delete("6050BE6B-A8BC-4BF8-A55C-11D616679CBC")

  Agent.update { id = "6050BE6B-A8BC-4BF8-A55C-11D616679CBC", name = "updateAccount" }


  -- clean up section
  Token.delete(tokenId)
  AEP.delete(aepId)
  Account.delete(accountId)


  -- event
  local Event = api.event

  Event.log({timestamp=1455562901, event="lets break things"})

  Event.log({timestamp=1455562901, event='{"test":"value"}'})

  Event.log({timestamp='This should fail', event='{"in":"something"}'})

  --[[
  --We will add pagination for events at some future point when we understand how we want to filter events
  Event.query({timestamp=1455562901})

  Event.query({timestamp=1}) -- should return nothing but still work

  Event.query({event='{test:value}'})]]

  api.close()
end)()
