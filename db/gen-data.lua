local numAccounts = 2500
local numAeps = 45
local tokensPerAccount = 10
local agentsPerAccount = 50
local connectionsPerAgent = 200

local getUUID = require('./uuid4').getUUID

local aeps = {}
local accounts = {}
local agents = {}
print("COPY aep (id, address) FROM STDIN;")
for i = 1, numAeps do
  local id = getUUID()
  aeps[i] = id
  print(id .. "\t128.0.0.1")
end
print("\\.")

print("COPY ACCOUNT (id, name) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = getUUID()
  accounts[i] = accountId
  print(accountId .. "\tTest account " .. i)
end
print("\\.")

print("COPY token (id, account_id, description) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = accounts[i]
  for j = 1, tokensPerAccount do
    local token = getUUID()
    print(token .. "\t" .. accountId .. "\tTest token " .. j)
  end
end
print("\\.")

print("COPY agent (id, account_id, description) FROM STDIN;")
for i = 1, numAccounts do
  local accountId = accounts[i]
  for j = 1, agentsPerAccount do
    local agentId = getUUID()
    agents[(i - 1) * agentsPerAccount + j] = agentId
    print(agentId .. "\t" .. accountId .. "\tTest agent " .. j)
  end
end
print("\\.")
local uv = require('uv')
local time = 2451187
for i = 1, numAccounts do
  print("COPY connection (aep_id, agent_id, connect, disconnect) FROM STDIN;")
  for j = 1, agentsPerAccount do
    local agentId = agents[(i - 1) * agentsPerAccount + j]
    for k = 1, connectionsPerAgent do
      local aepID = aeps[((k + j + i) % numAeps) + 1]
      local next = time + 1
        print(aepID .. "\t" .. agentId .. "\tJ" .. time .. "\tJ" .. next)
      time = next
    end
  end
  print("\\.")
  uv.run() -- flush stdout since luvit likes to buffer on some platforms.
end

-- print("INSERT INTO connection (aep_id, agent_id, connect)" ..
  -- " VALUES('" .. aepID .. "', '" .. agentId .. "', 'J" .. time .. "');")
