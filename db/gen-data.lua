local numAccounts = 10 -- 2500
local numAeps = 5 -- 45
local tokensPerAccount = 3 -- 10
local agentsPerAccount = 5 -- 50
local connectionsPerAgent = 20 -- 200

local getUUID = require('./uuid4').getUUID
local jsonStringify = require('json').stringify

local aeps = {}
local accounts = {}
local agents = {}
local tokens = {}
print("COPY aep (id, hostname) FROM STDIN;")
for i = 1, numAeps do
  local id = getUUID()
  aeps[i] = id
  print(id .. "\t128.0.0.1")
end
print("\\.")

print("COPY account (id, name) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = getUUID()
  accounts[i] = accountId
  print(accountId .. "\tTest account " .. i)
end
print("\\.")

print("COPY token (id, account_id, description) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = accounts[i]
  local list = {}
  tokens[accountId] = list
  for j = 1, tokensPerAccount do
    local token = getUUID()
    list[j] = token
    print(token .. "\t" .. accountId .. "\tTest token " .. j)
  end
end
print("\\.")

print("COPY agent (id, account_id, name, aep_id, token) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = accounts[i]
  for j = 1, agentsPerAccount do
    local agentId = getUUID()
    agents[(i - 1) * agentsPerAccount + j] = agentId
    local aepId = aeps[((j + i) % numAeps) + 1]
    local list = tokens[accountId]
    local token = list[((j + i) % tokensPerAccount) + 1]
    print(
      agentId ..
      "\t" .. accountId ..
      "\tTest agent " .. j ..
      "\t" .. aepId ..
      "\t" .. token)
  end
end
print("\\.")

print "SET datestyle TO 'ISO';"

local uv = require('uv')
local time = 2451187
for i = 1, numAccounts do
  print("COPY event (timestamp, event) FROM STDIN;")
  for j = 1, agentsPerAccount do
    local agentId = agents[(i - 1) * agentsPerAccount + j]
    for k = 1, connectionsPerAgent do
      local aepId = aeps[((k + j + i) % numAeps) + 1]
      local next = time + 1
      local json = jsonStringify {
        aep_id = aepId,
        agent_id = agentId
      }
      print(os.date("!%Y-%m-%dT%TZ", time) .. "\t" .. json)
      time = next
    end
  end
  print("\\.")
  uv.run() -- flush stdout since luvit likes to buffer on some platforms.
end
